package com.slock.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val methodChannelName = "slock/notifications/methods"
        private const val tapEventChannelName = "slock/notifications/taps"
        private const val foregroundEventChannelName = "slock/notifications/foreground"
        private const val tokenEventChannelName = "slock/notifications/token"
        private const val foregroundServiceChannelName = "slock/notifications/foreground_service"
        private const val notificationPermissionRequestCode = 1001
        private const val notificationChannelId = "slock_messages"
        private const val notificationChannelName = "Messages"
        private const val dmChannelId = "slock_direct_messages"
        private const val dmChannelName = "Direct Messages"
        private const val mentionChannelId = "slock_mentions"
        private const val mentionChannelName = "Mentions"
        private const val generalChannelId = "slock_channel_messages"
        private const val generalChannelName = "Channel Messages"
        private const val tag = "SlockNotifications"
    }

    private var tapEventSink: EventChannel.EventSink? = null
    private var pendingTapPayload: Map<String, Any?>? = null
    private var initialNotificationPayload: Map<String, Any?>? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var localNotificationId = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialNotificationPayload = extractNotificationPayload(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    ensureNotificationChannel()
                    result.success(null)
                }
                "requestPermission" -> requestNotificationPermission(result)
                "getPermissionStatus" -> {
                    result.success(readPermissionStatus().wireValue)
                }
                "getToken" -> getNotificationToken(result)
                "getInitialNotification" -> {
                    result.success(initialNotificationPayload)
                    initialNotificationPayload = null
                }
                "showLocalNotification" -> {
                    @Suppress("UNCHECKED_CAST")
                    val payload = call.arguments as? Map<String, Any?> ?: emptyMap()
                    showLocalNotification(payload)
                    result.success(null)
                }
                "configureNotificationChannels" -> {
                    @Suppress("UNCHECKED_CAST")
                    val channels = call.arguments as? List<Map<String, Any?>> ?: emptyList()
                    configureNotificationChannels(channels)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            tapEventChannelName,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    tapEventSink = events
                    pendingTapPayload?.let {
                        events.success(it)
                        pendingTapPayload = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    tapEventSink = null
                }
            },
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            foregroundEventChannelName,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    ForegroundMessageBroker.attachSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    ForegroundMessageBroker.detachSink()
                }
            },
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            tokenEventChannelName,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    TokenEventBroker.attachSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    TokenEventBroker.detachSink()
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            foregroundServiceChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val intent = Intent(this, SlockForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopForegroundService" -> {
                    val intent = Intent(this, SlockForegroundService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                "isForegroundServiceRunning" -> {
                    result.success(SlockForegroundService.isRunning)
                }
                "setAuthFlag" -> {
                    val authenticated = call.arguments as? Boolean ?: false
                    val prefs = getSharedPreferences(
                        "slock_foreground_service",
                        MODE_PRIVATE,
                    )
                    prefs.edit().putBoolean("is_authenticated", authenticated).apply()
                    result.success(null)
                }
                "refreshWorkerAuth" -> {
                    SlockForegroundService.refreshWorkerAuth()
                    result.success(null)
                }
                "setWorkerForegroundActive" -> {
                    val active = call.arguments as? Boolean ?: false
                    SlockForegroundService.setWorkerForegroundActive(active)
                    result.success(null)
                }
                "getWorkerDiagnostics" -> {
                    SlockForegroundService.getWorkerDiagnostics(result)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        extractNotificationPayload(intent)?.let { payload ->
            if (tapEventSink != null) {
                tapEventSink?.success(payload)
            } else {
                pendingTapPayload = payload
            }
        }
    }

    override fun onResume() {
        super.onResume()
        ForegroundMessageBroker.setForegroundActive(true)
    }

    override fun onPause() {
        super.onPause()
        ForegroundMessageBroker.setForegroundActive(false)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationPermissionRequestCode) {
            return
        }

        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null

        val isGranted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        val status = if (isGranted) {
            PermissionStatus.granted
        } else {
            readPermissionStatus()
        }
        result.success(status.wireValue)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java) ?: return

            // Legacy channel (kept for backwards compatibility).
            val legacyChannel = NotificationChannel(
                notificationChannelId,
                notificationChannelName,
                NotificationManager.IMPORTANCE_HIGH,
            )
            manager.createNotificationChannel(legacyChannel)

            // Type-specific channels.
            val dmChannel = NotificationChannel(
                dmChannelId,
                dmChannelName,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Notifications for direct messages"
            }
            manager.createNotificationChannel(dmChannel)

            val mentionChannel = NotificationChannel(
                mentionChannelId,
                mentionChannelName,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Notifications for @mentions"
            }
            manager.createNotificationChannel(mentionChannel)

            val generalChannel = NotificationChannel(
                generalChannelId,
                generalChannelName,
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Notifications for channel messages and other activity"
            }
            manager.createNotificationChannel(generalChannel)
        }
    }

    private fun configureNotificationChannels(channels: List<Map<String, Any?>>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        for (channel in channels) {
            val id = channel["id"] as? String ?: continue
            val name = channel["name"] as? String ?: id
            val importance = when (channel["importance"] as? String) {
                "low" -> NotificationManager.IMPORTANCE_LOW
                "high" -> NotificationManager.IMPORTANCE_HIGH
                else -> NotificationManager.IMPORTANCE_DEFAULT
            }
            val notificationChannel = NotificationChannel(id, name, importance).apply {
                description = channel["description"] as? String ?: ""
            }
            manager.createNotificationChannel(notificationChannel)
        }
    }

    private fun showLocalNotification(payload: Map<String, Any?>) {
        val title = payload["title"] as? String ?: "Slock"
        val body = payload["body"] as? String ?: ""
        val channelId = resolveChannelId(payload)

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            for ((key, value) in payload) {
                when (value) {
                    is String -> putExtra(key, value)
                    is Boolean -> putExtra(key, value)
                    is Int -> putExtra(key, value)
                    is Long -> putExtra(key, value)
                    is Double -> putExtra(key, value)
                }
            }
        }

        val requestCode = payload.hashCode() and 0x7FFFFFFF
        val pendingIntent = PendingIntent.getActivity(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        ensureNotificationChannel()

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        addMessageActions(builder, payload, requestCode)

        val notification = builder.build()

        val notificationManager = NotificationManagerCompat.from(this)
        val notificationId = localNotificationId++
        try {
            notificationManager.notify(notificationId, notification)
        } catch (e: SecurityException) {
            Log.w(tag, "Missing notification permission", e)
        }
    }

    private fun addMessageActions(
        builder: NotificationCompat.Builder,
        payload: Map<String, Any?>,
        requestCode: Int,
    ) {
        val serverId = payload["serverId"] as? String ?: return
        val channelId = payload["channelId"] as? String ?: return
        val replyLabel = payload["replyActionLabel"] as? String ?: "Reply"
        val markReadLabel = payload["markReadActionLabel"] as? String ?: "Mark as read"
        val replyInputLabel = payload["replyInputLabel"] as? String ?: replyLabel

        val replyInput = RemoteInput.Builder(SlockNotificationActionReceiver.KEY_REPLY_TEXT)
            .setLabel(replyInputLabel)
            .build()
        val replyIntent = actionIntent(
            SlockNotificationActionReceiver.ACTION_REPLY,
            payload,
        )
        val replyPendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode + 1,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        val replyAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send,
            replyLabel,
            replyPendingIntent,
        ).addRemoteInput(replyInput).build()

        val markReadIntent = actionIntent(
            SlockNotificationActionReceiver.ACTION_MARK_READ,
            payload,
        )
        val markReadPendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode + 2,
            markReadIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val markReadAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_manage,
            markReadLabel,
            markReadPendingIntent,
        ).build()

        builder.addAction(replyAction)
        builder.addAction(markReadAction)
    }

    private fun actionIntent(action: String, payload: Map<String, Any?>): Intent {
        return Intent(this, SlockNotificationActionReceiver::class.java).apply {
            this.action = action
            for ((key, value) in payload) {
                when (value) {
                    is String -> putExtra(key, value)
                    is Boolean -> putExtra(key, value)
                    is Int -> putExtra(key, value)
                    is Long -> putExtra(key, value)
                    is Double -> putExtra(key, value)
                }
            }
        }
    }

    private fun resolveChannelId(payload: Map<String, Any?>): String {
        val channelType = payload["notificationChannelType"] as? String
            ?: payload["type"] as? String
        return when (channelType) {
            "dm", "direct_message" -> dmChannelId
            "mention" -> mentionChannelId
            else -> generalChannelId
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        val powerManager = getSystemService(PowerManager::class.java) ?: return true
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }
        if (isIgnoringBatteryOptimizations()) {
            return
        }

        val packageUri = Uri.parse("package:$packageName")
        val requestIntent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            packageUri,
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            startActivity(requestIntent)
        } catch (error: Exception) {
            val settingsIntent = Intent(
                Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS,
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(settingsIntent)
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        val currentStatus = readPermissionStatus()
        if (currentStatus == PermissionStatus.granted ||
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
        ) {
            result.success(currentStatus.wireValue)
            return
        }

        if (pendingPermissionResult != null) {
            result.success(currentStatus.wireValue)
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode,
        )
    }

    private fun getNotificationToken(result: MethodChannel.Result) {
        try {
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (!task.isSuccessful) {
                    Log.w(tag, "Notification token fetch failed", task.exception)
                    result.success(null)
                    return@addOnCompleteListener
                }

                result.success(task.result)
            }
        } catch (error: Exception) {
            Log.w(tag, "Notification token fetch unavailable", error)
            result.success(null)
        }
    }

    private fun readPermissionStatus(): PermissionStatus {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return if (NotificationManagerCompat.from(this).areNotificationsEnabled()) {
                PermissionStatus.granted
            } else {
                PermissionStatus.denied
            }
        }

        val isGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (isGranted) {
            return if (NotificationManagerCompat.from(this).areNotificationsEnabled()) {
                PermissionStatus.granted
            } else {
                PermissionStatus.denied
            }
        }

        return if (shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
            PermissionStatus.denied
        } else {
            PermissionStatus.unknown
        }
    }

    private fun extractNotificationPayload(intent: Intent?): Map<String, Any?>? {
        val extras = intent?.extras ?: return null
        val payload = mutableMapOf<String, Any?>()

        for (key in extras.keySet()) {
            when (val value = extras.get(key)) {
                is Boolean,
                is Double,
                is Int,
                is Long,
                is String,
                -> payload[key] = value

                is CharSequence -> payload[key] = value.toString()
                is Float -> payload[key] = value.toDouble()
            }
        }

        return payload.ifEmpty { null }
    }
}

private enum class PermissionStatus(val wireValue: String) {
    unknown("unknown"),
    granted("granted"),
    denied("denied"),
}

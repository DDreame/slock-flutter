package com.slock.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
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
        private const val notificationPermissionRequestCode = 1001
        private const val notificationChannelId = "slock_messages"
        private const val notificationChannelName = "Messages"
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
            val channel = NotificationChannel(
                notificationChannelId,
                notificationChannelName,
                NotificationManager.IMPORTANCE_HIGH,
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun showLocalNotification(payload: Map<String, Any?>) {
        val title = payload["title"] as? String ?: "Slock"
        val body = payload["body"] as? String ?: ""

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

        val notification = NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val notificationManager = NotificationManagerCompat.from(this)
        val notificationId = localNotificationId++
        try {
            notificationManager.notify(notificationId, notification)
        } catch (e: SecurityException) {
            Log.w(tag, "Missing notification permission", e)
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

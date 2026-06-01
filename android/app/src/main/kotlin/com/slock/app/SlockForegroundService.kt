package com.slock.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class SlockForegroundService : Service() {
    companion object {
        private const val channelId = "slock_foreground"
        private const val channelName = "Real-time connection"
        private const val legacyMessageChannelId = "slock_messages"
        private const val legacyMessageChannelName = "Messages"
        private const val dmChannelId = "slock_direct_messages"
        private const val dmChannelName = "Direct Messages"
        private const val mentionChannelId = "slock_mentions"
        private const val mentionChannelName = "Mentions"
        private const val channelMessageChannelId = "slock_channel_messages"
        private const val channelMessageChannelName = "Channel Messages"
        private const val notificationId = 9001
        private const val tag = "SlockForegroundService"
        internal const val servicePrefsName = "slock_foreground_service"
        internal const val authFlagKey = "is_authenticated"
        private const val lastStartKey = "last_start_ms"
        private const val backgroundWorkerChannelName =
            "slock/notifications/background_worker"
        private const val dartEntrypoint = "backgroundNotificationMain"
        const val ACTION_NOTIFICATION_ACTION = "com.slock.app.notification.ACTION"
        const val EXTRA_NOTIFICATION_ACTION = "slock.action"

        /** Minimum interval between OS-triggered restarts. */
        private const val restartBackoffMs = 5_000L

        @Volatile
        var isRunning: Boolean = false
            private set

        /** Reference to the running service instance for static access. */
        @Volatile
        private var instance: SlockForegroundService? = null

        /** Signal the headless Dart worker to reload auth and reconnect. */
        fun refreshWorkerAuth() {
            instance?.workerMethodChannel?.invokeMethod("refreshAuth", null)
        }

        /** Signal the headless Dart worker about foreground-active state. */
        fun setWorkerForegroundActive(active: Boolean) {
            instance?.workerMethodChannel?.invokeMethod(
                "setForegroundActive",
                active,
            )
        }

        /** Request diagnostics from the headless Dart worker. */
        fun getWorkerDiagnostics(result: MethodChannel.Result) {
            val channel = instance?.workerMethodChannel
            if (channel == null) {
                result.success(null)
                return
            }
            channel.invokeMethod(
                "getDiagnostics",
                null,
                object : MethodChannel.Result {
                    override fun success(data: Any?) {
                        result.success(data)
                    }

                    override fun error(
                        code: String,
                        message: String?,
                        details: Any?,
                    ) {
                        result.success(null)
                    }

                    override fun notImplemented() {
                        result.success(null)
                    }
                },
            )
        }
    }

    private var flutterEngine: FlutterEngine? = null
    private var workerMethodChannel: MethodChannel? = null
    private var dartWorkerReady = false
    private var backgroundNotificationId = 10_000
    private val pendingNotificationActions = mutableListOf<Map<String, Any?>>()

    override fun onCreate() {
        super.onCreate()
        ensureForegroundNotificationChannel()
        ensureMessageNotificationChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        // When intent is null the OS restarted us (START_STICKY).
        // Verify the Dart-managed auth flag; if false, stop.
        val isOsRestart = intent == null
        if (isOsRestart) {
            val now = System.currentTimeMillis()
            val lastStart = readLastStartTimestamp()
            if (now - lastStart < restartBackoffMs) {
                Log.w(tag, "Restart too fast — backing off")
                stopSelf()
                return START_NOT_STICKY
            }
            if (!isAuthenticated()) {
                Log.d(tag, "Auth flag false — stopping after OS restart")
                stopSelf()
                return START_NOT_STICKY
            }
        }

        writeLastStartTimestamp(System.currentTimeMillis())

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Slock")
            .setContentText("Connected — receiving messages")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(launchIntent())
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    notificationId,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(notificationId, notification)
            }
            isRunning = true
            instance = this
        } catch (e: Exception) {
            Log.e(tag, "Failed to start foreground service", e)
            stopSelf()
            return START_NOT_STICKY
        }

        // Start headless FlutterEngine for background notification worker.
        startDartWorker()
        handleNotificationActionIntent(intent)

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        stopDartWorker()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // -- Headless FlutterEngine -----------------------------------------------

    private fun startDartWorker() {
        if (flutterEngine != null) {
            Log.d(tag, "Dart worker already running")
            return
        }

        Log.d(tag, "Starting headless Dart worker")
        val engine = FlutterEngine(this, null, false)

        // Register plugins so SharedPreferences and other platform
        // channels are available in the headless engine context.
        io.flutter.plugins.GeneratedPluginRegistrant.registerWith(engine)

        // Set up the method channel BEFORE executing the Dart entrypoint
        // so the Dart code can use it immediately.
        workerMethodChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            backgroundWorkerChannelName,
        )
        workerMethodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    @Suppress("UNCHECKED_CAST")
                    val payload = call.arguments as? Map<String, Any?> ?: emptyMap()
                    val error = showBackgroundNotification(payload)
                    if (error != null) {
                        result.error(error.first, error.second, null)
                    } else {
                        result.success(null)
                    }
                }
                "workerReady" -> {
                    dartWorkerReady = true
                    flushPendingNotificationActions()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Execute the background entrypoint.
        val flutterLoader = FlutterInjector.instance().flutterLoader()
        val appBundlePath = flutterLoader.findAppBundlePath()
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(appBundlePath, dartEntrypoint),
        )

        flutterEngine = engine
        Log.d(tag, "Headless Dart worker started")
    }

    private fun stopDartWorker() {
        workerMethodChannel?.setMethodCallHandler(null)
        workerMethodChannel = null
        dartWorkerReady = false
        pendingNotificationActions.clear()
        flutterEngine?.destroy()
        flutterEngine = null
        Log.d(tag, "Headless Dart worker stopped")
    }

    // -- Background notification posting --------------------------------------

    /**
     * Posts a local notification from the headless Dart worker.
     * Returns null on success, or a Pair(code, message) on error
     * that should be sent back via result.error().
     */
    private fun showBackgroundNotification(
        payload: Map<String, Any?>,
    ): Pair<String, String>? {
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

        val builder = NotificationCompat.Builder(this, resolveMessageChannelId(payload))
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        addMessageActions(builder, payload, requestCode)

        val notification = builder.build()

        val notificationManager = NotificationManagerCompat.from(this)
        val id = backgroundNotificationId++
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                    == PackageManager.PERMISSION_GRANTED
                ) {
                    notificationManager.notify(id, notification)
                } else {
                    Log.w(tag, "Missing POST_NOTIFICATIONS permission")
                    return Pair(
                        "PERMISSION_DENIED",
                        "POST_NOTIFICATIONS permission not granted",
                    )
                }
            } else {
                notificationManager.notify(id, notification)
            }
        } catch (e: SecurityException) {
            Log.w(tag, "Notification security exception", e)
            return Pair("PERMISSION_DENIED", e.message ?: "SecurityException")
        }
        return null
    }

    private fun handleNotificationActionIntent(intent: Intent?) {
        if (intent?.action != ACTION_NOTIFICATION_ACTION) return
        val payload = mutableMapOf<String, Any?>()
        intent.getStringExtra(EXTRA_NOTIFICATION_ACTION)?.let { payload["action"] = it }
        intent.getStringExtra("serverId")?.let { payload["serverId"] = it }
        intent.getStringExtra("channelId")?.let { payload["channelId"] = it }
        intent.getStringExtra("messageId")?.let { payload["messageId"] = it }
        intent.getStringExtra("replyText")?.let { payload["replyText"] = it }
        if (payload.isEmpty()) return
        dispatchNotificationAction(payload)
    }

    private fun dispatchNotificationAction(payload: Map<String, Any?>) {
        val channel = workerMethodChannel
        if (dartWorkerReady && channel != null) {
            channel.invokeMethod("handleNotificationAction", payload)
        } else {
            pendingNotificationActions.add(payload)
        }
    }

    private fun flushPendingNotificationActions() {
        val channel = workerMethodChannel ?: return
        val pending = pendingNotificationActions.toList()
        pendingNotificationActions.clear()
        for (payload in pending) {
            channel.invokeMethod("handleNotificationAction", payload)
        }
    }

    private fun addMessageActions(
        builder: NotificationCompat.Builder,
        payload: Map<String, Any?>,
        requestCode: Int,
    ) {
        payload["serverId"] as? String ?: return
        payload["channelId"] as? String ?: return
        val replyLabel = payload["replyActionLabel"] as? String ?: "Reply"
        val markReadLabel = payload["markReadActionLabel"] as? String ?: "Mark as read"
        val replyInputLabel = payload["replyInputLabel"] as? String ?: replyLabel

        val replyInput = RemoteInput.Builder(SlockNotificationActionReceiver.KEY_REPLY_TEXT)
            .setLabel(replyInputLabel)
            .build()
        val replyPendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode + 1,
            actionIntent(SlockNotificationActionReceiver.ACTION_REPLY, payload),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        val replyAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send,
            replyLabel,
            replyPendingIntent,
        ).addRemoteInput(replyInput).build()

        val markReadPendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode + 2,
            actionIntent(SlockNotificationActionReceiver.ACTION_MARK_READ, payload),
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

    private fun resolveMessageChannelId(payload: Map<String, Any?>): String {
        val channelType = payload["notificationChannelType"] as? String
            ?: payload["type"] as? String
        return when (channelType) {
            "dm", "direct_message" -> dmChannelId
            "mention" -> mentionChannelId
            else -> channelMessageChannelId
        }
    }

    // -- Service prefs -------------------------------------------------

    private fun servicePrefs() =
        getSharedPreferences(servicePrefsName, Context.MODE_PRIVATE)

    private fun isAuthenticated(): Boolean =
        servicePrefs().getBoolean(authFlagKey, false)

    private fun readLastStartTimestamp(): Long =
        servicePrefs().getLong(lastStartKey, 0L)

    private fun writeLastStartTimestamp(millis: Long) {
        servicePrefs().edit().putLong(lastStartKey, millis).apply()
    }

    // -- Notification channels -----------------------------------------

    private fun ensureForegroundNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps real-time message delivery active"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun ensureMessageNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java) ?: return
            manager.createNotificationChannel(
                NotificationChannel(
                    legacyMessageChannelId,
                    legacyMessageChannelName,
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    dmChannelId,
                    dmChannelName,
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    mentionChannelId,
                    mentionChannelName,
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    channelMessageChannelId,
                    channelMessageChannelName,
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
    }

    private fun launchIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

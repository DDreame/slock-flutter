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
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class SlockForegroundService : Service() {
    companion object {
        private const val channelId = "slock_foreground"
        private const val channelName = "Real-time connection"
        private const val messageChannelId = "slock_messages"
        private const val messageChannelName = "Messages"
        private const val notificationId = 9001
        private const val tag = "SlockForegroundService"
        internal const val servicePrefsName = "slock_foreground_service"
        internal const val authFlagKey = "is_authenticated"
        private const val lastStartKey = "last_start_ms"
        private const val backgroundWorkerChannelName =
            "slock/notifications/background_worker"
        private const val dartEntrypoint = "backgroundNotificationMain"

        /** Minimum interval between OS-triggered restarts. */
        private const val restartBackoffMs = 5_000L

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private var flutterEngine: FlutterEngine? = null
    private var workerMethodChannel: MethodChannel? = null
    private var backgroundNotificationId = 10_000

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
        } catch (e: Exception) {
            Log.e(tag, "Failed to start foreground service", e)
            stopSelf()
            return START_NOT_STICKY
        }

        // Start headless FlutterEngine for background notification worker.
        startDartWorker()

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
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
                    showBackgroundNotification(payload)
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
        flutterEngine?.destroy()
        flutterEngine = null
        Log.d(tag, "Headless Dart worker stopped")
    }

    // -- Background notification posting --------------------------------------

    private fun showBackgroundNotification(payload: Map<String, Any?>) {
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

        val notification = NotificationCompat.Builder(this, messageChannelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

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
                }
            } else {
                notificationManager.notify(id, notification)
            }
        } catch (e: SecurityException) {
            Log.w(tag, "Notification security exception", e)
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
            val channel = NotificationChannel(
                messageChannelId,
                messageChannelName,
                NotificationManager.IMPORTANCE_HIGH,
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
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

package com.slock.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class SlockForegroundService : Service() {
    companion object {
        private const val channelId = "slock_foreground"
        private const val channelName = "Real-time connection"
        private const val notificationId = 9001
        private const val tag = "SlockForegroundService"
        private const val sessionPrefsName = "FlutterSecureStorage"
        private const val sessionTokenKey = "session_token"
        private const val servicePrefsName = "slock_foreground_service"
        private const val lastStartKey = "last_start_ms"

        /** Minimum interval between OS-triggered restarts. */
        private const val restartBackoffMs = 5_000L

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        // When intent is null the OS restarted us (START_STICKY).
        // Verify the user still has a stored session; if not, stop.
        val isOsRestart = intent == null
        if (isOsRestart) {
            val now = System.currentTimeMillis()
            val lastStart = readLastStartTimestamp()
            if (now - lastStart < restartBackoffMs) {
                Log.w(tag, "Restart too fast — backing off")
                stopSelf()
                return START_NOT_STICKY
            }
            if (!hasStoredSession()) {
                Log.d(tag, "No stored session — stopping after OS restart")
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
        }

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // -- Backoff persistence -------------------------------------------

    private fun servicePrefs() =
        getSharedPreferences(servicePrefsName, Context.MODE_PRIVATE)

    private fun readLastStartTimestamp(): Long =
        servicePrefs().getLong(lastStartKey, 0L)

    private fun writeLastStartTimestamp(millis: Long) {
        servicePrefs().edit().putLong(lastStartKey, millis).apply()
    }

    // -- Session check -------------------------------------------------

    private fun hasStoredSession(): Boolean {
        return try {
            val masterKey = MasterKey.Builder(this)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val prefs = EncryptedSharedPreferences.create(
                this,
                sessionPrefsName,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )

            val token = prefs.getString(sessionTokenKey, null)
            !token.isNullOrEmpty()
        } catch (e: Exception) {
            Log.w(tag, "Could not read session storage", e)
            false
        }
    }

    // -- Notification ---------------------------------------------------

    private fun ensureNotificationChannel() {
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

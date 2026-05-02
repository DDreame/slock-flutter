package com.slock.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class SlockFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val notificationChannelId = "slock_messages"
        private const val notificationChannelName = "Messages"
        private const val tag = "SlockFCM"
    }

    private var localNotificationId = 0

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val payload = mutableMapOf<String, Any?>()

        remoteMessage.data.forEach { (key, value) ->
            payload[key] = value
        }

        remoteMessage.notification?.let { notification ->
            notification.title?.let { payload["title"] = it }
            notification.body?.let { payload["body"] = it }
        }

        if (payload.isEmpty()) return

        if (ForegroundMessageBroker.isForegroundActive) {
            ForegroundMessageBroker.push(payload)
        } else {
            showBackgroundNotification(payload)
        }
    }

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
}

package com.slock.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.RemoteInput

class SlockNotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != ACTION_REPLY && action != ACTION_MARK_READ) return

        val serviceIntent = Intent(context, SlockForegroundService::class.java).apply {
            this.action = SlockForegroundService.ACTION_NOTIFICATION_ACTION
            putExtra(SlockForegroundService.EXTRA_NOTIFICATION_ACTION, when (action) {
                ACTION_REPLY -> "reply"
                else -> "mark_read"
            })
            copyExtra(intent, "serverId")
            copyExtra(intent, "channelId")
            copyExtra(intent, "messageId")
            val replyText = RemoteInput.getResultsFromIntent(intent)
                ?.getCharSequence(KEY_REPLY_TEXT)
                ?.toString()
            if (!replyText.isNullOrBlank()) {
                putExtra("replyText", replyText)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun Intent.copyExtra(source: Intent, key: String) {
        source.getStringExtra(key)?.let { putExtra(key, it) }
    }

    companion object {
        const val ACTION_REPLY = "com.slock.app.notification.REPLY"
        const val ACTION_MARK_READ = "com.slock.app.notification.MARK_READ"
        const val KEY_REPLY_TEXT = "replyText"
    }
}

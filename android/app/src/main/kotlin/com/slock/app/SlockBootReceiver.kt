package com.slock.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Restores the foreground service after device boot if the user was
 * previously authenticated.
 *
 * Reads the plain `is_authenticated` flag from SharedPreferences
 * (`slock_foreground_service`) that is managed by the Dart-side
 * lifecycle binding. This avoids reading flutter_secure_storage keys
 * directly (which use internal key prefixing).
 */
class SlockBootReceiver : BroadcastReceiver() {
    companion object {
        private const val tag = "SlockBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences(
            SlockForegroundService.servicePrefsName,
            Context.MODE_PRIVATE,
        )
        val isAuthenticated = prefs.getBoolean(
            SlockForegroundService.authFlagKey,
            false,
        )

        if (!isAuthenticated) {
            Log.d(tag, "Auth flag false — skipping service restore")
            return
        }

        try {
            val serviceIntent = Intent(context, SlockForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(tag, "Foreground service restored after boot")
        } catch (e: Exception) {
            Log.e(tag, "Failed to restore foreground service", e)
        }
    }
}

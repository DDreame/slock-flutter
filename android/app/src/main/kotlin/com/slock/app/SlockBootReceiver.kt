package com.slock.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Restores the foreground service after device boot if the user was
 * previously authenticated.
 *
 * Checks EncryptedSharedPreferences for a stored session token
 * (written by flutter_secure_storage with encryptedSharedPreferences
 * enabled). If a token exists the service is started; the Dart-side
 * lifecycle binding will stop it again if the token turns out to be
 * expired once the full app bootstraps.
 */
class SlockBootReceiver : BroadcastReceiver() {
    companion object {
        private const val tag = "SlockBootReceiver"
        private const val prefsName = "FlutterSecureStorage"
        private const val sessionTokenKey = "session_token"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return

        if (!hasStoredSession(context)) {
            Log.d(tag, "No stored session — skipping service restore")
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

    private fun hasStoredSession(context: Context): Boolean {
        return try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val prefs = EncryptedSharedPreferences.create(
                context,
                prefsName,
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
}

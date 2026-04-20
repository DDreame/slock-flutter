package com.slock.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
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
        private const val tag = "SlockNotifications"
    }

    private var tapEventSink: EventChannel.EventSink? = null
    private var pendingTapPayload: Map<String, Any?>? = null
    private var initialNotificationPayload: Map<String, Any?>? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private lateinit var permissionLauncher: ActivityResultLauncher<String>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialNotificationPayload = extractNotificationPayload(intent)
        permissionLauncher = registerForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { granted ->
            val result = pendingPermissionResult ?: return@registerForActivityResult
            pendingPermissionResult = null
            val status = if (granted) {
                PermissionStatus.granted
            } else {
                readPermissionStatus()
            }
            result.success(status.wireValue)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> result.success(null)
                "requestPermission" -> requestNotificationPermission(result)
                "getToken" -> getNotificationToken(result)
                "getInitialNotification" -> {
                    result.success(initialNotificationPayload)
                    initialNotificationPayload = null
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
        permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
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

package com.slock.app

import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Singleton broker that bridges FCM token delivery from
 * [SlockFirebaseMessagingService.onNewToken] to the Flutter EventChannel
 * (`slock/notifications/token`).
 *
 * The token channel sink may not be attached when the service fires — e.g.
 * the token is rotated before the Dart isolate subscribes. In that case
 * the latest token is buffered and drained on [attachSink].
 */
object TokenEventBroker {
    private const val TAG = "TokenEventBroker"

    @Volatile
    private var sink: EventChannel.EventSink? = null

    @Volatile
    private var pendingToken: String? = null

    fun attachSink(eventSink: EventChannel.EventSink) {
        sink = eventSink
        pendingToken?.let { token ->
            eventSink.success(token)
            pendingToken = null
            Log.d(TAG, "Drained pending token on sink attach")
        }
    }

    fun detachSink() {
        sink = null
    }

    fun push(token: String) {
        val currentSink = sink
        if (currentSink != null) {
            currentSink.success(token)
        } else {
            pendingToken = token
            Log.d(TAG, "Buffered token (sink not yet attached)")
        }
    }
}

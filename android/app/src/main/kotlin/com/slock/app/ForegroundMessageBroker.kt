package com.slock.app

import android.util.Log
import io.flutter.plugin.common.EventChannel

object ForegroundMessageBroker {
    private const val TAG = "ForegroundMessageBroker"
    private const val MAX_BUFFER_SIZE = 50

    @Volatile
    private var sink: EventChannel.EventSink? = null

    @Volatile
    private var foregroundActive: Boolean = false

    private val buffer = mutableListOf<Map<String, Any?>>()

    fun attachSink(eventSink: EventChannel.EventSink) {
        sink = eventSink
        drainBuffer()
    }

    fun detachSink() {
        sink = null
    }

    fun setForegroundActive(active: Boolean) {
        foregroundActive = active
    }

    val isForegroundActive: Boolean
        get() = foregroundActive

    fun push(payload: Map<String, Any?>) {
        if (!foregroundActive) return

        val currentSink = sink
        if (currentSink != null) {
            currentSink.success(payload)
        } else {
            // Sink not yet attached (brief window after Activity resume
            // before Dart re-subscribes the EventChannel). Buffer for
            // drain on attachSink().
            synchronized(buffer) {
                if (buffer.size >= MAX_BUFFER_SIZE) {
                    Log.w(TAG, "Buffer full — dropping oldest message")
                    buffer.removeAt(0)
                }
                buffer.add(payload)
            }
            Log.d(TAG, "Buffered message (sink null, foreground active)")
        }
    }

    private fun drainBuffer() {
        val currentSink = sink ?: return
        val pending: List<Map<String, Any?>>
        synchronized(buffer) {
            pending = buffer.toList()
            buffer.clear()
        }
        for (payload in pending) {
            currentSink.success(payload)
        }
        if (pending.isNotEmpty()) {
            Log.d(TAG, "Drained ${pending.size} buffered message(s)")
        }
    }
}

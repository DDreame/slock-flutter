package com.slock.app

import io.flutter.plugin.common.EventChannel

object ForegroundMessageBroker {
    @Volatile
    private var sink: EventChannel.EventSink? = null

    @Volatile
    private var foregroundActive: Boolean = false

    fun attachSink(eventSink: EventChannel.EventSink) {
        sink = eventSink
    }

    fun detachSink() {
        sink = null
    }

    fun setForegroundActive(active: Boolean) {
        foregroundActive = active
    }

    fun push(payload: Map<String, Any?>) {
        if (foregroundActive) {
            sink?.success(payload)
        }
    }
}

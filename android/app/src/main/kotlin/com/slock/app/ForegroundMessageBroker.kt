package com.slock.app

import io.flutter.plugin.common.EventChannel

object ForegroundMessageBroker {
    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attachSink(eventSink: EventChannel.EventSink) {
        sink = eventSink
    }

    fun detachSink() {
        sink = null
    }

    fun push(payload: Map<String, Any?>) {
        sink?.success(payload)
    }
}

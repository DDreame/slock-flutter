package com.slock.app

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class SlockFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val payload = mutableMapOf<String, Any?>()

        remoteMessage.data.forEach { (key, value) ->
            payload[key] = value
        }

        remoteMessage.notification?.let { notification ->
            notification.title?.let { payload["title"] = it }
            notification.body?.let { payload["body"] = it }
        }

        if (payload.isNotEmpty()) {
            ForegroundMessageBroker.push(payload)
        }
    }
}

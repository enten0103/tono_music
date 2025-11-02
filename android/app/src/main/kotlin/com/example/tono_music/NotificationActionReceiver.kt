package com.example.tono_music

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == "toggle_overlay") {
            try { LyricsOverlayModule.toggleOverlayVisibility() } catch (_: Exception) {}
        }
        NotificationModule.sendActionEvent(action)
    }
}

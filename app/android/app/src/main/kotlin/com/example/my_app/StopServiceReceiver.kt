package com.example.my_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Broadcast receiver that handles the stop service action
 * triggered by the notification's close/stop button
 */
class StopServiceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("StopServiceReceiver", "Stop service broadcast received")
        
        // Stop the SMS listener service
        val serviceIntent = Intent(context, SmsListenerService::class.java)
        context.stopService(serviceIntent)
        
        Log.d("StopServiceReceiver", "SMS Listener Service stopped")
    }
}

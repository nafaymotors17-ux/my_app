package com.example.my_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Background service that listens for incoming SMS messages
 * Runs as a foreground service with persistent notification
 * Continues running in the background even when app is closed or swiped
 */
class SmsListenerService : Service() {
    companion object {
        private const val CHANNEL_ID = "sms_listener_channel"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_STOP_SERVICE = "com.example.my_app.STOP_SMS_SERVICE"
    }

    private lateinit var smsReceiver: SmsReceiver

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("SmsListenerService", "Service started - listening for SMS messages")

        // Handle stop service action from notification
        if (intent?.action == ACTION_STOP_SERVICE) {
            Log.d("SmsListenerService", "Stop service action received")
            stopSelf()
            return START_NOT_STICKY
        }

        // Register SMS receiver
        smsReceiver = SmsReceiver()
        val intentFilter = IntentFilter().apply {
            addAction(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.registerReceiver(
                this,
                smsReceiver,
                intentFilter,
                ContextCompat.RECEIVER_EXPORTED
            )
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(smsReceiver, intentFilter)
        }

        // Start foreground service with persistent notification
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // For Android 12+, specify foreground service type
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Service continues running in background even if app is killed
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(smsReceiver)
            Log.d("SmsListenerService", "Service stopped")
        } catch (e: Exception) {
            Log.e("SmsListenerService", "Error unregistering receiver: ${e.message}")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SMS Listener Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors incoming SMS and WhatsApp messages for phishing detection"
                setShowBadge(true)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        // Create intent to open app when notification is tapped
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Create intent to stop service when close button is pressed
        val stopIntent = Intent(this, StopServiceReceiver::class.java).apply {
            action = ACTION_STOP_SERVICE
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Phishing Detector Running")
            .setContentText("Monitoring SMS and notifications for phishing attempts")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(openAppPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop",
                stopPendingIntent
            )
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setAutoCancel(false)
            .build()
    }
}

/**
 * BroadcastReceiver that receives incoming SMS messages
 * Automatically triggered when new SMS arrives
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)

            for (smsMessage in smsMessages) {
                val sender = smsMessage.displayOriginatingAddress
                val messageBody = smsMessage.messageBody
                val timestamp = smsMessage.timestampMillis

                Log.d("SmsReceiver", "SMS received from: $sender")
                Log.d("SmsReceiver", "Message: $messageBody")

                // Save received message info for the app to display
                saveSmsNotification(context, sender, messageBody, timestamp)
            }
        }
    }

    /**
     * Save incoming SMS notification to local storage
     * The app will read this and refresh the message list
     */
    private fun saveSmsNotification(
        context: Context,
        sender: String,
        message: String,
        timestamp: Long
    ) {
        val sharedPrefs = context.getSharedPreferences("sms_notifications", Context.MODE_PRIVATE)
        val notifications = sharedPrefs.getStringSet("pending_sms", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        
        val notificationData = "$sender|$message|$timestamp"
        notifications.add(notificationData)
        
        sharedPrefs.edit().putStringSet("pending_sms", notifications).apply()
        
        Log.d("SmsReceiver", "SMS notification saved to local storage")
    }
}

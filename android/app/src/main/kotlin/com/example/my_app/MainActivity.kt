package com.example.my_app

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.sms_reader/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSmsMessages" -> {
                        val messages = getSmsMessages()
                        result.success(messages)
                    }
                    "getWhatsAppNotifications" -> {
                        val notifications = getWhatsAppNotifications()
                        result.success(notifications)
                    }
                    "enableNotificationListener" -> {
                        enableNotificationListener()
                        result.success(true)
                    }
                    "isNotificationListenerEnabled" -> {
                        val isEnabled = isNotificationListenerEnabled()
                        result.success(isEnabled)
                    }
                    "clearWhatsAppNotifications" -> {
                        // Clear stored notifications saved by the NotificationListenerService
                        val prefs = getSharedPreferences("whatsapp_notifications", Context.MODE_PRIVATE)
                        prefs.edit().remove("notifications").apply()
                        result.success(true)
                    }
                    "testNotificationListener" -> {
                        val result_data = testNotificationListener()
                        result.success(result_data)
                    }
                    "getSmsMessagesWithReadStatus" -> {
                        val messages = getSmsMessagesWithReadStatus()
                        result.success(messages)
                    }
                    "startBackgroundService" -> {
                        val success = startBackgroundSmsService()
                        result.success(success)
                    }
                    "stopBackgroundService" -> {
                        val success = stopBackgroundSmsService()
                        result.success(success)
                    }
                    "isBackgroundServiceRunning" -> {
                        val isRunning = isBackgroundServiceRunning()
                        result.success(isRunning)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getSmsMessages(): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        val contentResolver: ContentResolver = contentResolver
        val uri: Uri = Uri.parse("content://sms/inbox")
        val cursor: Cursor? = contentResolver.query(uri, null, null, null, "date DESC")

        cursor?.use {
            val addressIndex = it.getColumnIndex("address")
            val bodyIndex = it.getColumnIndex("body")
            val dateIndex = it.getColumnIndex("date")

            while (it.moveToNext()) {
                val address = it.getString(addressIndex) ?: "Unknown"
                val body = it.getString(bodyIndex) ?: "No content"
                val date = it.getLong(dateIndex)

                messages.add(
                    mapOf(
                        "address" to address,
                        "body" to body,
                        "date" to date,
                        "source" to "sms"
                    )
                )
            }
        }

        return messages
    }

    private fun getWhatsAppNotifications(): List<Map<String, Any>> {
        val notifications = NotificationListenerService.getStoredNotifications(this)
        return notifications.map {
            mapOf(
                "address" to (it["sender"] as? String ?: "Unknown"),
                "body" to (it["message"] as? String ?: "No content"),
                "date" to (it["timestamp"] as? Long ?: 0L),
                "source" to (it["source"] as? String ?: "whatsapp")
            )
        }
    }

    private fun enableNotificationListener() {
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: ""
        val componentName = "$packageName/com.example.my_app.NotificationListenerService"
        val isEnabled = enabledServices.contains("NotificationListenerService") || 
                       enabledServices.contains(componentName)
        android.util.Log.d("MainActivity", "Enabled services: $enabledServices")
        android.util.Log.d("MainActivity", "Component: $componentName, Enabled: $isEnabled")
        return isEnabled
    }

    private fun testNotificationListener(): Map<String, Any> {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: "No services"
        
        val storedNotifications = NotificationListenerService.getStoredNotifications(this)
        
        return mapOf(
            "enabled_services" to enabledServices,
            "listener_enabled" to isNotificationListenerEnabled(),
            "stored_notifications_count" to storedNotifications.size,
            "latest_notifications" to storedNotifications.take(5)
        )
    }

    // Get SMS messages with read/unread status
    private fun getSmsMessagesWithReadStatus(): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        val contentResolver: ContentResolver = contentResolver
        val uri: Uri = Uri.parse("content://sms/")
        val cursor: Cursor? = contentResolver.query(uri, null, null, null, "date DESC")

        cursor?.use {
            val addressIndex = it.getColumnIndex("address")
            val bodyIndex = it.getColumnIndex("body")
            val dateIndex = it.getColumnIndex("date")
            val readIndex = it.getColumnIndex("read")
            val idIndex = it.getColumnIndex("_id")
            val typeIndex = it.getColumnIndex("type")

            while (it.moveToNext()) {
                val address = it.getString(addressIndex) ?: "Unknown"
                val body = it.getString(bodyIndex) ?: "No content"
                val date = it.getLong(dateIndex)
                val isRead = it.getInt(readIndex) == 1
                val id = it.getString(idIndex) ?: ""
                val type = it.getInt(typeIndex) // 1=received, 2=sent

                messages.add(
                    mapOf(
                        "id" to id,
                        "address" to address,
                        "body" to body,
                        "date" to date,
                        "isRead" to isRead,
                        "type" to type,
                        "source" to "sms"
                    )
                )
            }
        }

        return messages
    }

    // Start background SMS listener service
    private fun startBackgroundSmsService(): Boolean {
        return try {
            val serviceIntent = Intent(this, SmsListenerService::class.java)
            startService(serviceIntent)
            true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to start background service: ${e.message}")
            false
        }
    }

    // Stop background SMS listener service
    private fun stopBackgroundSmsService(): Boolean {
        return try {
            val serviceIntent = Intent(this, SmsListenerService::class.java)
            stopService(serviceIntent)
            true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to stop background service: ${e.message}")
            false
        }
    }

    // Check if background service is running
    private fun isBackgroundServiceRunning(): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        @Suppress("DEPRECATION")
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (SmsListenerService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }
}

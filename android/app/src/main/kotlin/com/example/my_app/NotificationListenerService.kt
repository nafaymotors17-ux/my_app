package com.example.my_app

import android.app.Notification
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class NotificationListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "NotifListener"
        private const val PREFS_NAME = "whatsapp_notifications"
        private const val NOTIFICATIONS_KEY = "notifications"
        
        fun getStoredNotifications(context: Context): List<Map<String, Any>> {
            val notifications = mutableListOf<Map<String, Any>>()
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            try {
                val data = prefs.getString(NOTIFICATIONS_KEY, "[]") ?: "[]"
                Log.d(TAG, "Retrieved data: $data")
                val jsonArray = JSONArray(data)
                
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    notifications.add(
                        mapOf(
                            "sender" to obj.getString("sender"),
                            "message" to obj.getString("message"),
                            "timestamp" to obj.getLong("timestamp"),
                            "source" to obj.getString("source"),
                            "id" to (obj.optString("id", "")),
                            "conversationId" to (obj.optString("conversationId", ""))
                        )
                    )
                }
                Log.d(TAG, "Retrieved ${notifications.size} notifications")
            } catch (e: Exception) {
                Log.e(TAG, "Error retrieving notifications: ${e.message}", e)
            }
            
            return notifications.sortedByDescending { it["timestamp"] as Long }
        }
    }
    
    private fun getSharedPreferences(): SharedPreferences {
        return applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListenerService connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        
        if (sbn == null) return
        
        val packageName = sbn.packageName
        Log.d(TAG, "Notification received from: $packageName")
        
        // Capture WhatsApp notifications (both regular and business)
        if (packageName == "com.whatsapp" || packageName == "com.whatsapp.w4b") {
            try {
                val notification = sbn.notification
                val extras = notification.extras
                
                // Extract sender/contact name
                var sender = extras.getString(Notification.EXTRA_TITLE) ?: "Unknown"
                
                // Try to get more detailed info from notification
                val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
                val summaryText = extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString()
                
                // Extract message content
                var message = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: "No content"
                
                // Also check for big text (full message content)
                val bigText = extras.getCharSequence("android.bigText")?.toString()
                val finalMessage = if (!bigText.isNullOrEmpty()) bigText else message
                
                // Try to extract conversation info if available
                val conversationId = extras.getString("android.conversationId")
                val notificationId = sbn.id.toString()
                
                // Generate unique ID for this notification
                val timestamp = System.currentTimeMillis()
                val uniqueId = "${packageName}_${timestamp}_${sender}_${notificationId}"
                
                Log.d(TAG, "WhatsApp message captured - From: $sender, Text: $finalMessage, ID: $uniqueId")
                
                // Check if this message already exists (deduplication)
                if (!isDuplicate(sender, finalMessage)) {
                    saveNotification(sender, finalMessage, timestamp, uniqueId, conversationId)
                } else {
                    Log.d(TAG, "Duplicate message detected, skipping: From=$sender, Text=$finalMessage")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing WhatsApp notification: ${e.message}", e)
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }

    private fun saveNotification(sender: String, message: String, timestamp: Long, id: String, conversationId: String? = null) {
        try {
            val prefs = getSharedPreferences()
            val existingData = prefs.getString(NOTIFICATIONS_KEY, "[]") ?: "[]"
            val jsonArray = JSONArray(existingData)
            
            val notification = JSONObject().apply {
                put("sender", sender)
                put("message", message)
                put("timestamp", timestamp)
                put("source", "whatsapp")
                put("id", id)
                if (conversationId != null) {
                    put("conversationId", conversationId)
                }
            }
            
            jsonArray.put(notification)
            
            // Keep only last 500 notifications
            if (jsonArray.length() > 500) {
                val newArray = JSONArray()
                for (i in (jsonArray.length() - 100) until jsonArray.length()) {
                    newArray.put(jsonArray.getJSONObject(i))
                }
                prefs.edit().putString(NOTIFICATIONS_KEY, newArray.toString()).apply()
            } else {
                prefs.edit().putString(NOTIFICATIONS_KEY, jsonArray.toString()).apply()
            }
            
            Log.d(TAG, "Notification saved. Total: ${jsonArray.length()}")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving notification: ${e.message}", e)
        }
    }

    private fun isDuplicate(sender: String, message: String): Boolean {
        return try {
            val prefs = getSharedPreferences()
            val existingData = prefs.getString(NOTIFICATIONS_KEY, "[]") ?: "[]"
            val jsonArray = JSONArray(existingData)
            
            // Check last 10 messages for duplicates (to avoid checking entire list)
            val startIndex = maxOf(0, jsonArray.length() - 10)
            for (i in startIndex until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val existingSender = obj.getString("sender")
                val existingMessage = obj.getString("message")
                val existingTimestamp = obj.getLong("timestamp")
                
                // Check if same sender and message within last 5 seconds
                val timeDiff = System.currentTimeMillis() - existingTimestamp
                if (existingSender == sender && existingMessage == message && timeDiff < 5000) {
                    Log.d(TAG, "Duplicate found: sender=$sender, message=$message, timeDiff=$timeDiff ms")
                    return true
                }
            }
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking duplicate: ${e.message}", e)
            false
        }
    }
}
package com.example.my_app

import android.content.ContentResolver
import android.database.Cursor
import android.net.Uri
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
                    "getSmsMessagesWithReadStatus" -> {
                        val messages = getSmsMessagesWithReadStatus()
                        result.success(messages)
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
}

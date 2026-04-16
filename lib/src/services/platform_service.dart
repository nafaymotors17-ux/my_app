import 'package:flutter/services.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.sms_reader/sms',
  );

  static Future<List<dynamic>> getSmsMessages() async {
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getSmsMessages');
      return res ?? <dynamic>[];
    } on PlatformException {
      return <dynamic>[];
    }
  }

  static Future<List<dynamic>> getWhatsAppNotifications() async {
    try {
      final res = await _channel.invokeMethod<List<dynamic>>(
        'getWhatsAppNotifications',
      );
      return res ?? <dynamic>[];
    } on PlatformException {
      return <dynamic>[];
    }
  }

  static Future<void> enableNotificationListener() async {
    await _channel.invokeMethod('enableNotificationListener');
  }

  static Future<bool> isNotificationListenerEnabled() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>(
        'isNotificationListenerEnabled',
      );
      return res ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<Map<dynamic, dynamic>?> testNotificationListener() async {
    try {
      final Map<dynamic, dynamic>? res = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('testNotificationListener');
      return res;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> clearWhatsAppNotifications() async {
    try {
      await _channel.invokeMethod('clearWhatsAppNotifications');
    } on PlatformException {
      // ignore
    }
  }

  // Get SMS messages with read/unread status
  static Future<List<dynamic>> getSmsMessagesWithReadStatus() async {
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getSmsMessagesWithReadStatus');
      return res ?? <dynamic>[];
    } on PlatformException {
      return <dynamic>[];
    }
  }

  // Enable background SMS listener service
  static Future<bool> startBackgroundService() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('startBackgroundService');
      return res ?? false;
    } on PlatformException {
      return false;
    }
  }

  // Stop background SMS listener service
  static Future<bool> stopBackgroundService() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('stopBackgroundService');
      return res ?? false;
    } on PlatformException {
      return false;
    }
  }

  // Check if background service is running
  static Future<bool> isBackgroundServiceRunning() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('isBackgroundServiceRunning');
      return res ?? false;
    } on PlatformException {
      return false;
    }
  }
}

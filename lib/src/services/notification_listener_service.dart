import 'package:my_app/src/services/platform_service.dart';

/// Service for managing notification listener (WhatsApp, etc.)
class NotificationListenerService {
  /// Check if notification listener is enabled
  static Future<bool> isEnabled() async {
    try {
      return await PlatformService.isNotificationListenerEnabled();
    } catch (e) {
      print('Error checking notification listener: $e');
      return false;
    }
  }

  /// Enable notification listener (opens settings)
  static Future<void> enable() async {
    try {
      await PlatformService.enableNotificationListener();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Error enabling notification listener: $e');
      rethrow;
    }
  }

  /// Test notification listener and get debug info
  static Future<Map<dynamic, dynamic>?> getDebugInfo() async {
    try {
      return await PlatformService.testNotificationListener();
    } catch (e) {
      print('Error testing notification listener: $e');
      return null;
    }
  }

  /// Clear WhatsApp notifications storage
  static Future<void> clearNotifications() async {
    try {
      await PlatformService.clearWhatsAppNotifications();
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }
}

import 'package:my_app/src/services/platform_service.dart';

/// Service to manage background SMS/notification listening
class BackgroundListenerService {
  static bool _isRunning = false;

  /// Start background listener service
  static Future<bool> start() async {
    try {
      final success = await PlatformService.startBackgroundService();
      if (success) {
        _isRunning = true;
      }
      return success;
    } catch (e) {
      print('Error starting background service: $e');
      return false;
    }
  }

  /// Stop background listener service
  static Future<bool> stop() async {
    try {
      final success = await PlatformService.stopBackgroundService();
      if (success) {
        _isRunning = false;
      }
      return success;
    } catch (e) {
      print('Error stopping background service: $e');
      return false;
    }
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    try {
      final running = await PlatformService.isBackgroundServiceRunning();
      _isRunning = running;
      return running;
    } catch (e) {
      print('Error checking service status: $e');
      return false;
    }
  }

  /// Get cached running state
  static bool getCachedRunningState() {
    return _isRunning;
  }

  /// Refresh running state from platform
  static Future<void> refreshRunningState() async {
    await isRunning();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/services/platform_service.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageReaderController extends ChangeNotifier {
  List<Message> allMessages = [];
  List<Message> displayedMessages = [];
  bool isLoading = false;
  String selectedFilter = 'all'; // 'all', 'sms', 'whatsapp'
  bool notificationListenerEnabled = false;
  bool backgroundServiceRunning = false;
  SharedPreferences? _prefs;
  Set<String> readIds = <String>{};
  Set<String> clearedIds = <String>{};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    readIds = _prefs?.getStringList('read_ids')?.toSet() ?? <String>{};
    clearedIds = _prefs?.getStringList('cleared_ids')?.toSet() ?? <String>{};
    await requestPermissionsAndLoadMessages();
    await checkBackgroundServiceStatus();
  }

  Future<void> checkBackgroundServiceStatus() async {
    try {
      final bool isRunning = await PlatformService.isBackgroundServiceRunning();
      backgroundServiceRunning = isRunning;
      notifyListeners();
    } catch (e) {
      print('Error checking background service: $e');
    }
  }

  Future<void> requestPermissionsAndLoadMessages() async {
    final PermissionStatus status = await Permission.sms.request();

    if (status.isGranted) {
      loadAllMessages();
      checkNotificationListenerStatus();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> checkNotificationListenerStatus() async {
    try {
      final bool isEnabled =
          await PlatformService.isNotificationListenerEnabled();
      notificationListenerEnabled = isEnabled;
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> startBackgroundService() async {
    try {
      final success = await PlatformService.startBackgroundService();
      if (success) {
        backgroundServiceRunning = true;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stopBackgroundService() async {
    try {
      final success = await PlatformService.stopBackgroundService();
      if (success) {
        backgroundServiceRunning = false;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadAllMessages() async {
    isLoading = true;
    notifyListeners();

    try {
      // Load SMS messages with read/unread status
      final List<dynamic> smsMessages =
          await PlatformService.getSmsMessagesWithReadStatus();
      final List<Message> smsList = (smsMessages).map((message) {
        final Map<dynamic, dynamic> msg = message as Map<dynamic, dynamic>;
        final int ts = msg['date'] as int? ?? 0;
        final String src = msg['source'] as String? ?? 'sms';
        final String address = msg['address'] as String? ?? 'Unknown';
        final bool smsIsRead = msg['isRead'] as bool? ?? false;
        final String id = '${src}_${ts}_${address}';
        return Message(
          id: id,
          address: address,
          body: msg['body'] as String? ?? 'No content',
          date: DateTime.fromMillisecondsSinceEpoch(ts),
          source: src,
          isRead: smsIsRead,
        );
      }).toList();

      // Load WhatsApp notifications
      final List<dynamic> whatsAppMessages =
          await PlatformService.getWhatsAppNotifications();
      final List<Message> whatsappList = (whatsAppMessages).map((message) {
        final Map<dynamic, dynamic> msg = message as Map<dynamic, dynamic>;
        final int ts = msg['date'] as int? ?? 0;
        final String src = msg['source'] as String? ?? 'whatsapp';
        final String address = msg['address'] as String? ?? 'Unknown';
        // Use the ID from notification if available, otherwise generate one
        final String notificationId = msg['id'] as String? ?? '';
        final String id = notificationId.isNotEmpty
            ? notificationId
            : '${src}_${ts}_${address}';
        // Check if this WhatsApp message is marked as read locally
        final bool isLocallyRead = readIds.contains(id);
        return Message(
          id: id,
          address: address,
          body: msg['body'] as String? ?? 'No content',
          date: DateTime.fromMillisecondsSinceEpoch(ts),
          source: src,
          isRead: isLocallyRead, // Track read status locally for WhatsApp
        );
      }).toList();

      // Combine all messages
      final List<Message> combined = [...smsList, ...whatsappList];
      combined.sort((a, b) => b.date.compareTo(a.date));

      allMessages = combined;
      filterMessages();
      isLoading = false;
      notifyListeners();
    } on PlatformException {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void filterMessages() {
    final filtered = (selectedFilter == 'all')
        ? allMessages
        : allMessages.where((msg) => msg.source == selectedFilter).toList();
    // Exclude cleared IDs
    displayedMessages = filtered
        .where((m) => !clearedIds.contains(m.id))
        .toList();
    notifyListeners();
  }

  void setFilter(String filter) {
    selectedFilter = filter;
    filterMessages();
  }

  Future<void> enableNotificationListener() async {
    try {
      await PlatformService.enableNotificationListener();
      await Future.delayed(const Duration(milliseconds: 500));
      await checkNotificationListenerStatus();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> testNotificationListener() async {
    try {
      final result = await PlatformService.testNotificationListener();
      if (result == null) return null;
      return Map<String, dynamic>.from(
        result.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveLocalPrefs() async {
    await PrefsService.saveReadIds(readIds);
    await PrefsService.saveClearedIds(clearedIds);
  }

  void toggleRead(Message msg) {
    if (readIds.contains(msg.id)) {
      readIds.remove(msg.id);
    } else {
      readIds.add(msg.id);
    }
    saveLocalPrefs();
    notifyListeners();
  }

  void clearMessage(Message msg) {
    clearedIds.add(msg.id);
    displayedMessages.removeWhere((m) => m.id == msg.id);
    saveLocalPrefs();
    notifyListeners();
  }

  Future<void> clearAll() async {
    try {
      await PlatformService.clearWhatsAppNotifications();
    } catch (_) {}
    if (_prefs != null) {
      await _prefs?.remove('read_ids');
      await _prefs?.remove('cleared_ids');
    }
    readIds.clear();
    clearedIds.clear();
    allMessages.clear();
    displayedMessages.clear();
    await saveLocalPrefs();
    notifyListeners();
  }

  bool isMessageRead(Message msg) {
    return msg.source == 'sms' ? msg.isRead : readIds.contains(msg.id);
  }
}

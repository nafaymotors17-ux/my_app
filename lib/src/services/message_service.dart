import 'package:my_app/src/services/platform_service.dart';
import 'package:my_app/src/models/message.dart';
import 'package:flutter/services.dart';

/// Service for managing message operations
class MessageService {
  /// Load SMS messages with read/unread status
  static Future<List<Message>> loadSmsMessages() async {
    try {
      final List<dynamic> smsMessages =
          await PlatformService.getSmsMessagesWithReadStatus();
      return smsMessages.map((message) {
        final Map<dynamic, dynamic> msg = message as Map<dynamic, dynamic>;
        final int ts = msg['date'] as int? ?? 0;
        final String src = msg['source'] as String? ?? 'sms';
        final String address = msg['address'] as String? ?? 'Unknown';
        final bool smsIsRead = msg['isRead'] as bool? ?? false;
        final String id = '$src-$ts-$address';
        return Message(
          id: id,
          address: address,
          body: msg['body'] as String? ?? 'No content',
          date: DateTime.fromMillisecondsSinceEpoch(ts),
          source: src,
          isRead: smsIsRead,
        );
      }).toList();
    } on PlatformException catch (e) {
      print('Error loading SMS messages: ${e.message}');
      return <Message>[];
    }
  }

  /// Load all messages (SMS only - Gmail loaded separately by controller)
  static Future<List<Message>> loadAllMessages() async {
    final smsList = await loadSmsMessages();

    final combined = [...smsList];
    combined.sort((a, b) => b.date.compareTo(a.date));

    return combined;
  }

  /// Filter messages by type
  static List<Message> filterMessages(
    List<Message> messages,
    String filter,
    Set<String> clearedIds,
  ) {
    final filtered = (filter == 'all')
        ? messages
        : messages.where((msg) => msg.source == filter).toList();

    return filtered.where((m) => !clearedIds.contains(m.id)).toList();
  }
}

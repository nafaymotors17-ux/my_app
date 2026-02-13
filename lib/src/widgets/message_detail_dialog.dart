import 'package:flutter/material.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

class MessageDetailDialog extends StatelessWidget {
  final Message msg;
  final bool isRead;
  final VoidCallback onToggleRead;
  final VoidCallback onClear;

  const MessageDetailDialog({
    super.key,
    required this.msg,
    required this.isRead,
    required this.onToggleRead,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${msg.source.toUpperCase()} Message',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: msg.source == 'whatsapp'
                  ? Colors.green[100]
                  : Colors.blue[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              msg.source.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: msg.source == 'whatsapp'
                    ? Colors.green[700]
                    : Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'From: ${msg.address}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${DateTimeUtils.formatDate(msg.date)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Message:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(msg.body),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            onToggleRead();
            Navigator.pop(context);
          },
          child: Text(isRead ? 'Mark Unread' : 'Mark Read'),
        ),
        TextButton(
          onPressed: () {
            onClear();
            Navigator.pop(context);
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

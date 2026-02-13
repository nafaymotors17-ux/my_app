import 'package:flutter/material.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

class MessageCard extends StatelessWidget {
  final Message msg;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleRead;

  const MessageCard({
    super.key,
    required this.msg,
    required this.isRead,
    required this.onTap,
    this.onDelete,
    this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      color: isRead ? Colors.grey[50] : Colors.white,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: msg.source == 'whatsapp'
                  ? Colors.green
                  : Colors.blue,
              child: Text(
                msg.address.isNotEmpty
                    ? msg.address[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            // Read/Unread indicator dot
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRead ? Colors.grey : Colors.red,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    msg.address,
                    style: TextStyle(
                      fontWeight: isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                      color: isRead
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
                // Read/Unread status icon
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.grey[200]
                        : Colors.orange[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isRead ? '✓ Read' : '○ Unread',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isRead
                          ? Colors.grey[700]
                          : Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isRead ? Colors.grey : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateTimeUtils.formatDate(msg.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        isThreeLine: true,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show read/unread toggle for both SMS and WhatsApp
            if (onToggleRead != null)
              IconButton(
                icon: Icon(
                  isRead
                      ? Icons.done_all
                      : Icons.done,
                  color: isRead
                      ? Colors.green
                      : Colors.grey,
                ),
                tooltip: isRead
                    ? 'Mark as unread'
                    : 'Mark as read',
                onPressed: onToggleRead,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Clear message',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

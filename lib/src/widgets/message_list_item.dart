import 'package:flutter/material.dart';
import 'package:my_app/src/models/message.dart';

/// Widget for displaying a single message in list view
class MessageListItem extends StatelessWidget {
  final Message message;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MessageListItem({
    Key? key,
    required this.message,
    required this.isRead,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: isRead ? Colors.grey[50] : Colors.white,
      child: ListTile(
        leading: _buildLeadingAvatar(),
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        isThreeLine: true,
        onTap: onTap,
        trailing: _buildTrailing(),
      ),
    );
  }

  Widget _buildLeadingAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: message.source == 'gmail'
              ? Colors.red.shade700
              : Colors.blue,
          child: Text(
            message.address.isNotEmpty ? message.address[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
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
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                message.address,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  color: isRead ? Colors.grey : Colors.black,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isRead ? Colors.grey[200] : Colors.orange[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isRead ? '✓ Read' : '○ Unread',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isRead ? Colors.grey[700] : Colors.orange[900],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: message.source == 'gmail'
                ? Colors.red[100]
                : Colors.blue[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            message.source.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: message.source == 'gmail'
                  ? Colors.red[700]
                  : Colors.blue[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isRead ? Colors.grey : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${message.date.day}/${message.date.month}/${message.date.year}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.source == 'sms')
          Icon(
            isRead ? Icons.done_all : Icons.done,
            color: isRead ? Colors.green : Colors.grey,
            size: 18,
          ),
        IconButton(
          icon: const Icon(Icons.delete),
          iconSize: 18,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

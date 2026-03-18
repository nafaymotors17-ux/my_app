import 'package:flutter/material.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

class MessageCard extends StatelessWidget {
  final Message msg;
  final int? index; // 1-based number (for Gmail list)
  final bool isRead;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleRead;

  const MessageCard({
    super.key,
    required this.msg,
    this.index,
    required this.isRead,
    this.isSelected = false,
    required this.onTap,
    this.onDelete,
    this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final isGmail = msg.source == 'gmail';
    final sourceColor = msg.source == 'gmail'
        ? Colors.red.shade700
        : Colors.blue;
    final isSpam = msg.gmailLabel == 'SPAM';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      elevation: isSelected ? 3 : 0,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSpam
            ? BorderSide(color: Colors.orange.shade300, width: 1.5)
            : BorderSide(color: Colors.grey.shade200),
      ),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
          : isRead
              ? Colors.grey.shade50
              : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Number badge (Gmail) or Avatar
              if (index != null)
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sourceColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: sourceColor,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: sourceColor.withValues(alpha: 0.2),
                    child: Icon(
                      isGmail ? Icons.mail : Icons.sms,
                      color: sourceColor,
                      size: 24,
                    ),
                  ),
                  if (!isRead)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isGmail ? (msg.subject ?? '(No subject)') : msg.address,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                              fontSize: 15,
                              color: isRead ? Colors.grey[700] : Colors.black87,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateTimeUtils.formatDate(msg.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sourceColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isGmail
                                ? (isSpam ? 'SPAM' : (msg.gmailLabel == 'SENT' ? 'SENT' : 'INBOX'))
                                : msg.source.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: sourceColor,
                            ),
                          ),
                        ),
                        if (isRead) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.done_all, size: 14, color: Colors.grey[600]),
                        ],
                      ],
                    ),
                    if (isGmail)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          msg.gmailLabel == 'SENT' ? 'To: ${msg.address}' : 'From: ${msg.address}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      msg.body.trim().isEmpty ? '(No content)' : msg.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead ? Colors.grey[600] : Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onToggleRead != null)
                    IconButton(
                      icon: Icon(isRead ? Icons.mark_email_unread : Icons.done_all, size: 20),
                      tooltip: isRead ? 'Mark unread' : 'Mark read',
                      onPressed: onToggleRead,
                      color: isRead ? Colors.grey : sourceColor,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Clear',
                      onPressed: onDelete,
                      color: Colors.grey[600],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

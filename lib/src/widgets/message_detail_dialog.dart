import 'package:flutter/material.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

class MessageDetailDialog extends StatelessWidget {
  final Message msg;
  final bool isRead;
  final VoidCallback onToggleRead;
  final VoidCallback onClear;
  final Future<void> Function()? onMarkAsSpam;
  final Future<void> Function()? onTrash;
  /// Optional: fetch full body on demand (for Gmail - list uses snippet only)
  final Future<String>? fullBodyFuture;

  const MessageDetailDialog({
    super.key,
    required this.msg,
    required this.isRead,
    required this.onToggleRead,
    required this.onClear,
    this.onMarkAsSpam,
    this.onTrash,
    this.fullBodyFuture,
  });

  @override
  Widget build(BuildContext context) {
    final isGmail = msg.source == 'gmail';
    final sourceColor = msg.source == 'whatsapp'
        ? Colors.green
        : msg.source == 'gmail'
            ? Colors.red.shade700
            : Colors.blue;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mail, color: sourceColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isGmail ? (msg.subject ?? '(No subject)') : '${msg.source.toUpperCase()} Message',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sourceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isGmail ? (msg.gmailLabel ?? 'INBOX') : msg.source.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sourceColor),
                ),
              ),
            ],
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow(context, 'From', msg.address),
            if (isGmail && msg.gmailTo != null && msg.gmailTo!.isNotEmpty)
              _buildInfoRow(context, 'To', msg.gmailTo!),
            _buildInfoRow(context, 'Date', DateTimeUtils.formatDate(msg.date)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            fullBodyFuture != null
                ? FutureBuilder<String>(
                    future: fullBodyFuture,
                    builder: (context, snapshot) {
                      final body = snapshot.hasData && snapshot.data!.isNotEmpty
                          ? snapshot.data!
                          : msg.body;
                      if (snapshot.connectionState == ConnectionState.waiting && body.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildBodyContainer(body);
                    },
                  )
                : _buildBodyContainer(msg.body),
          ],
        ),
      ),
      actions: [
        if (isGmail && onMarkAsSpam != null)
          TextButton.icon(
            onPressed: () async {
              await onMarkAsSpam!();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marked as spam'), backgroundColor: Colors.orange),
                );
              }
            },
            icon: const Icon(Icons.report, size: 18),
            label: const Text('Spam'),
          ),
        if (isGmail && onTrash != null)
          TextButton.icon(
            onPressed: () async {
              await onTrash!();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Moved to trash'), backgroundColor: Colors.orange),
                );
              }
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Trash'),
          ),
        TextButton.icon(
          onPressed: () {
            onToggleRead();
            Navigator.pop(context);
          },
          icon: Icon(isRead ? Icons.mark_email_unread : Icons.done_all, size: 18),
          label: Text(isRead ? 'Mark Unread' : 'Mark Read'),
        ),
        TextButton.icon(
          onPressed: () {
            onClear();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.clear, size: 18),
          label: const Text('Clear'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildBodyContainer(String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        body.trim().isEmpty ? '(No content)' : body,
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

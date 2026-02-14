import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final String selectedFilter;
  final VoidCallback onLoadMessages;
  final String? gmailLabel; // INBOX or SPAM - for more specific empty message

  const EmptyStateWidget({
    super.key,
    required this.selectedFilter,
    required this.onLoadMessages,
    this.gmailLabel,
  });

  @override
  Widget build(BuildContext context) {
    final icon = selectedFilter == 'gmail'
        ? Icons.mail
        : selectedFilter == 'whatsapp'
            ? Icons.chat
            : Icons.sms;
    String label = selectedFilter == 'all'
        ? 'No messages found'
        : selectedFilter == 'gmail'
            ? (gmailLabel == 'SPAM' ? 'No spam emails' : 'No unread emails in inbox')
            : selectedFilter == 'whatsapp'
                ? 'No WhatsApp messages'
                : 'No SMS messages';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onLoadMessages,
            child: Text(selectedFilter == 'gmail' ? 'Refresh Emails' : 'Load Messages'),
          ),
        ],
      ),
    );
  }
}

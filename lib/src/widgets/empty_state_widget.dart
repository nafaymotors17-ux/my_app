import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final String selectedFilter;
  final VoidCallback onLoadMessages;

  const EmptyStateWidget({
    super.key,
    required this.selectedFilter,
    required this.onLoadMessages,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selectedFilter == 'whatsapp' ? Icons.chat : Icons.sms,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            selectedFilter == 'all'
                ? 'No messages found'
                : 'No ${selectedFilter == 'whatsapp' ? 'WhatsApp' : 'SMS'} messages',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onLoadMessages,
            child: const Text('Load Messages'),
          ),
        ],
      ),
    );
  }
}

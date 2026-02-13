import 'package:flutter/material.dart';

class NotificationListenerDialogs {
  static void showEnableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notification Access'),
        content: const Text(
          'To capture WhatsApp messages:\n\n'
          '1. Find "Phishing Detector" in the list\n'
          '2. Toggle ON to enable it\n'
          '3. Your status will show "Active" when enabled\n\n'
          'After enabling, send yourself a WhatsApp message to test!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void showTestDialog(BuildContext context, Map<String, dynamic> testResult) {
    final enabledServices = testResult['enabled_services'] ?? 'Unknown';
    final listenerEnabled = testResult['listener_enabled'] ?? false;
    final notifCount = testResult['stored_notifications_count'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Listener Debug'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    listenerEnabled ? Icons.check_circle : Icons.cancel,
                    color: listenerEnabled ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(listenerEnabled ? 'ENABLED' : 'DISABLED'),
                ],
              ),
              const SizedBox(height: 12),
              Text('Stored Notifications: $notifCount'),
              const SizedBox(height: 12),
              const Text(
                'Enabled Services:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                enabledServices.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showClearAllDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Messages'),
        content: const Text(
          'This will clear stored WhatsApp notifications and local read/cleared state. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showClearMessageDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Message'),
        content: const Text(
          'Remove this message from the list? (won\'t delete SMS from device)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

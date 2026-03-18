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
    final isGmail = selectedFilter == 'gmail';
    final icon = isGmail ? Icons.mail_outline_rounded : Icons.sms_outlined;
    final label = isGmail
        ? 'No emails here'
        : 'No unread SMS messages';
    final subtitle = isGmail
        ? 'Pull down to refresh or switch folder'
        : 'Grant SMS permission to load messages';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onLoadMessages,
              icon: Icon(isGmail ? Icons.refresh_rounded : Icons.inbox_rounded, size: 20),
              label: Text(isGmail ? 'Refresh emails' : 'Load messages'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

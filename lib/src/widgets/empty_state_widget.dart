import 'package:flutter/material.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';

class EmptyStateWidget extends StatelessWidget {
  final String selectedFilter;
  final InboxSegment? inboxSegment;

  const EmptyStateWidget({
    super.key,
    required this.selectedFilter,
    this.inboxSegment,
  });

  @override
  Widget build(BuildContext context) {
    final isGmail = selectedFilter == 'gmail';
    final seg = inboxSegment ?? InboxSegment.all;

    late final IconData icon;
    late final String label;
    late final String subtitle;

    if (seg == InboxSegment.phishing) {
      icon = Icons.verified_user_outlined;
      label = 'No phishing matches here';
      subtitle = isGmail
          ? 'Scan emails with the shield in the app bar, or switch to All to browse messages.'
          : 'Scan SMS with the shield in the app bar, or switch to All.';
    } else if (seg == InboxSegment.safe) {
      icon = Icons.shield_outlined;
      label = 'No safe scans yet';
      subtitle =
          '“Safe” lists only messages you scanned and the model marked as safe. '
          'Use All to see everything, or scan messages with the shield icon.';
    } else if (isGmail) {
      icon = Icons.mail_outline_rounded;
      label = 'No emails here';
      subtitle = 'Sign in to Gmail and pull to refresh, or pick another folder.';
    } else {
      icon = Icons.sms_outlined;
      label = 'No unread SMS messages';
      subtitle = 'Grant SMS permission to load messages, or pull to refresh.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
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
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

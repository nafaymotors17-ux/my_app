import 'package:flutter/material.dart';

/// Onboarding-style help for examiners and users.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(
            icon: Icons.home_outlined,
            title: 'Home',
            body:
                'Overview and quick navigation to SMS, Email, and the Threat inbox. '
                'Statistics reflect scan results stored on this device.',
          ),
          _Section(
            icon: Icons.sms_outlined,
            title: 'SMS',
            body:
                'Grant SMS permission when prompted. The list shows unread messages. '
                'Select a message, then use the shield in the app bar to run the API check. '
                'Use AI separation chips to show All, only Phishing-scanned, or only Safe-scanned items.',
          ),
          _Section(
            icon: Icons.mail_outline,
            title: 'Email (Gmail)',
            body:
                'Sign in with Google from the mail icon. The list shows Inbox unread '
                'messages only, with Previous/Next paging. Open a message and scan with the shield; '
                'the model uses the fetched body text.',
          ),
          _Section(
            icon: Icons.shield_outlined,
            title: 'Threat inbox',
            body:
                'Lists every message you scanned that was classified as phishing. '
                'Swipe to remove a row — this only deletes the saved result, not the original message.',
          ),
          _Section(
            icon: Icons.filter_alt_outlined,
            title: 'Gmail vs AI Phishing',
            body:
                'This app loads only unread Inbox mail. Gmail’s own spam filters run '
                'before messages arrive. The Phishing chip shows items your model flagged '
                'after you scanned them.',
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tip: pull down on a list to refresh.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.outline,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer.withValues(alpha: 0.6),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

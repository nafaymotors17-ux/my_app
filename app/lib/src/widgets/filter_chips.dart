import 'package:flutter/material.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';

/// AI segment filters. Gmail is Inbox · unread only (no folder switcher).
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.mode,
    required this.inboxSegment,
    required this.onInboxSegmentChanged,
    this.gmailSignedIn = false,
    this.gmailLoading = false,
  });

  final MessageReaderMode mode;
  final InboxSegment inboxSegment;
  final void Function(InboxSegment) onInboxSegmentChanged;
  final bool gmailSignedIn;
  final bool gmailLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mode == MessageReaderMode.email && gmailSignedIn) ...[
              Row(
                children: [
                  Icon(Icons.inbox_outlined, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Inbox · unread messages only',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (mode == MessageReaderMode.email && !gmailSignedIn)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Use the mail icon above to sign in to Gmail.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            SegmentedButton<InboxSegment>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
              ),
              segments: const [
                ButtonSegment<InboxSegment>(
                  value: InboxSegment.all,
                  label: Text('All'),
                  icon: Icon(Icons.list_alt_rounded, size: 18),
                ),
                ButtonSegment<InboxSegment>(
                  value: InboxSegment.phishing,
                  label: Text('Phishing'),
                  icon: Icon(Icons.warning_amber_rounded, size: 18),
                ),
                ButtonSegment<InboxSegment>(
                  value: InboxSegment.safe,
                  label: Text('Safe'),
                  icon: Icon(Icons.verified_user_outlined, size: 18),
                ),
              ],
              selected: {inboxSegment},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                final seg = set.first;
                if (seg != inboxSegment) {
                  onInboxSegmentChanged(seg);
                }
              },
            ),
            if (gmailLoading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(2),
                  color: cs.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

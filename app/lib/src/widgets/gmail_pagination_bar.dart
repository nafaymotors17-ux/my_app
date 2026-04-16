import 'package:flutter/material.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';

/// Previous / next controls for inbox unread pages (Gmail API page tokens).
class GmailPaginationBar extends StatelessWidget {
  const GmailPaginationBar({
    super.key,
    required this.controller,
  });

  final MessageReaderController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final est = controller.gmailResultSizeEstimate;

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: controller.gmailLoadingMore ||
                          !controller.gmailHasPreviousPage
                      ? null
                      : controller.gmailGoToPreviousPage,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Page ${controller.gmailPageNumber}'
                        '${controller.gmailCachedPageCount > 0 ? ' · ${controller.gmailCachedPageCount} loaded' : ''}',
                        textAlign: TextAlign.center,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (est > 0)
                        Text(
                          '~$est unread in Inbox (estimate)',
                          textAlign: TextAlign.center,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                controller.gmailLoadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: controller.gmailHasNextPage
                            ? 'Next page'
                            : 'No more pages',
                        onPressed: !controller.gmailHasNextPage
                            ? null
                            : () => controller.gmailGoToNextPage(),
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: controller.gmailHasNextPage
                              ? cs.primary
                              : cs.outline,
                        ),
                      ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(
                '${controller.displayedMessages.length} messages on this page · Inbox, unread only',
                textAlign: TextAlign.center,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

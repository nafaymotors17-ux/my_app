import 'package:flutter/material.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/models/phishing_scan_record.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

class MessageCard extends StatelessWidget {
  final Message msg;
  final int? index;
  final bool isRead;
  final bool isSelected;
  final VoidCallback onTap;
  final PhishingScanRecord? aiScan;

  /// Multi-select batch scan mode — tap toggles [isChecked].
  final bool selectionMode;
  final bool isChecked;
  final VoidCallback? onLongPress;

  const MessageCard({
    super.key,
    required this.msg,
    this.index,
    required this.isRead,
    this.isSelected = false,
    required this.onTap,
    this.aiScan,
    this.selectionMode = false,
    this.isChecked = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isGmail = msg.source == 'gmail';
    final isSpam = msg.gmailLabel == 'SPAM';
    final sourceColor =
        isGmail ? const Color(0xFFB91C1C) : const Color(0xFF0D9488);

    final title = isGmail ? (msg.subject ?? '(No subject)') : msg.address;

    final bool showSingleStrip = isSelected && !selectionMode;
    final Color borderColor = selectionMode && isChecked
        ? cs.primary
        : showSingleStrip
            ? cs.primary
            : isSpam
                ? const Color(0xFFFDBA74)
                : cs.outline.withValues(alpha: 0.12);
    final double borderW =
        (selectionMode && isChecked) || showSingleStrip ? 2 : 1;

    return Material(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: borderW),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectionMode)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 10),
                child: Checkbox(
                  value: isChecked,
                  onChanged: (_) => onTap(),
                ),
              )
            else if (showSingleStrip)
              Container(width: 4, color: cs.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index != null)
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sourceColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$index',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: sourceColor,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      cs.primaryContainer.withValues(alpha: 0.6),
                                  child: Icon(
                                    isGmail ? Icons.mail_rounded : Icons.sms_rounded,
                                    color: cs.onPrimaryContainer,
                                    size: 22,
                                  ),
                                ),
                                if (!isRead)
                                  Positioned(
                                    right: -1,
                                    top: -1,
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: cs.surface,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.titleSmall?.copyWith(
                                          fontWeight:
                                              isRead ? FontWeight.w500 : FontWeight.w700,
                                          color: isRead
                                              ? cs.onSurface.withValues(alpha: 0.65)
                                              : cs.onSurface,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateTimeUtils.formatDate(msg.date),
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.outline,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _SourceChip(
                                      label: isGmail
                                          ? (isSpam
                                              ? 'SPAM'
                                              : (msg.gmailLabel == 'SENT'
                                                  ? 'SENT'
                                                  : 'INBOX'))
                                          : 'SMS',
                                      color: sourceColor,
                                    ),
                                    if (aiScan != null)
                                      _AiChip(
                                        isPhishing: aiScan!.isPhishing,
                                        confidence: aiScan!.phishingProbability,
                                      ),
                                    if (isRead)
                                      Icon(
                                        Icons.done_all_rounded,
                                        size: 14,
                                        color: cs.outline,
                                      ),
                                  ],
                                ),
                                if (isGmail) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    msg.gmailLabel == 'SENT'
                                        ? 'To: ${msg.address}'
                                        : 'From: ${msg.address}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.outline,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  msg.body.trim().isEmpty
                                      ? '(No content)'
                                      : msg.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodyMedium?.copyWith(
                                    height: 1.35,
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

class _AiChip extends StatelessWidget {
  const _AiChip({required this.isPhishing, this.confidence});

  final bool isPhishing;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final bg = isPhishing
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFD1FAE5);
    final fg = isPhishing
        ? const Color(0xFFB91C1C)
        : const Color(0xFF047857);
    final riskPct = confidence != null
        ? '${(confidence! * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%'
        : null;
    final pctLabel = riskPct == null ? '' : ' · $riskPct risk';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPhishing ? Icons.warning_amber_rounded : Icons.verified_rounded,
            size: 12,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            isPhishing ? 'PHISHING$pctLabel' : 'SAFE$pctLabel',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

class MessageCard extends StatelessWidget {
  final Message msg;
  final int? index;
  final bool isRead;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleRead;
  final VoidCallback? onCheckAi;
  final bool isCheckingAi;
  final int? aiPrediction;
  final String? aiResult;

  const MessageCard({
    super.key,
    required this.msg,
    this.index,
    required this.isRead,
    this.isSelected = false,
    required this.onTap,
    this.onDelete,
    this.onToggleRead,
    this.onCheckAi,
    this.isCheckingAi = false,
    this.aiPrediction,
    this.aiResult,
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

    return Material(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? cs.primary
              : isSpam
                  ? const Color(0xFFFDBA74)
                  : cs.outline.withValues(alpha: 0.12),
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSelected)
                Container(width: 4, color: cs.primary),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
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
                                if (onCheckAi != null) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed:
                                            isCheckingAi ? null : onCheckAi,
                                        icon: isCheckingAi
                                            ? SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: cs.primary,
                                                ),
                                              )
                                            : Icon(
                                                Icons.shield_rounded,
                                                size: 18,
                                                color: cs.primary,
                                              ),
                                        label: Text(
                                          isCheckingAi
                                              ? 'Scanning…'
                                              : isGmail
                                                  ? 'Scan email'
                                                  : 'Scan SMS',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        style: FilledButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      if (aiPrediction != null &&
                                          aiResult != null)
                                        _AiResultChip(
                                          prediction: aiPrediction!,
                                          label: aiResult!,
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (onToggleRead != null)
                    IconButton(
                      icon: Icon(
                        isRead
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                        size: 20,
                      ),
                      tooltip: isRead ? 'Mark unread' : 'Mark read',
                      onPressed: onToggleRead,
                      color: isRead ? cs.outline : cs.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.outline),
                      tooltip: 'Remove',
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
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

class _AiResultChip extends StatelessWidget {
  const _AiResultChip({
    required this.prediction,
    required this.label,
  });

  final int prediction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isRisk = prediction == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isRisk
            ? const Color(0xFFFFF1F2)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRisk
              ? const Color(0xFFFECDD3)
              : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRisk ? Icons.warning_amber_rounded : Icons.verified_rounded,
            size: 16,
            color: isRisk ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isRisk ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:my_app/src/services/sms_ai_service.dart';

class EmailAiCheckCard extends StatefulWidget {
  final String messageText;

  const EmailAiCheckCard({super.key, required this.messageText});

  @override
  State<EmailAiCheckCard> createState() => _EmailAiCheckCardState();
}

class _EmailAiCheckCardState extends State<EmailAiCheckCard> {
  bool _checkingEmailText = false;

  SmsAiResult? _emailTextResult;

  String? _error;

  @override
  void didUpdateWidget(covariant EmailAiCheckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageText != widget.messageText) {
      setState(() {
        _emailTextResult = null;
        _error = null;
      });
    }
  }

  Future<void> _checkEmailText() async {
    if (_checkingEmailText) return;
    setState(() {
      _checkingEmailText = true;
      _error = null;
    });

    try {
      final res = await SmsAiService.checkEmailText(widget.messageText);
      if (!mounted) return;
      setState(() => _emailTextResult = res);
    } catch (e, st) {
      debugPrint('Email AI text check failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() => _error = SmsAiService.describeNetworkError(e));
    } finally {
      if (!mounted) return;
      setState(() => _checkingEmailText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final et = _emailTextResult;
    final isPhishing = et != null && et.prediction == 1;
    final showBodyConfidence = et != null &&
        et.prediction == 1 &&
        et.phishingProbability != null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    color: cs.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email scan',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Scans the email body text with the same model as SMS.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (et != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isPhishing
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPhishing
                        ? const Color(0xFFFECDD3)
                        : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPhishing
                                ? Icons.warning_amber_rounded
                                : Icons.verified_rounded,
                            size: 22,
                            color: isPhishing
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF15803D),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isPhishing
                                  ? 'Potential phishing'
                                  : 'No phishing detected',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isPhishing) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Treat this email as suspicious. Do not open unexpected attachments or sign in through email links.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      if (!isPhishing && et.phishingProbability != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Estimated phishing risk: ${et.phishingPercentLabel} '
                          '(phishing probability — not flagged).',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (showBodyConfidence) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Estimated phishing risk',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.outline,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value:
                                et.phishingProbability!.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: cs.surfaceContainerHighest,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          et.phishingConfidenceLine ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB91C1C),
                  height: 1.35,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _checkingEmailText ? null : _checkEmailText,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _checkingEmailText
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Icon(Icons.text_fields_rounded, size: 22),
                label: Text(
                  _checkingEmailText ? 'Scanning…' : 'Scan email text',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

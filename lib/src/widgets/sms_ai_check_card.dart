import 'package:flutter/material.dart';
import 'package:my_app/src/services/sms_ai_service.dart';

class SmsAiCheckCard extends StatefulWidget {
  final String messageText;

  const SmsAiCheckCard({super.key, required this.messageText});

  @override
  State<SmsAiCheckCard> createState() => _SmsAiCheckCardState();
}

class _SmsAiCheckCardState extends State<SmsAiCheckCard> {
  bool _loading = false;
  SmsAiResult? _result;
  String? _error;

  @override
  void didUpdateWidget(covariant SmsAiCheckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageText != widget.messageText) {
      setState(() {
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _runCheck() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await SmsAiService.checkSms(widget.messageText);
      if (mounted) setState(() => _result = res);
    } catch (e, st) {
      debugPrint('SMS AI check failed: $e');
      debugPrint('$st');
      if (mounted) {
        setState(() => _error = SmsAiService.describeNetworkError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = _result;
    final isPhishing = r != null && r.prediction == 1;
    final showConfidence = r != null &&
        r.prediction == 1 &&
        r.phishingProbability != null;

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
                    Icons.shield_rounded,
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
                        'Message scan',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Check this SMS for phishing before you tap links or reply.',
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
          if (r != null)
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
                    width: 1,
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
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isPhishing) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Do not tap links, share codes, or send money. '
                          'If it claims to be your bank or carrier, contact them through their official app or number.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      if (!isPhishing && r.phishingProbability != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Estimated phishing risk: ${r.phishingPercentLabel} '
                          '(phishing probability — not flagged).',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (showConfidence) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Estimated phishing risk',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.outline,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: r.phishingProbability!.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: cs.surfaceContainerHighest,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r.phishingConfidenceLine ?? '',
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              onPressed: _loading ? null : _runCheck,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.radar_rounded, size: 22),
              label: Text(
                _loading ? 'Scanning…' : 'Scan this message',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

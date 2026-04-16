import 'package:flutter/material.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';
import 'package:my_app/src/services/sms_ai_service.dart';

/// Scan arbitrary pasted text — no message selection required.
class QuickScanSheet extends StatefulWidget {
  const QuickScanSheet({
    super.key,
    required this.initialMode,
  });

  final MessageReaderMode initialMode;

  static Future<void> show(
    BuildContext context, {
    MessageReaderMode initialMode = MessageReaderMode.sms,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: QuickScanSheet(initialMode: initialMode),
      ),
    );
  }

  @override
  State<QuickScanSheet> createState() => _QuickScanSheetState();
}

class _QuickScanSheetState extends State<QuickScanSheet> {
  late MessageReaderMode _mode;
  final _textController = TextEditingController();
  bool _busy = false;
  String? _lastResult;
  bool? _lastPhishing;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    final raw = _textController.text.trim();
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paste or type a message to scan')),
        );
      }
      return;
    }
    setState(() {
      _busy = true;
      _lastResult = null;
      _lastPhishing = null;
    });
    try {
      final SmsAiResult result;
      if (_mode == MessageReaderMode.sms) {
        result = await SmsAiService.checkSms(raw);
      } else {
        result = await SmsAiService.checkEmailText(raw);
      }
      if (!mounted) return;
      final pct = result.phishingProbability != null
          ? ' (${result.phishingPercentLabel} confidence)'
          : '';
      setState(() {
        _lastPhishing = result.prediction == 1;
        _lastResult = result.prediction == 1
            ? 'Phishing risk detected$pct'
            : 'Looks safe$pct';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastResult = SmsAiService.describeNetworkError(e);
        _lastPhishing = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quick scan',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Paste SMS or email text. Nothing is saved unless you scan from a message list.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SegmentedButton<MessageReaderMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<MessageReaderMode>(
                  value: MessageReaderMode.sms,
                  label: Text('SMS model'),
                  icon: Icon(Icons.sms_outlined, size: 18),
                ),
                ButtonSegment<MessageReaderMode>(
                  value: MessageReaderMode.email,
                  label: Text('Email model'),
                  icon: Icon(Icons.mail_outline, size: 18),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                setState(() => _mode = set.first);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 6,
              minLines: 4,
              decoration: InputDecoration(
                hintText: 'Paste suspicious text here…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _runScan,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield_rounded),
              label: Text(_busy ? 'Scanning…' : 'Scan'),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              Material(
                color: _lastPhishing == true
                    ? const Color(0xFFFEE2E2)
                    : _lastPhishing == false
                        ? const Color(0xFFD1FAE5)
                        : cs.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _lastPhishing == true
                            ? Icons.warning_amber_rounded
                            : _lastPhishing == false
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                        color: _lastPhishing == true
                            ? const Color(0xFFB91C1C)
                            : _lastPhishing == false
                                ? const Color(0xFF047857)
                                : cs.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _lastResult!,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

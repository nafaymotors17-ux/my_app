import 'package:flutter/material.dart';
import 'package:my_app/src/services/prefs_service.dart';
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
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final url = await SmsAiService.getBaseUrl();
    if (!mounted) return;
    setState(() => _baseUrl = url);
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
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editBaseUrl() async {
    final current = _baseUrl ?? SmsAiService.defaultBaseUrl();
    final controller = TextEditingController(text: current);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI API Base URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Example',
            hintText: 'http://10.0.2.2:8000',
          ),
          autocorrect: false,
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == null) return;
    await PrefsService.setAiBaseUrl(saved);
    if (!mounted) return;
    setState(() {
      _baseUrl = saved;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPhishing = _result?.prediction == 1;
    final badgeColor = isPhishing ? Colors.red : Colors.green;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security_rounded, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI SMS Check',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_result != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _result!.result,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _baseUrl == null ? 'API: loading…' : 'API: $_baseUrl',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _editBaseUrl,
                  child: const Text('Change'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _runCheck,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_loading ? 'Checking…' : 'Check this SMS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:my_app/src/services/sms_ai_service.dart';

class EmailAiCheckCard extends StatefulWidget {
  final String messageText;

  const EmailAiCheckCard({super.key, required this.messageText});

  @override
  State<EmailAiCheckCard> createState() => _EmailAiCheckCardState();
}

class _EmailAiCheckCardState extends State<EmailAiCheckCard> {
  bool _checkingEmailText = false;
  bool _checkingUrls = false;

  SmsAiResult? _emailTextResult;
  UrlLinksResult? _urlLinksResult;

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

  List<String> _extractUrls(String text) {
    final Set<String> urls = <String>{};

    // Prefer anchor href values from HTML.
    final hrefDouble =
        RegExp(r'href\s*=\s*"([^"]+)"', caseSensitive: false);
    final hrefSingle =
        RegExp(r"href\s*=\s*'([^']+)'", caseSensitive: false);

    for (final m in hrefDouble.allMatches(text)) {
      final url = (m.group(1) ?? '').trim();
      if (url.isEmpty) continue;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        urls.add(url);
      } else if (url.startsWith('www.')) {
        urls.add('http://$url');
      }
    }

    for (final m in hrefSingle.allMatches(text)) {
      final url = (m.group(1) ?? '').trim();
      if (url.isEmpty) continue;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        urls.add(url);
      } else if (url.startsWith('www.')) {
        urls.add('http://$url');
      }
    }

    // Also detect plain URLs inside text.
    final urlRegex =
        RegExp(r'\bhttps?://[^\s<>()"]+', caseSensitive: false);
    for (final m in urlRegex.allMatches(text)) {
      final url = m.group(0)?.trim() ?? '';
      if (url.isEmpty) continue;
      urls.add(url);
    }

    return urls.toList();
  }

  Future<void> _checkEmailText() async {
    if (_checkingEmailText || _checkingUrls) return;
    setState(() {
      _checkingEmailText = true;
      _error = null;
    });

    try {
      final res = await SmsAiService.checkEmailText(widget.messageText);
      if (!mounted) return;
      setState(() => _emailTextResult = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _checkingEmailText = false);
    }
  }

  Future<void> _checkUrls() async {
    if (_checkingUrls || _checkingEmailText) return;
    setState(() {
      _checkingUrls = true;
      _error = null;
    });

    try {
      final urls = _extractUrls(widget.messageText);
      if (urls.isEmpty) {
        if (!mounted) return;
        setState(() => _urlLinksResult = UrlLinksResult(
              links: const [],
              overallPrediction: 0,
              overallResult: 'Safe',
            ));
        return;
      }

      final res = await SmsAiService.checkUrls(urls);
      if (!mounted) return;
      setState(() => _urlLinksResult = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _checkingUrls = false);
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
            labelText: 'Base URL',
            hintText: 'http://127.0.0.1:8000',
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
      _emailTextResult = null;
      _urlLinksResult = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emailIsPhishing = _emailTextResult?.prediction == 1;
    final emailBadgeColor = emailIsPhishing ? Colors.red : Colors.green;

    final suspiciousLinks =
        _urlLinksResult?.links.where((l) => l.prediction == 1).length ?? 0;

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
                    'AI Email Check',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_emailTextResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: emailBadgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: emailBadgeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _emailTextResult!.result,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: emailBadgeColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_emailTextResult != null) ...[
              Text(
                'Email text result: ${_emailTextResult!.result}',
                style: TextStyle(fontSize: 12, color: cs.outline),
              ),
              const SizedBox(height: 6),
            ],
            if (_urlLinksResult != null) ...[
              Text(
                'Links result: ${_urlLinksResult!.overallResult} (suspicious: $suspiciousLinks)',
                style: TextStyle(fontSize: 12, color: cs.outline),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 4),
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
                  onPressed: (_checkingEmailText || _checkingUrls) ? null : _editBaseUrl,
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
              child: Column(
                children: [
                  FilledButton.icon(
                    onPressed:
                        _checkingEmailText ? null : _checkEmailText,
                    icon: _checkingEmailText
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.text_fields_rounded),
                    label: Text(
                      _checkingEmailText ? 'Checking email text…' : 'Check Email Text',
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _checkingUrls ? null : _checkUrls,
                    icon: _checkingUrls
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link_rounded),
                    label: Text(
                      _checkingUrls ? 'Checking links…' : 'Check Links',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


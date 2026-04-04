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

  @override
  void didUpdateWidget(covariant EmailAiCheckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageText != widget.messageText) {
      setState(() {
        _emailTextResult = null;
        _urlLinksResult = null;
        _error = null;
      });
    }
  }

  List<String> _extractUrls(String text) {
    final Set<String> urls = <String>{};

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
        setState(() => _urlLinksResult = const UrlLinksResult(
              links: [],
              overallPrediction: 0,
              overallResult: 'Safe',
            ));
        return;
      }

      final res = await SmsAiService.checkUrls(urls);
      if (!mounted) return;
      setState(() => _urlLinksResult = res);
    } catch (e, st) {
      debugPrint('URL AI check failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() => _error = SmsAiService.describeNetworkError(e));
    } finally {
      if (!mounted) return;
      setState(() => _checkingUrls = false);
    }
  }

  Future<void> _editServer() async {
    final current = await SmsAiService.getBaseUrl();
    if (!mounted) return;
    final controller = TextEditingController(text: current);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detector server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Base URL only (no path).',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: SmsAiService.productionBaseUrl,
                border: const OutlineInputBorder(),
              ),
              autocorrect: false,
              keyboardType: TextInputType.url,
            ),
          ],
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
      _emailTextResult = null;
      _urlLinksResult = null;
      _error = null;
    });
  }

  String? _linkConfidence(EmailUrlPrediction l) {
    if (l.prediction != 1 || l.phishingProbability == null) return null;
    final pct = (l.phishingProbability! * 100).clamp(0.0, 100.0);
    return '${pct.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final et = _emailTextResult;
    final isPhishing = et != null && et.prediction == 1;
    final showBodyConfidence = et != null &&
        et.prediction == 1 &&
        et.phishingProbability != null;

    final links = _urlLinksResult?.links ?? const <EmailUrlPrediction>[];
    final flaggedLinks = links.where((l) => l.prediction == 1).toList();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
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
                        'Analyze message text and links for phishing patterns.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Detector server',
                  onPressed: (_checkingEmailText || _checkingUrls)
                      ? null
                      : _editServer,
                  icon: const Icon(Icons.tune_rounded),
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
                                  ? 'Body: potential phishing'
                                  : 'Body: looks safe',
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
                      if (showBodyConfidence) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Phishing confidence',
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
          if (_urlLinksResult != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: flaggedLinks.isEmpty
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: flaggedLinks.isEmpty
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFECDD3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Links',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      if (links.isEmpty)
                        Text(
                          'No http(s) links found in this email.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.outline,
                          ),
                        )
                      else if (flaggedLinks.isEmpty)
                        Text(
                          '${links.length} link(s) scanned — none flagged as phishing.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        )
                      else ...[
                        Text(
                          '${flaggedLinks.length} of ${links.length} link(s) flagged:',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...flaggedLinks.map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.link_off_rounded,
                                  size: 18,
                                  color: Color(0xFFB91C1C),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l.url,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                if (_linkConfidence(l) != null)
                                  Text(
                                    _linkConfidence(l)!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB91C1C),
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
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _checkingEmailText ? null : _checkEmailText,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _checkingEmailText
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Icon(Icons.text_fields_rounded, size: 22),
                    label: Text(
                      _checkingEmailText
                          ? 'Scanning body…'
                          : 'Scan email text',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _checkingUrls ? null : _checkUrls,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _checkingUrls
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : const Icon(Icons.link_rounded, size: 22),
                    label: Text(
                      _checkingUrls ? 'Scanning links…' : 'Scan links',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
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

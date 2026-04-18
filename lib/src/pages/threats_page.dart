import 'package:flutter/material.dart';
import 'package:my_app/src/models/phishing_scan_record.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

/// Unified list of every message that was scanned and classified as phishing.
class ThreatsPage extends StatefulWidget {
  const ThreatsPage({super.key});

  @override
  State<ThreatsPage> createState() => _ThreatsPageState();
}

class _ThreatsPageState extends State<ThreatsPage> {
  Map<String, PhishingScanRecord> _scans = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final all = PrefsService.getPhishingScans();
    setState(() {
      _scans = Map.fromEntries(
        all.entries.where((e) => e.value.isPhishing),
      );
    });
  }

  Future<void> _remove(String messageId) async {
    await PrefsService.removePhishingScan(messageId);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final list = _scans.values.toList()
      ..sort((a, b) => b.scannedAtMs.compareTo(a.scannedAtMs));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Threat inbox',
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Messages you scanned that were classified as phishing. '
                  'Removing an entry only deletes the stored result — it does not delete SMS or email.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (list.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 64,
                        color: cs.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No threats recorded',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Run Scan from inside a message, or use the scan control in the app bar '
                        'when a message is selected. Phishing results appear here automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final r = list[index];
                    final pct = r.phishingProbability != null
                        ? '${(r.phishingProbability! * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%'
                        : null;
                    return Dismissible(
                      key: ValueKey(r.messageId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: cs.errorContainer,
                        child: Icon(Icons.delete_outline, color: cs.error),
                      ),
                      onDismissed: (_) => _remove(r.messageId),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFEE2E2),
                            child: Icon(
                              r.source == 'gmail'
                                  ? Icons.mail_outline
                                  : Icons.sms_outlined,
                              color: const Color(0xFFB91C1C),
                            ),
                          ),
                          title: Text(
                            r.title.isEmpty ? r.address : r.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                r.preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      pct != null
                                          ? 'Phishing · $pct'
                                          : 'Phishing',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFFEE2E2),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Text(
                                    DateTimeUtils.formatDate(
                                      DateTime.fromMillisecondsSinceEpoch(
                                        r.scannedAtMs,
                                      ),
                                    ),
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

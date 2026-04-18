import 'package:flutter/material.dart';
import 'package:my_app/src/models/phishing_scan_record.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

/// Full history of persisted AI scans, split by SMS vs Email.
class TotalScansPage extends StatefulWidget {
  const TotalScansPage({super.key, this.onScanRemoved});

  /// Notifies parent to refresh inbox/threat stats when a row is removed.
  final VoidCallback? onScanRemoved;

  @override
  State<TotalScansPage> createState() => _TotalScansPageState();
}

class _TotalScansPageState extends State<TotalScansPage> {
  Map<String, PhishingScanRecord> _all = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _all = Map<String, PhishingScanRecord>.from(
          PrefsService.getPhishingScans(),
        ));
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    _reload();
  }

  List<PhishingScanRecord> _forSource(String source) {
    final list =
        _all.values.where((r) => r.source == source).toList(growable: false)
          ..sort((a, b) => b.scannedAtMs.compareTo(a.scannedAtMs));
    return list;
  }

  Future<void> _remove(String messageId) async {
    await PrefsService.removePhishingScan(messageId);
    _reload();
    widget.onScanRemoved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final smsList = _forSource('sms');
    final emailList = _forSource('gmail');
    final total = _all.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stored scans'),
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sms_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text('SMS (${smsList.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mail_outline, size: 20),
                    const SizedBox(width: 8),
                    Text('Email (${emailList.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                total == 0
                    ? 'No scan results saved on this device yet.'
                    : '$total total — phishing and safe — kept until you remove them.',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ScanList(
                    records: smsList,
                    emptyIcon: Icons.sms_outlined,
                    emptyTitle: 'No SMS scans yet',
                    emptyBody: 'Run Scan from an SMS thread or the app bar.',
                    onRefresh: _refresh,
                    onRemove: _remove,
                  ),
                  _ScanList(
                    records: emailList,
                    emptyIcon: Icons.mail_outline,
                    emptyTitle: 'No email scans yet',
                    emptyBody:
                        'Run Scan from a Gmail message or the app bar after signing in.',
                    onRefresh: _refresh,
                    onRemove: _remove,
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

class _ScanList extends StatelessWidget {
  const _ScanList({
    required this.records,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onRefresh,
    required this.onRemove,
  });

  final List<PhishingScanRecord> records;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String messageId) onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (records.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(emptyIcon, size: 56, color: cs.outline),
                        const SizedBox(height: 16),
                        Text(
                          emptyTitle,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptyBody,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final r = records[index];
          final pct = r.phishingProbability != null
              ? '${(r.phishingProbability! * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%'
              : null;
          final isPh = r.isPhishing;

          return Dismissible(
            key: ValueKey(r.messageId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: cs.errorContainer,
              child: Icon(Icons.delete_outline, color: cs.error),
            ),
            onDismissed: (_) => onRemove(r.messageId),
            child: Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                isThreeLine: true,
                leading: CircleAvatar(
                  backgroundColor: isPh
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFD1FAE5),
                  child: Icon(
                    isPh ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                    color: isPh
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF047857),
                    size: 22,
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                            isPh
                                ? (pct != null ? 'Phishing · $pct' : 'Phishing')
                                : (pct != null ? 'Safe · $pct est. risk' : 'Safe'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          backgroundColor: isPh
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFD1FAE5),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          DateTimeUtils.formatDate(
                            DateTime.fromMillisecondsSinceEpoch(r.scannedAtMs),
                          ),
                          style: tt.labelSmall?.copyWith(color: cs.outline),
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:my_app/src/models/batch_scan_result.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

enum _ResultFilter { all, phishing, safe, failed }

/// Full-screen report for a batch scan.
class BatchScanResultsPage extends StatefulWidget {
  const BatchScanResultsPage({
    super.key,
    required this.items,
    required this.completedAt,
  });

  final List<BatchScanResultItem> items;
  final DateTime completedAt;

  @override
  State<BatchScanResultsPage> createState() => _BatchScanResultsPageState();
}

class _BatchScanResultsPageState extends State<BatchScanResultsPage> {
  _ResultFilter _filter = _ResultFilter.all;

  int get _phishing =>
      widget.items.where((e) => !e.isFailure && e.isPhishing).length;
  int get _safe =>
      widget.items.where((e) => !e.isFailure && e.isSafe).length;
  int get _failed => widget.items.where((e) => e.isFailure).length;

  List<BatchScanResultItem> get _filtered {
    switch (_filter) {
      case _ResultFilter.all:
        return widget.items;
      case _ResultFilter.phishing:
        return widget.items.where((e) => !e.isFailure && e.isPhishing).toList();
      case _ResultFilter.safe:
        return widget.items.where((e) => !e.isFailure && e.isSafe).toList();
      case _ResultFilter.failed:
        return widget.items.where((e) => e.isFailure).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            elevation: 0,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Batch scan report',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  shadows: [
                    Shadow(
                      color: cs.surface.withValues(alpha: 0.9),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0F766E),
                      const Color(0xFF0F766E).withValues(alpha: 0.85),
                      cs.primaryContainer.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.analytics_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.items.length} messages analysed',
                                    style: tt.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Completed ${DateTimeUtils.formatDate(widget.completedAt)} · '
                                    '${widget.completedAt.hour.toString().padLeft(2, '0')}:'
                                    '${widget.completedAt.minute.toString().padLeft(2, '0')}',
                                    style: tt.bodySmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
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
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      label: 'Phishing',
                      value: '$_phishing',
                      color: const Color(0xFFDC2626),
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatPill(
                      label: 'Safe',
                      value: '$_safe',
                      color: const Color(0xFF059669),
                      icon: Icons.verified_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatPill(
                      label: 'Failed',
                      value: '$_failed',
                      color: const Color(0xFFCA8A04),
                      icon: Icons.error_outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_ResultFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _ResultFilter.all,
                      label: Text('All'),
                      icon: Icon(Icons.list_alt_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: _ResultFilter.phishing,
                      label: Text('Phishing'),
                      icon: Icon(Icons.warning_amber_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: _ResultFilter.safe,
                      label: Text('Safe'),
                      icon: Icon(Icons.verified_user_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: _ResultFilter.failed,
                      label: Text('Failed'),
                      icon: Icon(Icons.cloud_off_outlined, size: 18),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (set) {
                    if (set.isEmpty) return;
                    setState(() => _filter = set.first);
                  },
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Nothing in this filter',
                  style: tt.bodyLarge?.copyWith(color: cs.outline),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ResultRowCard(item: item),
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRowCard extends StatelessWidget {
  const _ResultRowCard({required this.item});

  final BatchScanResultItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final m = item.message;
    final isGmail = m.source == 'gmail';
    final title = isGmail ? (m.subject ?? '(No subject)') : m.address;

    final Color accent;
    final String label;
    final IconData statusIcon;
    if (item.isFailure) {
      accent = const Color(0xFFCA8A04);
      label = item.errorMessage ?? 'Error';
      statusIcon = Icons.cloud_off_outlined;
    } else if (item.isPhishing) {
      accent = const Color(0xFFDC2626);
      label = item.result?.phishingConfidenceLine ??
          (item.result?.phishingPercentLabel != null
              ? 'Est. phishing risk ${item.result!.phishingPercentLabel}'
              : 'Phishing');
      statusIcon = Icons.warning_amber_rounded;
    } else {
      accent = const Color(0xFF059669);
      label = item.result?.phishingPercentLabel != null
          ? 'Not flagged · ${item.result!.phishingPercentLabel} est. phishing risk'
          : 'Not flagged';
      statusIcon = Icons.check_circle_outline;
    }

    return Material(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.35), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Icon(statusIcon, color: accent, size: 22),
          ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGmail ? 'From: ${m.address}' : 'Sender: ${m.address}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preview',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.body.trim().isEmpty ? '(No content)' : m.body,
                    style: tt.bodyMedium?.copyWith(
                      height: 1.4,
                      color: cs.onSurfaceVariant,
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

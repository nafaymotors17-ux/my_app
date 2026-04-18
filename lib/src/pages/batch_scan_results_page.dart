import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/models/batch_scan_result.dart';
import 'package:my_app/src/utils/date_time_utils.dart';

enum _ResultFilter { all, phishing, safe, failed }

enum _SortMode { original, riskHigh, riskLow, title }

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
  _SortMode _sort = _SortMode.original;
  String _searchQuery = '';
  final Map<String, ExpansibleController> _tileControllers = {};

  @override
  void dispose() {
    for (final c in _tileControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  ExpansibleController _controllerFor(String messageId) {
    return _tileControllers.putIfAbsent(
      messageId,
      ExpansibleController.new,
    );
  }

  int get _phishing =>
      widget.items.where((e) => !e.isFailure && e.isPhishing).length;
  int get _safe =>
      widget.items.where((e) => !e.isFailure && e.isSafe).length;
  int get _failed => widget.items.where((e) => e.isFailure).length;

  List<BatchScanResultItem> get _categoryFiltered {
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

  List<BatchScanResultItem> get _searchFiltered {
    final base = _categoryFiltered;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base.where((e) {
      final m = e.message;
      final subject = (m.subject ?? '').toLowerCase();
      return subject.contains(q) ||
          m.address.toLowerCase().contains(q) ||
          m.body.toLowerCase().contains(q);
    }).toList();
  }

  static double _riskKey(BatchScanResultItem e) {
    if (e.isFailure) return -1;
    final p = e.result?.phishingProbability;
    if (p != null) return p;
    return e.isPhishing ? 1.0 : 0.0;
  }

  static String _sortLabel(_SortMode m) {
    switch (m) {
      case _SortMode.original:
        return 'Scan order';
      case _SortMode.riskHigh:
        return 'Highest risk';
      case _SortMode.riskLow:
        return 'Lowest risk';
      case _SortMode.title:
        return 'Title A–Z';
    }
  }

  static String _titleOf(BatchScanResultItem e) {
    final m = e.message;
    return m.source == 'gmail' ? (m.subject ?? '(No subject)') : m.address;
  }

  List<BatchScanResultItem> get _displayItems {
    final list = List<BatchScanResultItem>.from(_searchFiltered);
    switch (_sort) {
      case _SortMode.original:
        break;
      case _SortMode.riskHigh:
        list.sort((a, b) {
          if (a.isFailure != b.isFailure) return a.isFailure ? 1 : -1;
          return _riskKey(b).compareTo(_riskKey(a));
        });
      case _SortMode.riskLow:
        list.sort((a, b) {
          if (a.isFailure != b.isFailure) return a.isFailure ? 1 : -1;
          return _riskKey(a).compareTo(_riskKey(b));
        });
      case _SortMode.title:
        list.sort(
          (a, b) => _titleOf(a).toLowerCase().compareTo(_titleOf(b).toLowerCase()),
        );
    }
    return list;
  }

  void _setFilter(_ResultFilter f) {
    HapticFeedback.selectionClick();
    setState(() => _filter = f);
  }

  void _expandOrCollapseAll({required bool expand}) {
    HapticFeedback.lightImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final item in _displayItems) {
        final c = _tileControllers[item.message.id];
        if (c == null) continue;
        expand ? c.expand() : c.collapse();
      }
    });
  }

  void _onCopyBody(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    Clipboard.setData(ClipboardData(text: t));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message text copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final display = _displayItems;

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      label: 'Phishing',
                      count: _phishing,
                      color: const Color(0xFFDC2626),
                      icon: Icons.warning_amber_rounded,
                      selected: _filter == _ResultFilter.phishing,
                      onTap: () => _setFilter(_ResultFilter.phishing),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatPill(
                      label: 'Safe',
                      count: _safe,
                      color: const Color(0xFF059669),
                      icon: Icons.verified_rounded,
                      selected: _filter == _ResultFilter.safe,
                      onTap: () => _setFilter(_ResultFilter.safe),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatPill(
                      label: 'Failed',
                      count: _failed,
                      color: const Color(0xFFCA8A04),
                      icon: Icons.error_outline,
                      selected: _filter == _ResultFilter.failed,
                      onTap: () => _setFilter(_ResultFilter.failed),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _OutcomeMixBar(
                phishing: _phishing,
                safe: _safe,
                failed: _failed,
                onTapPhishing: () => _setFilter(_ResultFilter.phishing),
                onTapSafe: () => _setFilter(_ResultFilter.safe),
                onTapFailed: () => _setFilter(_ResultFilter.failed),
                onTapAll: () => _setFilter(_ResultFilter.all),
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
                    _setFilter(set.first);
                  },
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search sender, subject, or message…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () => setState(() => _searchQuery = ''),
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sort',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  PopupMenuButton<_SortMode>(
                    tooltip: 'Sort results',
                    onSelected: (mode) {
                      HapticFeedback.selectionClick();
                      setState(() => _sort = mode);
                    },
                    itemBuilder: (context) => [
                      for (final mode in _SortMode.values)
                        PopupMenuItem(
                          value: mode,
                          child: Row(
                            children: [
                              if (_sort == mode)
                                Icon(Icons.check_rounded, size: 20, color: cs.primary)
                              else
                                const SizedBox(width: 20),
                              const SizedBox(width: 8),
                              Text(_sortLabel(mode)),
                            ],
                          ),
                        ),
                    ],
                    child: Chip(
                      avatar: Icon(
                        Icons.sort_rounded,
                        size: 18,
                        color: cs.primary,
                      ),
                      label: Text(_sortLabel(_sort)),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _expandOrCollapseAll(expand: true),
                    icon: const Icon(Icons.unfold_more_rounded, size: 20),
                    label: const Text('Expand all'),
                  ),
                  TextButton.icon(
                    onPressed: () => _expandOrCollapseAll(expand: false),
                    icon: const Icon(Icons.unfold_less_rounded, size: 20),
                    label: const Text('Collapse all'),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          if (display.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _searchQuery.trim().isEmpty
                            ? Icons.filter_alt_off_outlined
                            : Icons.search_off_rounded,
                        size: 48,
                        color: cs.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.trim().isEmpty
                            ? 'Nothing in this filter'
                            : 'No messages match your search',
                        textAlign: TextAlign.center,
                        style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = display[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ResultRowCard(
                        item: item,
                        expansionController: _controllerFor(item.message.id),
                        onCopyBody: _onCopyBody,
                      ),
                    );
                  },
                  childCount: display.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OutcomeMixBar extends StatelessWidget {
  const _OutcomeMixBar({
    required this.phishing,
    required this.safe,
    required this.failed,
    required this.onTapPhishing,
    required this.onTapSafe,
    required this.onTapFailed,
    required this.onTapAll,
  });

  final int phishing;
  final int safe;
  final int failed;
  final VoidCallback onTapPhishing;
  final VoidCallback onTapSafe;
  final VoidCallback onTapFailed;
  final VoidCallback onTapAll;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final total = phishing + safe + failed;
    final cPhish = const Color(0xFFDC2626);
    final cSafe = const Color(0xFF059669);
    final cFail = const Color(0xFFCA8A04);

    Widget segment({
      required int flex,
      required Color color,
      required String tooltip,
      required VoidCallback onTap,
    }) {
      if (flex <= 0) return const SizedBox.shrink();
      return Expanded(
        flex: flex,
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: color,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: const SizedBox(height: 14),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Outcome mix',
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onTapAll();
              },
              child: const Text('Show all'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (total == 0)
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                segment(
                  flex: phishing,
                  color: cPhish,
                  tooltip: 'Phishing: $phishing — tap to filter',
                  onTap: onTapPhishing,
                ),
                segment(
                  flex: safe,
                  color: cSafe,
                  tooltip: 'Safe: $safe — tap to filter',
                  onTap: onTapSafe,
                ),
                segment(
                  flex: failed,
                  color: cFail,
                  tooltip: 'Failed: $failed — tap to filter',
                  onTap: onTapFailed,
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Tap a colour to focus that group',
          style: tt.labelSmall?.copyWith(color: cs.outline),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.55 : 0.25),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: tt.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: count.toDouble()),
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    value.round().toString(),
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRowCard extends StatelessWidget {
  const _ResultRowCard({
    required this.item,
    required this.expansionController,
    required this.onCopyBody,
  });

  final BatchScanResultItem item;
  final ExpansibleController expansionController;
  final void Function(String text) onCopyBody;

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

    final prob = item.result?.phishingProbability;

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
          controller: expansionController,
          tilePadding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!item.isFailure && prob != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: prob.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) {
                      return LinearProgressIndicator(
                        value: t,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: Color.lerp(
                          const Color(0xFF059669),
                          const Color(0xFFDC2626),
                          t,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated phishing risk bar (0–100%)',
                  style: tt.labelSmall?.copyWith(color: cs.outline),
                ),
              ],
            ],
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          isGmail ? Icons.mail_outline : Icons.sms_outlined,
                          size: 16,
                        ),
                        label: Text(isGmail ? 'Gmail' : 'SMS'),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      if (isGmail && m.gmailLabel != null)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(m.gmailLabel!),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isGmail ? 'From: ${m.address}' : 'Sender: ${m.address}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Preview',
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.outline,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => onCopyBody(m.body),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    m.body.trim().isEmpty ? '(No content)' : m.body,
                    style: tt.bodyMedium?.copyWith(
                      height: 1.45,
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

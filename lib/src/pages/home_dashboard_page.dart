import 'package:flutter/material.dart';
import 'package:my_app/src/services/prefs_service.dart';

/// Overview and entry points for the phishing-detection workflow.
class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({
    super.key,
    required this.onGoToSms,
    required this.onGoToEmail,
    required this.onGoToThreats,
    required this.onGoToMore,
    required this.onQuickScan,
    required this.onTapStatFlagged,
    required this.onTapStatSafe,
    required this.onTapStatTotal,
  });

  final VoidCallback onGoToSms;
  final VoidCallback onGoToEmail;
  final VoidCallback onGoToThreats;
  final VoidCallback onGoToMore;
  final VoidCallback onQuickScan;

  /// Opens the Threat inbox (persisted phishing items).
  final VoidCallback onTapStatFlagged;

  /// Choose SMS or Email, then opens that inbox filtered to safe scans.
  final VoidCallback onTapStatSafe;

  /// Opens full list of saved scans (SMS & Email tabs).
  final VoidCallback onTapStatTotal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final scans = PrefsService.getPhishingScans();
    final phishing = scans.values.where((r) => r.isPhishing).length;
    final safe = scans.values.where((r) => !r.isPhishing).length;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phishing Detector',
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan SMS and Gmail with the on-device API, separate phishing from '
                    'safe items, and review everything in one place.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Flagged',
                      value: '$phishing',
                      color: const Color(0xFFDC2626),
                      icon: Icons.warning_amber_rounded,
                      tooltip: 'Open threat inbox',
                      onTap: onTapStatFlagged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Safe scans',
                      value: '$safe',
                      color: const Color(0xFF059669),
                      icon: Icons.verified_user_outlined,
                      tooltip: 'Safe scans — SMS or Email',
                      onTap: onTapStatSafe,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: _StatCard(
                label: 'Total scans stored',
                value: '${scans.length}',
                color: cs.primary,
                icon: Icons.analytics_outlined,
                wide: true,
                tooltip: 'All saved scans — SMS & Email list',
                onTap: onTapStatTotal,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Navigate',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _NavTile(
                  icon: Icons.bolt_rounded,
                  title: 'Quick scan',
                  subtitle: 'Paste any text — no message selection needed',
                  onTap: onQuickScan,
                ),
                _NavTile(
                  icon: Icons.sms_outlined,
                  title: 'SMS inbox',
                  subtitle:
                      'Unread messages—scan from the message or app bar, filter by phishing/safe',
                  onTap: onGoToSms,
                ),
                _NavTile(
                  icon: Icons.mail_outline,
                  title: 'Email (Gmail)',
                  subtitle: 'Inbox unread only · paged list · AI separation',
                  onTap: onGoToEmail,
                ),
                _NavTile(
                  icon: Icons.shield_outlined,
                  title: 'Threat inbox',
                  subtitle:
                      'All messages ever flagged as phishing (persisted on device)',
                  onTap: onGoToThreats,
                  highlight: phishing > 0,
                ),
                _NavTile(
                  icon: Icons.apps_outlined,
                  title: 'More',
                  subtitle: 'User guide and settings & data',
                  onTap: onGoToMore,
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.wide = false,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool wide;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 20 : 16,
          vertical: 18,
        ),
        child: wide
            ? Row(
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
    );

    Widget tappable = InkWell(
      onTap: onTap,
      child: body,
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      tappable = Tooltip(message: tooltip!, child: tappable);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: tappable,
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: highlight
              ? const Color(0xFFFEE2E2)
              : cs.primaryContainer.withValues(alpha: 0.5),
          child: Icon(
            icon,
            color: highlight ? const Color(0xFFB91C1C) : cs.primary,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

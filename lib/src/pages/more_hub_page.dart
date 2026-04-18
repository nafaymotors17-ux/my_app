import 'package:flutter/material.dart';
import 'package:my_app/src/pages/help_page.dart';
import 'package:my_app/src/pages/settings_page.dart';

/// Entry point for secondary screens (guide, settings).
class MoreHubPage extends StatelessWidget {
  const MoreHubPage({
    super.key,
    required this.onDataCleared,
  });

  /// Called after settings clear stored data so SMS/Email lists refresh scans.
  final VoidCallback onDataCleared;

  Future<void> _open(
    BuildContext context,
    Widget page,
  ) async {
    final cleared = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => page,
      ),
    );
    if (cleared == true) {
      onDataCleared();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                    'More',
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'User guide and data controls.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MoreTile(
                  icon: Icons.menu_book_outlined,
                  title: 'User guide',
                  subtitle: 'How scanning, Gmail, and threat separation work',
                  color: cs.primary,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const HelpPage(),
                    ),
                  ),
                ),
                _MoreTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings & data',
                  subtitle: 'Clear scan history or reset stored preferences',
                  color: const Color(0xFF7C3AED),
                  onTap: () => _open(context, const SettingsPage()),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

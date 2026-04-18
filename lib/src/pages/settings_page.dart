import 'package:flutter/material.dart';
import 'package:my_app/src/pages/onboarding_page.dart';
import 'package:my_app/src/services/prefs_service.dart';

/// Local data and onboarding replay.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearPhishingHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear AI scan history?'),
        content: const Text(
          'Removes all stored phishing/safe scan results. The Threat inbox '
          'will be empty; SMS and email messages on the device are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await PrefsService.clearPhishingScansOnly();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan history cleared')),
        );
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _resetAllLocalData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all app data?'),
        content: const Text(
          'Clears read state, hidden messages, and AI scan history stored in '
          'this app. You may need to reload SMS and sign in to Gmail again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await PrefsService.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local app data cleared')),
        );
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & data'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Privacy',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Message text is sent to your configured phishing-detection API '
                'only when you run Scan. Nothing is uploaded automatically.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                'Getting started',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(Icons.tour_outlined, color: cs.primary),
                  title: const Text('Show onboarding again'),
                  subtitle: const Text(
                    'Replay the 3-step intro (permissions, Gmail, scanning)',
                  ),
                  onTap: _busy
                      ? null
                      : () async {
                          await PrefsService.setOnboardingCompleted(false);
                          if (!context.mounted) return;
                          await Navigator.of(context, rootNavigator: true)
                              .pushAndRemoveUntil(
                            MaterialPageRoute<void>(
                              builder: (_) => const OnboardingPage(),
                            ),
                            (_) => false,
                          );
                        },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Stored on this device',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.psychology_outlined),
                      title: const Text('Clear AI scan history'),
                      subtitle: const Text(
                        'Threat inbox, list badges, Phishing/Safe filters',
                      ),
                      onTap: _busy ? null : _clearPhishingHistory,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.delete_forever_outlined, color: cs.error),
                      title: Text(
                        'Reset all local data',
                        style: TextStyle(color: cs.error),
                      ),
                      subtitle: const Text(
                        'Read state, cleared items, and scans — full wipe',
                      ),
                      onTap: _busy ? null : _resetAllLocalData,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

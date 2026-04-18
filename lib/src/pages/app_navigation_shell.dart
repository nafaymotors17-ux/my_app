import 'package:flutter/material.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';
import 'package:my_app/src/pages/home_dashboard_page.dart';
import 'package:my_app/src/pages/message_reader_page.dart';
import 'package:my_app/src/pages/more_hub_page.dart';
import 'package:my_app/src/pages/threats_page.dart';
import 'package:my_app/src/widgets/quick_scan_sheet.dart';

/// Primary shell: dashboard + SMS + Email + unified threat inbox.
class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({super.key});

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  int _index = 0;
  int _threatsRefreshKey = 0;

  final GlobalKey<MessageReaderPageState> _smsReaderKey =
      GlobalKey<MessageReaderPageState>();
  final GlobalKey<MessageReaderPageState> _emailReaderKey =
      GlobalKey<MessageReaderPageState>();

  void _reloadReaders() {
    _smsReaderKey.currentState?.reloadPhishingFromPrefs();
    _emailReaderKey.currentState?.reloadPhishingFromPrefs();
  }

  void _onDestination(int i) {
    if (i == 3) {
      _threatsRefreshKey++;
    }
    setState(() => _index = i);
    _reloadReaders();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeDashboardPage(
            onGoToSms: () => _onDestination(1),
            onGoToEmail: () => _onDestination(2),
            onGoToThreats: () => _onDestination(3),
            onGoToMore: () => _onDestination(4),
            onQuickScan: () => QuickScanSheet.show(context),
          ),
          MessageReaderPage(
            key: _smsReaderKey,
            title: 'SMS',
            mode: MessageReaderMode.sms,
            autoLoad: true,
            isActive: _index == 1,
            showAppBar: true,
          ),
          MessageReaderPage(
            key: _emailReaderKey,
            title: 'Email',
            mode: MessageReaderMode.email,
            autoLoad: true,
            isActive: _index == 2,
            showAppBar: true,
          ),
          ThreatsPage(key: ValueKey(_threatsRefreshKey)),
          MoreHubPage(onDataCleared: _reloadReaders),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestination,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: cs.primaryContainer,
        surfaceTintColor: Colors.transparent,
        backgroundColor: cs.surface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.sms_outlined),
            selectedIcon: Icon(Icons.sms_rounded),
            label: 'SMS',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail_rounded),
            label: 'Email',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Threats',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

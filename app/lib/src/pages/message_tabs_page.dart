import 'package:flutter/material.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';
import 'package:my_app/src/pages/message_reader_page.dart';

/// SMS and Email are two separate pages sharing one app bar shell (same chrome, tab strip).
class MessageTabsPage extends StatefulWidget {
  const MessageTabsPage({super.key});

  @override
  State<MessageTabsPage> createState() => _MessageTabsPageState();
}

class _MessageTabsPageState extends State<MessageTabsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<MessageReaderPageState> _smsPageKey =
      GlobalKey<MessageReaderPageState>();
  final GlobalKey<MessageReaderPageState> _emailPageKey =
      GlobalKey<MessageReaderPageState>();

  MessageReaderPageState? get _activeReaderState => _tabController.index == 0
      ? _smsPageKey.currentState
      : _emailPageKey.currentState;

  Listenable get _appBarListenable {
    final s = _activeReaderState;
    return Listenable.merge([
      _tabController,
      if (s != null) s.readerController,
    ]);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _appBarListenable,
      builder: (context, _) {
        final active = _tabController.index == 0
            ? _smsPageKey.currentState
            : _emailPageKey.currentState;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: Text(
              _tabController.index == 0 ? 'SMS' : 'Email',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'SMS'),
                Tab(text: 'Email'),
              ],
            ),
            elevation: 0,
            scrolledUnderElevation: 1,
            surfaceTintColor: Colors.transparent,
            actions: active?.buildAppBarActions(context) ?? const [],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              MessageReaderPage(
                key: _smsPageKey,
                title: 'SMS',
                mode: MessageReaderMode.sms,
                autoLoad: _tabController.index == 0,
                showAppBar: false,
                onToolbarChanged: () {
                  if (mounted) setState(() {});
                },
              ),
              MessageReaderPage(
                key: _emailPageKey,
                title: 'Email',
                mode: MessageReaderMode.email,
                autoLoad: _tabController.index == 1,
                showAppBar: false,
                onToolbarChanged: () {
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

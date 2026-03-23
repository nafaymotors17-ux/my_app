import 'package:flutter/material.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';
import 'package:my_app/src/pages/message_reader_page.dart';

class MessageTabsPage extends StatefulWidget {
  const MessageTabsPage({super.key});

  @override
  State<MessageTabsPage> createState() => _MessageTabsPageState();
}

class _MessageTabsPageState extends State<MessageTabsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phishing Detector'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SMS'),
            Tab(text: 'Email'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MessageReaderPage(
            title: 'SMS',
            mode: MessageReaderMode.sms,
            autoLoad: _tabController.index == 0,
            showAppBar: false,
          ),
          MessageReaderPage(
            title: 'Email',
            mode: MessageReaderMode.email,
            autoLoad: _tabController.index == 1,
            showAppBar: false,
          ),
        ],
      ),
    );
  }
}


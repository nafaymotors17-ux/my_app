import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/widgets/background_service_button.dart';
import 'package:my_app/src/widgets/empty_state_widget.dart';
import 'package:my_app/src/widgets/filter_chips.dart';
import 'package:my_app/src/widgets/message_card.dart';
import 'package:my_app/src/widgets/message_detail_dialog.dart';
import 'package:my_app/src/widgets/notification_listener_dialogs.dart';
import 'package:my_app/src/widgets/notification_status_button.dart';

class MessageReaderPage extends StatefulWidget {
  const MessageReaderPage({super.key, required this.title});

  final String title;

  @override
  State<MessageReaderPage> createState() => _MessageReaderPageState();
}

class _MessageReaderPageState extends State<MessageReaderPage> {
  late MessageReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MessageReaderController();
    _controller.addListener(_onControllerUpdate);
    _controller.init();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleStartBackgroundService() async {
    try {
      await _controller.startBackgroundService();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Background SMS listener started'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleStopBackgroundService() async {
    try {
      await _controller.stopBackgroundService();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Background SMS listener stopped'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleEnableNotificationListener() async {
    try {
      await _controller.enableNotificationListener();
      if (mounted) {
        NotificationListenerDialogs.showEnableDialog(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleTestNotificationListener() async {
    try {
      final testResult = await _controller.testNotificationListener();
      if (mounted && testResult != null) {
        NotificationListenerDialogs.showTestDialog(context, testResult);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error testing: $e')),
        );
      }
    }
  }

  Future<void> _handleLoadMessages() async {
    try {
      await _controller.loadAllMessages();
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: ${e.message}')),
        );
      }
    }
  }

  Future<void> _handleClearAll() async {
    final confirm = await NotificationListenerDialogs.showClearAllDialog(context);
    if (confirm == true) {
      await _controller.clearAll();
    }
  }

  Future<void> _handleClearMessage(Message msg) async {
    final res = await NotificationListenerDialogs.showClearMessageDialog(context);
    if (res == true) {
      _controller.clearMessage(msg);
    }
  }

  void _showMessageDetail(Message msg) {
    showDialog(
      context: context,
      builder: (context) => MessageDetailDialog(
        msg: msg,
        isRead: _controller.isMessageRead(msg),
        onToggleRead: () => _controller.toggleRead(msg),
        onClear: () => _controller.clearMessage(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        elevation: 0,
        actions: [
          NotificationStatusButton(
            isEnabled: _controller.notificationListenerEnabled,
            onTap: _controller.notificationListenerEnabled
                ? _handleTestNotificationListener
                : _handleEnableNotificationListener,
          ),
          BackgroundServiceButton(
            isRunning: _controller.backgroundServiceRunning,
            onTap: _controller.backgroundServiceRunning
                ? _handleStopBackgroundService
                : _handleStartBackgroundService,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear all (WhatsApp storage + local state)',
            onPressed: _handleClearAll,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleLoadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          FilterChips(
            selectedFilter: _controller.selectedFilter,
            onFilterChanged: (filter) => _controller.setFilter(filter),
          ),
          Expanded(
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _controller.displayedMessages.isEmpty
                    ? EmptyStateWidget(
                        selectedFilter: _controller.selectedFilter,
                        onLoadMessages: _handleLoadMessages,
                      )
                    : ListView.builder(
                        itemCount: _controller.displayedMessages.length,
                        itemBuilder: (context, index) {
                          final Message msg = _controller.displayedMessages[index];
                          final bool isMessageRead = _controller.isMessageRead(msg);

                          return MessageCard(
                            msg: msg,
                            isRead: isMessageRead,
                            onTap: () => _showMessageDetail(msg),
                            onDelete: () => _handleClearMessage(msg),
                            onToggleRead: () => _controller.toggleRead(msg), // Works for both SMS and WhatsApp
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

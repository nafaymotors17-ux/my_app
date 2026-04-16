import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/utils/responsive.dart';
import 'package:my_app/src/widgets/background_service_button.dart';
import 'package:my_app/src/widgets/empty_state_widget.dart';
import 'package:my_app/src/widgets/filter_chips.dart';
import 'package:my_app/src/widgets/gmail_status_button.dart';
import 'package:my_app/src/widgets/message_card.dart';
import 'package:my_app/src/widgets/message_detail_dialog.dart';
import 'package:my_app/src/widgets/message_detail_panel.dart';
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
  Message? _selectedMessage; // For master-detail layout on wide screens

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
      setState(() {
        // Clear selection if the message was cleared
        if (_selectedMessage != null &&
            !_controller.displayedMessages.any(
              (m) => m.id == _selectedMessage!.id,
            )) {
          _selectedMessage = null;
        }
      });
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error testing: $e')));
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

  Future<void> _handleGmailTap() async {
    if (_controller.gmailSignedIn) {
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gmail Account'),
          content: Text('Signed in as: ${_controller.gmailUserEmail}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
      if (shouldSignOut == true) {
        await _controller.signOutFromGmail();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out from Gmail'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      await _handleGmailSignIn();
    }
  }

  Future<void> _handleGmailSignIn() async {
    try {
      setState(() {});
      await _controller.signInToGmail().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Sign-in timed out');
        },
      );
      if (mounted && _controller.gmailSignedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Signed in as ${_controller.gmailUserEmail}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gmail sign-in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleFilterChanged(String filter) async {
    if (filter == 'gmail' && !_controller.gmailSignedIn) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gmail Sign-In Required'),
          content: const Text(
            'Sign in with your Google account to view Gmail emails',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );

      if (result == true) {
        await _handleGmailSignIn();
        if (_controller.gmailSignedIn) {
          _controller.setFilter(filter);
        }
      }
    } else {
      _controller.setFilter(filter);
    }
  }

  Future<void> _handleClearAll() async {
    final confirm = await NotificationListenerDialogs.showClearAllDialog(
      context,
    );
    if (confirm == true) {
      await _controller.clearAll();
      setState(() => _selectedMessage = null);
    }
  }

  Future<void> _handleClearMessage(Message msg) async {
    final res = await NotificationListenerDialogs.showClearMessageDialog(
      context,
    );
    if (res == true) {
      _controller.clearMessage(msg);
      if (_selectedMessage?.id == msg.id) {
        setState(() => _selectedMessage = null);
      }
    }
  }

  void _showMessageDetail(Message msg) {
    if (ResponsiveBreakpoints.isWideScreen(context)) {
      setState(() => _selectedMessage = msg);
    } else {
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
  }

  Widget _buildMessageList() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.displayedMessages.isEmpty) {
      return EmptyStateWidget(
        selectedFilter: _controller.selectedFilter,
        onLoadMessages: _handleLoadMessages,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        left: ResponsiveBreakpoints.isMediumOrWider(context) ? 12 : 8,
        right: ResponsiveBreakpoints.isMediumOrWider(context) ? 12 : 8,
        bottom: 16,
      ),
      itemCount: _controller.displayedMessages.length,
      itemBuilder: (context, index) {
        final Message msg = _controller.displayedMessages[index];
        final bool isMessageRead = _controller.isMessageRead(msg);
        final bool isSelected = _selectedMessage?.id == msg.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MessageCard(
            msg: msg,
            isRead: isMessageRead,
            isSelected: isSelected,
            onTap: () => _showMessageDetail(msg),
            onDelete: () => _handleClearMessage(msg),
            onToggleRead: () => _controller.toggleRead(msg),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.isWideScreen(context);
    final isNarrow = !ResponsiveBreakpoints.isMediumOrWider(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        elevation: 0,
        actions: [
          // On narrow screens, show icons only; on wider, show full buttons
          if (isNarrow) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _handleLoadMessages,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Clear all',
              onPressed: _handleClearAll,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Status & options',
              onSelected: (value) {
                switch (value) {
                  case 'notifications':
                    _controller.notificationListenerEnabled
                        ? _handleTestNotificationListener()
                        : _handleEnableNotificationListener();
                    break;
                  case 'background':
                    _controller.backgroundServiceRunning
                        ? _handleStopBackgroundService()
                        : _handleStartBackgroundService();
                    break;
                  case 'gmail':
                    _handleGmailTap();
                    break;
                  case 'refresh':
                    _handleLoadMessages();
                    break;
                  case 'clear':
                    _handleClearAll();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'notifications',
                  child: Row(
                    children: [
                      Icon(
                        _controller.notificationListenerEnabled
                            ? Icons.check_circle
                            : Icons.notifications,
                        color: _controller.notificationListenerEnabled
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _controller.notificationListenerEnabled
                            ? 'Notifications: Active'
                            : 'Enable Notifications',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'background',
                  child: Row(
                    children: [
                      Icon(
                        _controller.backgroundServiceRunning
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        color: _controller.backgroundServiceRunning
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _controller.backgroundServiceRunning
                            ? 'Background: Running'
                            : 'Start Background Service',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'gmail',
                  child: Row(
                    children: [
                      Icon(
                        _controller.gmailSignedIn
                            ? Icons.mail
                            : Icons.mail_outline,
                        color: _controller.gmailSignedIn
                            ? Colors.red
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _controller.gmailSignedIn
                            ? 'Gmail: ${_controller.gmailUserEmail}'
                            : 'Sign in to Gmail',
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 12),
                      Text('Refresh messages'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever),
                      SizedBox(width: 12),
                      Text('Clear all'),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
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
            GmailStatusButton(
              isSignedIn: _controller.gmailSignedIn,
              userEmail: _controller.gmailUserEmail,
              onTap: _handleGmailTap,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Clear all (WhatsApp storage + local state)',
              onPressed: _handleClearAll,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh messages',
              onPressed: _handleLoadMessages,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master: message list
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilterChips(
                          selectedFilter: _controller.selectedFilter,
                          onFilterChanged: _handleFilterChanged,
                        ),
                        Expanded(child: _buildMessageList()),
                      ],
                    ),
                  ),
                  // Detail panel
                  SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.4,
                    constraints: const BoxConstraints(minWidth: 320),
                    child: MessageDetailPanel(
                      message: _selectedMessage,
                      isRead: _selectedMessage != null
                          ? _controller.isMessageRead(_selectedMessage!)
                          : false,
                      onToggleRead: _selectedMessage != null
                          ? () => _controller.toggleRead(_selectedMessage!)
                          : null,
                      onClear: _selectedMessage != null
                          ? () => _handleClearMessage(_selectedMessage!)
                          : null,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  FilterChips(
                    selectedFilter: _controller.selectedFilter,
                    onFilterChanged: _handleFilterChanged,
                  ),
                  Expanded(child: _buildMessageList()),
                ],
              ),
      ),
    );
  }
}

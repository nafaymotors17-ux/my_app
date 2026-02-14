import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';
import 'package:my_app/src/services/gmail_service.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/utils/responsive.dart';
import 'package:my_app/src/widgets/background_service_button.dart';
import 'package:my_app/src/widgets/empty_state_widget.dart';
import 'package:my_app/src/widgets/filter_chips.dart';
import 'package:my_app/src/widgets/gmail_status_button.dart';
import 'package:my_app/src/widgets/message_card.dart';
import 'package:my_app/src/pages/message_detail_page.dart';
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = MessageReaderController();
    _controller.addListener(_onControllerUpdate);
    _controller.init();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.selectedFilter != 'gmail') return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_controller.gmailLoadingMore &&
        _controller.gmailHasMore) {
      _controller.loadMoreGmailEmails();
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {
        // Clear selection if the message was cleared
        if (_selectedMessage != null &&
            !_controller.displayedMessages.any((m) => m.id == _selectedMessage!.id)) {
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
      if (shouldSignOut == true) {
        await _handleGmailSignOut();
      }
    } else {
      await _handleGmailSignIn();
    }
  }

  Future<void> _handleGmailSignOut() async {
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

  Future<void> _handleGmailSignIn() async {
    try {
      setState(() {});
      
      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Signing in...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Opening Google account picker...'),
              ],
            ),
          ),
        );
      }
      
      await _controller.signInToGmail().timeout(
        const Duration(seconds: 120), // Increased timeout to 2 minutes
        onTimeout: () {
          throw TimeoutException(
            'Sign-in timed out. Check your internet connection and try again.',
          );
        },
      );
      
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        
        if (_controller.gmailSignedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Signed in as ${_controller.gmailUserEmail}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        
        String errorMessage = 'Sign-in failed';
        if (e is TimeoutException) {
          errorMessage = e.message ?? errorMessage;
        } else if (e.toString().contains('PlatformException')) {
          errorMessage = 'Could not connect to Google. Check:\n• Internet connection\n• Web Client ID is set correctly\n• Google Play Services is installed';
        } else {
          errorMessage = 'Error: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
          await _controller.loadGmailWhenFilterIsGmail();
        }
      }
    } else {
      _controller.setFilter(filter);
      if (filter == 'gmail' && _controller.gmailSignedIn) {
        await _controller.loadGmailWhenFilterIsGmail();
      }
    }
  }

  Future<void> _handleGmailLabelChanged(String labelId) async {
    await _controller.setGmailLabel(labelId);
  }

  Future<void> _handleClearAll() async {
    final confirm = await NotificationListenerDialogs.showClearAllDialog(context);
    if (confirm == true) {
      await _controller.clearAll();
      setState(() => _selectedMessage = null);
    }
  }

  Future<void> _handleClearMessage(Message msg) async {
    final res = await NotificationListenerDialogs.showClearMessageDialog(context);
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
      // Open in a full page (like email apps) — preserves list state on back.
      final gmailId = msg.source == 'gmail'
          ? msg.id.replaceFirst('gmail_', '')
          : null;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessageDetailPage(
            message: msg,
            initialIsRead: _controller.isMessageRead(msg),
            onToggleRead: () => _controller.toggleRead(msg),
            onClear: () => _controller.clearMessage(msg),
            onMarkAsSpam: msg.source == 'gmail' && gmailId != null
                ? () async {
                    await GmailService.markAsSpam(gmailId);
                    _controller.clearMessage(msg);
                  }
                : null,
            onTrash: msg.source == 'gmail' && gmailId != null
                ? () async {
                    await GmailService.trashEmail(gmailId);
                    _controller.clearMessage(msg);
                  }
                : null,
          ),
        ),
      );
    }
  }

  Widget _buildMessageList() {
    final isGmailFilter = _controller.selectedFilter == 'gmail';
    final showGmailLoading = isGmailFilter && _controller.gmailLoading;

    if (_controller.isLoading && _controller.displayedMessages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Gmail tab loading (switching Inbox/Sent/Spam)
    if (showGmailLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading ${_controller.selectedGmailLabel == GmailLabels.spam ? 'spam' : 'inbox'}...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      );
    }
    if (_controller.displayedMessages.isEmpty) {
      return EmptyStateWidget(
        selectedFilter: _controller.selectedFilter,
        onLoadMessages: isGmailFilter ? () => _controller.loadGmailWhenFilterIsGmail() : _handleLoadMessages,
        gmailLabel: isGmailFilter ? _controller.selectedGmailLabel : null,
      );
    }

    final count = _controller.displayedMessages.length;
    final hasMore = _controller.gmailHasMore;
    final loadingMore = _controller.gmailLoadingMore;

    return Column(
      children: [
        if (isGmailFilter && _controller.gmailSignedIn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Loaded $count'
                  + (hasMore ? ' · Load more below' : ' · All loaded'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(
              left: ResponsiveBreakpoints.isMediumOrWider(context) ? 12 : 8,
              right: ResponsiveBreakpoints.isMediumOrWider(context) ? 12 : 8,
              bottom: 16,
            ),
            itemCount: count + (isGmailFilter && count > 0 && (hasMore || loadingMore) ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= count) {
                return _buildGmailLoadMoreFooter();
              }
              final Message msg = _controller.displayedMessages[index];
              final bool isMessageRead = _controller.isMessageRead(msg);
              final bool isSelected = _selectedMessage?.id == msg.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MessageCard(
                  msg: msg,
                  index: isGmailFilter ? index + 1 : null,
                  isRead: isMessageRead,
                  isSelected: isSelected,
                  onTap: () => _showMessageDetail(msg),
                  onDelete: () => _handleClearMessage(msg),
                  onToggleRead: () => _controller.toggleRead(msg),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGmailLoadMoreFooter() {
    if (_controller.gmailLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: _controller.gmailHasMore ? () => _controller.loadMoreGmailEmails() : null,
          icon: const Icon(Icons.expand_more, size: 20),
          label:           const Text('Load more (30 next)'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.isWideScreen(context);
    final isNarrow = !ResponsiveBreakpoints.isMediumOrWider(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          widget.title,
          overflow: TextOverflow.ellipsis,
        ),
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
                  case 'gmail_signin':
                    _handleGmailSignIn();
                    break;
                  case 'gmail_signout':
                    _handleGmailSignOut();
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
                const PopupMenuDivider(),
                if (_controller.gmailSignedIn) ...[
                  PopupMenuItem(
                    enabled: false,
                    child: Row(
                      children: [
                        const Icon(Icons.mail, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _controller.gmailUserEmail ?? 'Gmail',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'gmail_signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Sign out of Gmail',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const PopupMenuItem(
                    value: 'gmail_signin',
                    child: Row(
                      children: [
                        Icon(Icons.mail_outline, color: Colors.grey),
                        SizedBox(width: 12),
                        Text('Sign in to Gmail'),
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
                          selectedGmailLabel: _controller.selectedGmailLabel,
                          onGmailLabelChanged: _handleGmailLabelChanged,
                          gmailSignedIn: _controller.gmailSignedIn,
                          gmailLoading: _controller.gmailLoading,
                        ),
                        Expanded(child: _buildMessageList()),
                      ],
                    ),
                  ),
                  // Detail panel
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width * 0.4).clamp(320.0, 500.0),
                    child: MessageDetailPanel(
                      message: _selectedMessage,
                      isRead: _selectedMessage != null
                          ? _controller.isMessageRead(_selectedMessage!)
                          : false,
                      fullBodyFuture: _selectedMessage != null &&
                              _selectedMessage!.source == 'gmail'
                          ? GmailService.getEmailBodyForDisplay(
                              _selectedMessage!.id.replaceFirst('gmail_', ''),
                            ).then((body) => body ?? _selectedMessage!.body)
                          : null,
                      onToggleRead: _selectedMessage != null
                          ? () => _controller.toggleRead(_selectedMessage!)
                          : null,
                      onClear: _selectedMessage != null
                          ? () => _handleClearMessage(_selectedMessage!)
                          : null,
                      onMarkAsSpam: _selectedMessage != null &&
                              _selectedMessage!.source == 'gmail'
                          ? () async {
                              final msg = _selectedMessage!;
                              final messenger = ScaffoldMessenger.of(context);
                              final gmailId = msg.id.replaceFirst('gmail_', '');
                              await GmailService.markAsSpam(gmailId);
                              _controller.clearMessage(msg);
                              if (mounted) {
                                setState(() => _selectedMessage = null);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Marked as spam'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          : null,
                      onTrash: _selectedMessage != null &&
                              _selectedMessage!.source == 'gmail'
                          ? () async {
                              final msg = _selectedMessage!;
                              final messenger = ScaffoldMessenger.of(context);
                              final gmailId = msg.id.replaceFirst('gmail_', '');
                              await GmailService.trashEmail(gmailId);
                              _controller.clearMessage(msg);
                              if (mounted) {
                                setState(() => _selectedMessage = null);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Moved to trash'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
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
                    selectedGmailLabel: _controller.selectedGmailLabel,
                    onGmailLabelChanged: _handleGmailLabelChanged,
                    gmailSignedIn: _controller.gmailSignedIn,
                    gmailLoading: _controller.gmailLoading,
                  ),
                  Expanded(child: _buildMessageList()),
                ],
              ),
      ),
    );
  }
}

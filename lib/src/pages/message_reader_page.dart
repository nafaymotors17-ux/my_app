import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';
import 'package:my_app/src/services/gmail_service.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/utils/responsive.dart';
import 'package:my_app/src/widgets/empty_state_widget.dart';
import 'package:my_app/src/widgets/filter_chips.dart';
import 'package:my_app/src/widgets/gmail_status_button.dart';
import 'package:my_app/src/widgets/message_card.dart';
import 'package:my_app/src/pages/message_detail_page.dart';
import 'package:my_app/src/widgets/message_detail_panel.dart';
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
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

  void _showMessageDetail(Message msg) {
    if (ResponsiveBreakpoints.isWideScreen(context)) {
      setState(() => _selectedMessage = msg);
    } else {
      // Open in a full page (like email apps) — preserves list state on back.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessageDetailPage(
            message: msg,
            initialIsRead: _controller.isMessageRead(msg),
            onToggleRead: () => _controller.toggleRead(msg),
          ),
        ),
      );
    }
  }

  Widget _buildMessageList() {
    final isGmailFilter = _controller.selectedFilter == 'gmail';
    final showGmailLoading = isGmailFilter && _controller.gmailLoading;

    if (_controller.isLoading && _controller.displayedMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading…',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }
    // Gmail tab loading (switching Inbox/Sent/Spam)
    if (showGmailLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading emails…',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    if (_controller.displayedMessages.isEmpty) {
      return EmptyStateWidget(
        selectedFilter: _controller.selectedFilter,
        onLoadMessages: isGmailFilter ? () => _controller.loadGmailWhenFilterIsGmail() : _handleLoadMessages,
      );
    }

    final visible = _controller.visibleMessages;
    final total = _controller.displayedMessages.length;
    final hasMoreVisible = _controller.gmailHasMoreVisible;

    return Column(
      children: [
        if (isGmailFilter && _controller.gmailSignedIn && total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.inbox_outlined, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  hasMoreVisible
                      ? 'Showing ${visible.length} of $total'
                      : '$total emails',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              if (isGmailFilter) {
                await _controller.loadGmailWhenFilterIsGmail();
              } else {
                await _handleLoadMessages();
              }
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                left: ResponsiveBreakpoints.isMediumOrWider(context) ? 16 : 12,
                right: ResponsiveBreakpoints.isMediumOrWider(context) ? 16 : 12,
                top: 8,
                bottom: 24,
              ),
              itemCount: visible.length + (hasMoreVisible ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= visible.length) {
                  return _buildLoadMoreVisibleFooter(total, visible.length);
                }
                final Message msg = visible[index];
                final bool isMessageRead = _controller.isMessageRead(msg);
                final bool isSelected = _selectedMessage?.id == msg.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MessageCard(
                    msg: msg,
                    index: isGmailFilter ? index + 1 : null,
                    isRead: isMessageRead,
                    isSelected: isSelected,
                    onTap: () => _showMessageDetail(msg),
                    onToggleRead: () => _controller.toggleRead(msg),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreVisibleFooter(int total, int showing) {
    final remaining = total - showing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: _controller.gmailHasMoreVisible ? _controller.loadMoreVisible : null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          label: Text('Show ${remaining > 25 ? 25 : remaining} more'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Text(
          widget.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        actions: [
          // On narrow screens, show icons only; on wider, show full buttons
          if (isNarrow) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _handleLoadMessages,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Status & options',
              onSelected: (value) {
                switch (value) {
                  case 'gmail_signin':
                    _handleGmailSignIn();
                    break;
                  case 'gmail_signout':
                    _handleGmailSignOut();
                    break;
                  case 'refresh':
                    _handleLoadMessages();
                    break;
                }
              },
              itemBuilder: (context) => [
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
              ],
            ),
          ] else ...[
            GmailStatusButton(
              isSignedIn: _controller.gmailSignedIn,
              userEmail: _controller.gmailUserEmail,
              onTap: _handleGmailTap,
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

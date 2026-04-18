import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/controllers/message_reader_controller.dart';
import 'package:my_app/src/services/gmail_service.dart';
import 'package:my_app/src/models/batch_scan_result.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/pages/batch_scan_progress_page.dart';
import 'package:my_app/src/utils/responsive.dart';
import 'package:my_app/src/widgets/empty_state_widget.dart';
import 'package:my_app/src/widgets/filter_chips.dart';
import 'package:my_app/src/widgets/gmail_pagination_bar.dart';
import 'package:my_app/src/widgets/gmail_status_button.dart';
import 'package:my_app/src/widgets/message_card.dart';
import 'package:my_app/src/pages/message_detail_page.dart';
import 'package:my_app/src/widgets/message_detail_panel.dart';
import 'package:my_app/src/widgets/quick_scan_sheet.dart';
import 'package:my_app/src/services/sms_ai_service.dart';

class MessageReaderPage extends StatefulWidget {
  const MessageReaderPage({
    super.key,
    required this.title,
    required this.mode,
    this.autoLoad = true,
    this.isActive = true,
    this.showAppBar = true,
    this.onToolbarChanged,
  });

  final String title;
  final MessageReaderMode mode;
  final bool autoLoad;

  /// When false, [init] is deferred until this becomes true (e.g. hidden [IndexedStack] tab).
  final bool isActive;
  final bool showAppBar;

  /// When [showAppBar] is false, the parent owns the app bar — call this after
  /// state that affects toolbar actions (selection, AI scan progress, etc.).
  final VoidCallback? onToolbarChanged;

  @override
  State<MessageReaderPage> createState() => MessageReaderPageState();
}

class MessageReaderPageState extends State<MessageReaderPage> {
  late MessageReaderController _controller;
  Message? _selectedMessage; // For master-detail layout on wide screens
  final ScrollController _scrollController = ScrollController();
  final Set<String> _checkingAiIds = <String>{};
  bool _selectionMode = false;
  final Set<String> _batchSelectedIds = <String>{};
  bool _didInit = false;

  MessageReaderController get readerController => _controller;

  void _notifyToolbar() => widget.onToolbarChanged?.call();

  /// Call when phishing store may have changed (e.g. after Threats tab dismiss).
  Future<void> reloadPhishingFromPrefs() => _controller.reloadPhishingScans();

  @override
  void initState() {
    super.initState();
    _controller = MessageReaderController(mode: widget.mode);
    _controller.addListener(_onControllerUpdate);
    _maybeInit();
  }

  @override
  void didUpdateWidget(covariant MessageReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_didInit && widget.autoLoad) {
      _maybeInit();
    }
  }

  void _maybeInit() {
    if (_didInit || !widget.autoLoad) return;
    if (!widget.isActive) return;
    _didInit = true;
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
        final ids = _controller.displayedMessages.map((m) => m.id).toSet();
        _batchSelectedIds.removeWhere((id) => !ids.contains(id));
      });
      _notifyToolbar();
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _batchSelectedIds.clear();
    });
    _notifyToolbar();
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _batchSelectedIds.clear();
      _selectedMessage = null;
    });
    _notifyToolbar();
  }

  void _selectAllVisible() {
    setState(() {
      for (final m in _controller.visibleMessages) {
        _batchSelectedIds.add(m.id);
      }
    });
    _notifyToolbar();
  }

  Future<BatchScanResultItem> _scanOneMessageForBatch(Message msg) async {
    try {
      late final SmsAiResult result;
      if (msg.source == 'sms') {
        result = await SmsAiService.checkSms(msg.body);
      } else {
        if (!_controller.gmailSignedIn) {
          return BatchScanResultItem.failure(
            msg,
            'Sign in to Gmail to scan email',
          );
        }
        final gmailId = msg.id.replaceFirst('gmail_', '');
        final fullBody = await GmailService.getEmailBodyForDisplay(gmailId);
        final bodyToSend =
            (fullBody != null && fullBody.trim().isNotEmpty) ? fullBody : msg.body;
        result = await SmsAiService.checkEmailText(bodyToSend);
      }
      await _controller.recordPhishingScan(msg, result);
      return BatchScanResultItem.success(msg, result);
    } catch (e) {
      return BatchScanResultItem.failure(
        msg,
        SmsAiService.describeNetworkError(e),
      );
    }
  }

  Future<void> _runBatchScan() async {
    final msgs = _controller.visibleMessages
        .where((m) => _batchSelectedIds.contains(m.id))
        .toList();
    if (msgs.isEmpty) return;

    setState(() {
      _selectionMode = false;
      _batchSelectedIds.clear();
    });
    _notifyToolbar();
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (context, animation, secondaryAnimation) {
          return BatchScanProgressPage(
            sourceLabel: widget.title,
            messages: msgs,
            scanOne: _scanOneMessageForBatch,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
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

  /// Refresh: Gmail path when signed in on Email tab, else full reload.
  Future<void> _handleRefreshMessages() async {
    try {
      if (widget.mode == MessageReaderMode.email &&
          _controller.gmailSignedIn) {
        await _controller.loadGmailWhenFilterIsGmail();
      } else {
        await _controller.loadAllMessages();
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: ${e.message}')),
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

  Future<void> _checkMessageWithAi(Message msg) async {
    if (_checkingAiIds.contains(msg.id)) return;
    setState(() => _checkingAiIds.add(msg.id));
    _notifyToolbar();
    try {
      late final SmsAiResult result;
      if (msg.source == 'sms') {
        result = await SmsAiService.checkSms(msg.body);
        if (!mounted) return;
        await _controller.recordPhishingScan(msg, result);
        if (!mounted) return;
        final suffix = result.phishingRiskPercentSuffix ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.prediction == 1
                  ? 'SMS: flagged as phishing$suffix'
                  : 'SMS: not flagged as phishing$suffix',
            ),
            backgroundColor:
                result.prediction == 1 ? Colors.red : Colors.green,
          ),
        );
      } else if (msg.source == 'gmail') {
        if (!_controller.gmailSignedIn) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in to Gmail first'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final gmailId = msg.id.replaceFirst('gmail_', '');
        final fullBody = await GmailService.getEmailBodyForDisplay(gmailId);
        final bodyToSend = (fullBody != null && fullBody.trim().isNotEmpty)
            ? fullBody
            : msg.body;

        result = await SmsAiService.checkEmailText(bodyToSend);
        if (!mounted) return;
        await _controller.recordPhishingScan(msg, result);
        if (!mounted) return;

        final suffixMail = result.phishingRiskPercentSuffix ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.prediction == 1
                  ? 'Email: flagged as phishing$suffixMail'
                  : 'Email: not flagged as phishing$suffixMail',
            ),
            backgroundColor: result.prediction == 1 ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Check AI failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      final friendly = SmsAiService.describeNetworkError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AI check failed: $friendly',
            maxLines: 4,
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _checkingAiIds.remove(msg.id));
        _notifyToolbar();
      }
    }
  }

  Widget _buildFilterChips() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FilterChips(
          mode: widget.mode,
          inboxSegment: _controller.inboxSegment,
          onInboxSegmentChanged: (s) {
            _controller.setInboxSegment(s);
            _notifyToolbar();
          },
          gmailSignedIn: _controller.gmailSignedIn,
          gmailLoading: _controller.gmailLoading,
        );
      },
    );
  }

  void _onMessageTap(Message msg) {
    if (_selectionMode) {
      setState(() {
        if (_batchSelectedIds.contains(msg.id)) {
          _batchSelectedIds.remove(msg.id);
        } else {
          _batchSelectedIds.add(msg.id);
        }
      });
      _notifyToolbar();
      return;
    }
    _showMessageDetail(msg);
  }

  void _onMessageLongPress(Message msg) {
    if (_selectionMode) return;
    setState(() {
      _selectionMode = true;
      _batchSelectedIds.add(msg.id);
      _selectedMessage = null;
    });
    _notifyToolbar();
  }

  void _showMessageDetail(Message msg) {
    setState(() => _selectedMessage = msg);
    _notifyToolbar();
    if (ResponsiveBreakpoints.isWideScreen(context)) {
      return;
    }
    // Phone: full-screen detail; keep selection so scan/read stay in the app bar when you return.
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
        inboxSegment: _controller.inboxSegment,
      );
    }

    final visible = _controller.visibleMessages;
    final total = _controller.displayedMessages.length;

    if (visible.isEmpty && total > 0) {
      return EmptyStateWidget(
        selectedFilter: _controller.selectedFilter,
        inboxSegment: _controller.inboxSegment,
      );
    }

    return Column(
      children: [
        if (isGmailFilter && _controller.gmailSignedIn && total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: GmailPaginationBar(controller: _controller),
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
              itemCount: visible.length,
              itemBuilder: (context, index) {
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
                    selectionMode: _selectionMode,
                    isChecked: _batchSelectedIds.contains(msg.id),
                    aiScan: _controller.scanFor(msg.id),
                    onTap: () => _onMessageTap(msg),
                    onLongPress: () => _onMessageLongPress(msg),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Toolbar actions for this page (used by [MessageReaderPage] or a parent shell).
  List<Widget> buildAppBarActions(BuildContext context) {
    final isNarrow = !ResponsiveBreakpoints.isMediumOrWider(context);
    final cs = Theme.of(context).colorScheme;
    if (_selectionMode) {
      return [
        TextButton(
          onPressed: _selectAllVisible,
          child: const Text('Select all'),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: FilledButton.icon(
            onPressed:
                _batchSelectedIds.isEmpty ? null : _runBatchScan,
            icon: const Icon(Icons.shield_rounded, size: 20),
            label: Text('Scan (${_batchSelectedIds.length})'),
          ),
        ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Quick scan — paste text without picking a message',
        onPressed: () => QuickScanSheet.show(context),
        icon: Icon(
          Icons.bolt_rounded,
          color: cs.primary,
        ),
      ),
      IconButton(
        tooltip: 'Select messages — batch scan',
        onPressed: _enterSelectionMode,
        icon: Icon(Icons.checklist_rounded, color: cs.primary),
      ),
      // Scan / read for the selected row (same app bar on phone after you open a message once).
      if (_selectedMessage != null) ...[
        Builder(
          builder: (context) {
            final sel = _selectedMessage!;
            final checking = _checkingAiIds.contains(sel.id);
            final needGmail = sel.source == 'gmail';
            final canScan = !needGmail || _controller.gmailSignedIn;
            final cs = Theme.of(context).colorScheme;
            return IconButton(
              tooltip: needGmail ? 'Scan email' : 'Scan SMS',
              onPressed: !canScan || checking
                  ? null
                  : () => _checkMessageWithAi(sel),
              icon: checking
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Icon(
                      Icons.shield_rounded,
                      color: canScan ? cs.primary : cs.outline,
                    ),
            );
          },
        ),
        Builder(
          builder: (context) {
            final sel = _selectedMessage!;
            final read = _controller.isMessageRead(sel);
            final cs = Theme.of(context).colorScheme;
            return IconButton(
              tooltip: read ? 'Mark unread' : 'Mark read',
              icon: Icon(
                read
                    ? Icons.mark_email_unread_outlined
                    : Icons.mark_email_read_outlined,
                color: read ? cs.outline : cs.primary,
              ),
              onPressed: () => _controller.toggleRead(sel),
            );
          },
        ),
      ],
      // Phones: mail icon is always visible on Email tab (Gmail is also in ⋮).
      if (isNarrow && widget.mode == MessageReaderMode.email) ...[
        IconButton(
          icon: Icon(
            _controller.gmailSignedIn ? Icons.mail_rounded : Icons.mail_outlined,
            color: _controller.gmailSignedIn
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          tooltip: _controller.gmailSignedIn
              ? 'Gmail: ${_controller.gmailUserEmail ?? 'signed in'}'
              : 'Sign in to Gmail',
          onPressed: _handleGmailTap,
        ),
      ],
      if (isNarrow) ...[
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _handleRefreshMessages,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'More options',
          onSelected: (value) {
            switch (value) {
              case 'gmail_signin':
                _handleGmailSignIn();
                break;
              case 'gmail_signout':
                _handleGmailSignOut();
                break;
              case 'refresh':
                _handleRefreshMessages();
                break;
            }
          },
          itemBuilder: (context) => [
            if (widget.mode == MessageReaderMode.email) ...[
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
            ],
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
        if (widget.mode == MessageReaderMode.email)
          GmailStatusButton(
            isSignedIn: _controller.gmailSignedIn,
            userEmail: _controller.gmailUserEmail,
            onTap: _handleGmailTap,
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh messages',
          onPressed: _handleRefreshMessages,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.isWideScreen(context);

    final Widget content = SafeArea(
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
                      _buildFilterChips(),
                      Expanded(child: _buildMessageList()),
                    ],
                  ),
                ),
                // Detail panel
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width * 0.4).clamp(320.0, 500.0),
                  child: MessageDetailPanel(
                    message: _selectedMessage,
                    fullBodyFuture: _selectedMessage != null &&
                            _selectedMessage!.source == 'gmail'
                        ? GmailService.getEmailBodyForDisplay(
                            _selectedMessage!.id.replaceFirst('gmail_', ''),
                          ).then((body) => body ?? _selectedMessage!.body)
                        : null,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildFilterChips(),
                Expanded(child: _buildMessageList()),
              ],
            ),
    );

    if (!widget.showAppBar) return content;

    return Scaffold(
      appBar: AppBar(
            leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        automaticallyImplyLeading: !_selectionMode,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Text(
          _selectionMode
              ? 'Select messages (${_batchSelectedIds.length})'
              : widget.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        actions: buildAppBarActions(context),
      ),
      body: content,
    );
  }
}

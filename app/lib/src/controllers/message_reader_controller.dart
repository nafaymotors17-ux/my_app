import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/models/phishing_scan_record.dart';
import 'package:my_app/src/services/platform_service.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:my_app/src/services/gmail_auth_service.dart';
import 'package:my_app/src/services/gmail_service.dart';
import 'package:my_app/src/services/sms_ai_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MessageReaderMode { sms, email }

/// Filters the current folder list by AI scan outcome (stored locally).
enum InboxSegment {
  /// Every message in the folder.
  all,

  /// Messages scanned and classified as phishing.
  phishing,

  /// Messages scanned and classified as safe (unscanned messages are hidden).
  safe,
}

class MessageReaderController extends ChangeNotifier {
  final MessageReaderMode mode;

  List<Message> allMessages = [];
  List<Message> displayedMessages = [];
  bool isLoading = false;
  late String selectedFilter; // 'sms', 'gmail'
  InboxSegment inboxSegment = InboxSegment.all;

  /// Persisted AI results for messages (SMS + Gmail ids).
  Map<String, PhishingScanRecord> phishingScanById = {};
  bool gmailSignedIn = false;
  String? gmailUserEmail;
  SharedPreferences? _prefs;
  Set<String> readIds = <String>{};
  Set<String> clearedIds = <String>{};
  bool gmailLoading = false;

  /// Gmail: **Inbox · unread only** — one page at a time with explicit navigation.
  static const int _gmailPageSize = 15;
  final List<List<Message>> _gmailPageCache = [];
  int _gmailPageIndex = 0;
  String? _gmailNextPageToken;
  int _gmailResultSizeEstimate = 0;
  bool _gmailLoadingNextPage = false;

  /// App only loads [GmailLabels.inbox] with unread filter (see Gmail API).
  String get selectedGmailLabel => GmailLabels.inbox;

  MessageReaderController({required this.mode}) {
    selectedFilter = mode == MessageReaderMode.sms ? 'sms' : 'gmail';
  }

  /// Messages to show after [inboxSegment] filter (Gmail: current page only).
  List<Message> get visibleMessages {
    final base = displayedMessages;
    switch (inboxSegment) {
      case InboxSegment.all:
        return base;
      case InboxSegment.phishing:
        return base
            .where((m) => phishingScanById[m.id]?.isPhishing == true)
            .toList();
      case InboxSegment.safe:
        return base
            .where(
              (m) =>
                  phishingScanById.containsKey(m.id) &&
                  phishingScanById[m.id]!.isPhishing == false,
            )
            .toList();
    }
  }

  bool get gmailLoadingMore => _gmailLoadingNextPage;

  int get gmailPageNumber => _gmailPageCache.isEmpty ? 1 : _gmailPageIndex + 1;
  int get gmailCachedPageCount => _gmailPageCache.length;
  int get gmailResultSizeEstimate => _gmailResultSizeEstimate;

  bool get gmailHasPreviousPage =>
      selectedFilter == 'gmail' && _gmailPageIndex > 0;

  /// Next page: another cached page, or fetch from API using [ _gmailNextPageToken ].
  bool get gmailHasNextPage {
    if (selectedFilter != 'gmail' || !gmailSignedIn) return false;
    if (_gmailPageIndex + 1 < _gmailPageCache.length) return true;
    return _gmailNextPageToken != null && _gmailNextPageToken!.isNotEmpty;
  }

  void gmailGoToPreviousPage() {
    if (!gmailHasPreviousPage) return;
    _gmailPageIndex--;
    filterMessages();
    notifyListeners();
  }

  Future<void> gmailGoToNextPage() async {
    if (selectedFilter != 'gmail' || !gmailSignedIn) return;
    if (_gmailLoadingNextPage) return;

    if (_gmailPageIndex + 1 < _gmailPageCache.length) {
      _gmailPageIndex++;
      filterMessages();
      notifyListeners();
      return;
    }

    if (_gmailNextPageToken == null || _gmailNextPageToken!.isEmpty) return;

    _gmailLoadingNextPage = true;
    notifyListeners();
    try {
      final result = await GmailService.fetchEmailsByLabelPage(
        labelId: GmailLabels.inbox,
        pageToken: _gmailNextPageToken,
        maxResults: _gmailPageSize,
        unreadOnly: true,
      );
      _gmailNextPageToken = result.nextPageToken;
      if (result.resultSizeEstimate > 0) {
        _gmailResultSizeEstimate = result.resultSizeEstimate;
      }
      final page = result.emails.map(_emailToMessage).toList();
      _gmailPageCache.add(page);
      _gmailPageIndex = _gmailPageCache.length - 1;
      allMessages = [
        ...allMessages.where((m) => m.source != 'gmail'),
        ..._gmailPageCache.expand((p) => p),
      ];
      allMessages.sort((a, b) => b.date.compareTo(a.date));
      filterMessages();
    } finally {
      _gmailLoadingNextPage = false;
      notifyListeners();
    }
  }

  void _resetGmailPagination() {
    _gmailPageCache.clear();
    _gmailPageIndex = 0;
    _gmailNextPageToken = null;
    _gmailResultSizeEstimate = 0;
  }


  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    readIds = _prefs?.getStringList('read_ids')?.toSet() ?? <String>{};
    clearedIds = _prefs?.getStringList('cleared_ids')?.toSet() ?? <String>{};
    phishingScanById = PrefsService.getPhishingScans();
    if (mode == MessageReaderMode.email) {
      // Email tab: only initialize Gmail side.
      await _checkGmailStatus();
      await loadAllMessages();
    } else {
      // SMS tab: only initialize SMS side.
      await requestPermissionsAndLoadMessages();
    }
  }

  Future<void> requestPermissionsAndLoadMessages() async {
    if (kIsWeb) {
      await loadAllMessages();
      return;
    }
    final PermissionStatus status = await Permission.sms.request();

    if (status.isGranted) {
      loadAllMessages();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> loadAllMessages() async {
    isLoading = true;
    notifyListeners();

    try {
      final List<Message> smsList = selectedFilter == 'sms'
          ? (await PlatformService.getSmsMessagesWithReadStatus())
              .map((message) {
                final Map<dynamic, dynamic> msg =
                    message as Map<dynamic, dynamic>;
                final int ts = msg['date'] as int? ?? 0;
                final String src = msg['source'] as String? ?? 'sms';
                final String address = msg['address'] as String? ?? 'Unknown';
                final bool smsIsRead = msg['isRead'] as bool? ?? false;
                final String id = '${src}_${ts}_${address}';
                return Message(
                  id: id,
                  address: address,
                  body: msg['body'] as String? ?? 'No content',
                  date: DateTime.fromMillisecondsSinceEpoch(ts),
                  source: src,
                  isRead: smsIsRead,
                );
              })
              .where((m) => !m.isRead)
              .toList() // Only unread SMS
          : <Message>[];

      // Email tab: load the first small page only.
      List<Message> gmailList = <Message>[];
      if (selectedFilter == 'gmail' && gmailSignedIn) {
        try {
          _resetGmailPagination();
          final result = await GmailService.fetchEmailsByLabelPage(
            labelId: GmailLabels.inbox,
            pageToken: null,
            maxResults: _gmailPageSize,
            unreadOnly: true,
          );
          _gmailNextPageToken = result.nextPageToken;
          _gmailResultSizeEstimate = result.resultSizeEstimate;
          gmailList = result.emails.map(_emailToMessage).toList();
          _gmailPageCache.add(gmailList);
          _gmailPageIndex = 0;
        } catch (e) {
          print('Error loading Gmail in loadAllMessages: $e');
        }
      } else {
        _resetGmailPagination();
      }

      final List<Message> combined = [...smsList, ...gmailList];
      combined.sort((a, b) => b.date.compareTo(a.date));
      allMessages = combined;
      filterMessages();
      isLoading = false;
      notifyListeners();
    } on PlatformException {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void filterMessages() {
    if (selectedFilter == 'gmail') {
      if (_gmailPageCache.isEmpty) {
        displayedMessages = [];
      } else {
        final page = _gmailPageCache[_gmailPageIndex];
        displayedMessages =
            page.where((m) => !clearedIds.contains(m.id)).toList();
      }
      notifyListeners();
      return;
    }
    final filtered =
        allMessages.where((msg) => msg.source == 'sms').toList();
    displayedMessages =
        filtered.where((m) => !clearedIds.contains(m.id)).toList();
    notifyListeners();
  }

  void setInboxSegment(InboxSegment segment) {
    if (inboxSegment == segment) return;
    inboxSegment = segment;
    notifyListeners();
  }

  Future<void> recordPhishingScan(Message msg, SmsAiResult result) async {
    phishingScanById[msg.id] = PhishingScanRecord.fromMessage(msg, result);
    await PrefsService.savePhishingScans(phishingScanById);
    notifyListeners();
  }

  PhishingScanRecord? scanFor(String messageId) => phishingScanById[messageId];

  void setFilter(String filter) {
    selectedFilter = filter;
    filterMessages();
  }

  /// Inbox-only app: kept for API compatibility; always reloads unread inbox.
  Future<void> setGmailLabel(String labelId) async {
    if (!gmailSignedIn) {
      filterMessages();
      notifyListeners();
      return;
    }
    await _loadGmailWithLoadingState();
  }

  /// Load Gmail when user selects Gmail filter (first time or refresh)
  Future<void> loadGmailWhenFilterIsGmail() async {
    if (!gmailSignedIn || selectedFilter != 'gmail') return;
    await _loadGmailWithLoadingState();
  }

  Future<void> _loadGmailWithLoadingState() async {
    gmailLoading = true;
    allMessages = allMessages.where((m) => m.source != 'gmail').toList();
    _resetGmailPagination();
    _gmailLoadingNextPage = false;
    filterMessages();
    notifyListeners();
    await Future.delayed(Duration.zero);
    await loadGmailEmails();
    gmailLoading = false;
    notifyListeners();
  }

  Future<void> saveLocalPrefs() async {
    await PrefsService.saveReadIds(readIds);
    await PrefsService.saveClearedIds(clearedIds);
  }

  void toggleRead(Message msg) {
    if (readIds.contains(msg.id)) {
      readIds.remove(msg.id);
    } else {
      readIds.add(msg.id);
    }
    saveLocalPrefs();
    notifyListeners();
  }

  void clearMessage(Message msg) {
    clearedIds.add(msg.id);
    saveLocalPrefs();
    filterMessages();
  }

  Future<void> clearAll() async {
    await PrefsService.clearAll();
    readIds.clear();
    clearedIds.clear();
    phishingScanById.clear();
    _resetGmailPagination();
    allMessages.clear();
    displayedMessages.clear();
    notifyListeners();
  }

  Future<void> reloadPhishingScans() async {
    phishingScanById = PrefsService.getPhishingScans();
    notifyListeners();
  }

  bool isMessageRead(Message msg) {
    return msg.source == 'sms' ? msg.isRead : readIds.contains(msg.id);
  }

  // Gmail-related methods
  Future<void> _checkGmailStatus() async {
    try {
      final user = await GmailAuthService.silentSignIn();
      if (user != null) {
        gmailSignedIn = true;
        gmailUserEmail = user.email;
      } else {
        // Silent sign-in failed — token may have expired (7-day testing mode,
        // revoked access, etc.). Clear the signed-in state so the UI shows
        // the sign-in button instead of silently failing.
        gmailSignedIn = false;
        gmailUserEmail = null;
        print(
          'ℹ Gmail silent sign-in returned null — user needs to sign in again',
        );
      }
      notifyListeners();
    } catch (e) {
      print('Error checking Gmail status: $e');
      gmailSignedIn = false;
      gmailUserEmail = null;
      notifyListeners();
    }
  }

  Future<void> signInToGmail() async {
    isLoading = true;
    notifyListeners();

    try {
      print('Starting Gmail sign-in...');
      final user = await GmailAuthService.signIn();
      print('Sign-in result: ${user?.email ?? "null"}');

      if (user != null) {
        gmailSignedIn = true;
        gmailUserEmail = user.email;
        print('✓ Signed in as: ${user.email}');

        // Fetch Gmail emails after signing in
        print('Fetching Gmail emails...');
        await loadGmailEmails();
        print('✓ Gmail emails loaded');
      } else {
        print('Sign-in cancelled by user');
        gmailSignedIn = false;
      }
    } catch (e) {
      print('❌ Gmail sign-in error: $e');
      gmailSignedIn = false;
      rethrow; // Re-throw so UI can show error
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Message _emailToMessage(Email email) {
    final isSent = email.labelId == GmailLabels.sent;
    return Message(
      id: 'gmail_${email.id}',
      address: isSent
          ? (email.to.isNotEmpty ? email.to : email.from)
          : email.from,
      body: email.body.isNotEmpty ? email.body : email.snippet,
      date: email.date,
      source: 'gmail',
      isRead: false,
      subject: email.subject,
      gmailTo: email.to.isNotEmpty ? email.to : null,
      gmailLabel: email.labelId,
    );
  }

  /// Inbox unread only, page 1 — further pages use [gmailGoToNextPage].
  Future<void> loadGmailEmails() async {
    try {
      _resetGmailPagination();
      final result = await GmailService.fetchEmailsByLabelPage(
        labelId: GmailLabels.inbox,
        pageToken: null,
        maxResults: _gmailPageSize,
        unreadOnly: true,
      );
      _gmailNextPageToken = result.nextPageToken;
      _gmailResultSizeEstimate = result.resultSizeEstimate;
      final gmailList = result.emails.map(_emailToMessage).toList();

      if (gmailList.isEmpty && gmailSignedIn && !GmailAuthService.hasUser) {
        print(
          '⚠ Gmail returned empty and auth lost — resetting signed-in state',
        );
        gmailSignedIn = false;
        gmailUserEmail = null;
        notifyListeners();
        return;
      }

      _gmailPageCache.add(gmailList);
      _gmailPageIndex = 0;
      allMessages = [
        ...allMessages.where((m) => m.source != 'gmail'),
        ...gmailList,
      ];
      allMessages.sort((a, b) => b.date.compareTo(a.date));
      filterMessages();
    } catch (e) {
      print('Error loading Gmail emails: $e');
      if (!GmailAuthService.hasUser) {
        gmailSignedIn = false;
        gmailUserEmail = null;
        notifyListeners();
      }
    }
  }

  Future<void> signOutFromGmail() async {
    try {
      await GmailAuthService.signOut();
      gmailSignedIn = false;
      gmailUserEmail = null;
      _gmailLoadingNextPage = false;
      _resetGmailPagination();
      allMessages = allMessages.where((m) => m.source != 'gmail').toList();
      filterMessages();
      notifyListeners();
    } catch (e) {
      print('Error signing out from Gmail: $e');
    }
  }
}

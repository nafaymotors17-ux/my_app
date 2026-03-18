import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/services/platform_service.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:my_app/src/services/gmail_auth_service.dart';
import 'package:my_app/src/services/gmail_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageReaderController extends ChangeNotifier {
  List<Message> allMessages = [];
  List<Message> displayedMessages = [];
  bool isLoading = false;
  String selectedFilter = 'sms'; // 'sms', 'gmail'
  String selectedGmailLabel = GmailLabels.inbox; // INBOX only (unread)
  bool gmailSignedIn = false;
  String? gmailUserEmail;
  SharedPreferences? _prefs;
  Set<String> readIds = <String>{};
  Set<String> clearedIds = <String>{};
  // Gmail: load all at once, then paginate on frontend
  bool gmailLoading = false;
  static const int _initialVisibleCount = 25;
  static const int _loadMoreVisibleCount = 25;
  int _gmailVisibleCount = _initialVisibleCount;

  /// Messages to show in the list (for Gmail we only show the first N and let user tap "Show more").
  List<Message> get visibleMessages {
    if (selectedFilter != 'gmail' ||
        displayedMessages.length <= _gmailVisibleCount) {
      return displayedMessages;
    }
    return displayedMessages.sublist(0, _gmailVisibleCount);
  }

  bool get gmailHasMoreVisible =>
      selectedFilter == 'gmail' &&
      _gmailVisibleCount < displayedMessages.length;

  void loadMoreVisible() {
    if (!gmailHasMoreVisible) return;
    _gmailVisibleCount = (_gmailVisibleCount + _loadMoreVisibleCount).clamp(
      0,
      displayedMessages.length,
    );
    notifyListeners();
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    readIds = _prefs?.getStringList('read_ids')?.toSet() ?? <String>{};
    clearedIds = _prefs?.getStringList('cleared_ids')?.toSet() ?? <String>{};
    // Check Gmail status BEFORE loading messages, so gmailSignedIn is set
    // when loadAllMessages() decides whether to fetch Gmail emails.
    await _checkGmailStatus();
    await requestPermissionsAndLoadMessages();
  }

  Future<void> requestPermissionsAndLoadMessages() async {
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
      // Load SMS messages with read/unread status
      final List<dynamic> smsMessages =
          await PlatformService.getSmsMessagesWithReadStatus();
      final List<Message> smsList = (smsMessages)
          .map((message) {
            final Map<dynamic, dynamic> msg = message as Map<dynamic, dynamic>;
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
          .toList(); // Only unread SMS

      // Load all Gmail at once when signed in (frontend pagination)
      List<Message> gmailList = [];
      if (gmailSignedIn) {
        try {
          gmailList = (await GmailService.fetchAllEmailsByLabel(
            labelId: selectedGmailLabel,
            pageSize: GmailService.defaultPageSize,
            maxTotalResults: 500,
          )).map(_emailToMessage).toList();
          _gmailVisibleCount = _initialVisibleCount;
        } catch (e) {
          print('Error loading Gmail in loadAllMessages: $e');
        }
      }

      // Combine all messages
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
    List<Message> filtered;
    if (selectedFilter == 'gmail') {
      filtered = allMessages.where((msg) {
        if (msg.source != 'gmail') return false;
        // Only inbox (unread) - no spam
        return msg.gmailLabel == null || msg.gmailLabel == GmailLabels.inbox;
      }).toList();
    } else {
      filtered = allMessages.where((msg) => msg.source == 'sms').toList();
    }
    displayedMessages = filtered
        .where((m) => !clearedIds.contains(m.id))
        .toList();
    notifyListeners();
  }

  void setFilter(String filter) {
    selectedFilter = filter;
    filterMessages();
  }

  Future<void> setGmailLabel(String labelId) async {
    if (selectedGmailLabel == labelId) return;
    selectedGmailLabel = labelId;
    if (!gmailSignedIn) {
      filterMessages();
      notifyListeners();
      return;
    }
    await _loadGmailWithLoadingState(labelId: labelId);
  }

  /// Load Gmail when user selects Gmail filter (first time or refresh)
  Future<void> loadGmailWhenFilterIsGmail() async {
    if (!gmailSignedIn || selectedFilter != 'gmail') return;
    await _loadGmailWithLoadingState(labelId: selectedGmailLabel);
  }

  Future<void> _loadGmailWithLoadingState({String? labelId}) async {
    gmailLoading = true;
    allMessages = allMessages.where((m) => m.source != 'gmail').toList();
    _gmailVisibleCount = _initialVisibleCount;
    filterMessages();
    notifyListeners();
    await Future.delayed(Duration.zero);
    await loadGmailEmails(labelId: labelId ?? selectedGmailLabel);
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
    displayedMessages.removeWhere((m) => m.id == msg.id);
    saveLocalPrefs();
    notifyListeners();
  }

  Future<void> clearAll() async {
    if (_prefs != null) {
      await _prefs?.remove('read_ids');
      await _prefs?.remove('cleared_ids');
    }
    readIds.clear();
    clearedIds.clear();
    allMessages.clear();
    displayedMessages.clear();
    await saveLocalPrefs();
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

  /// Load all Gmail emails at once (then frontend pagination shows first N).
  Future<void> loadGmailEmails({String? labelId}) async {
    try {
      final label = labelId ?? selectedGmailLabel;
      final gmailList = (await GmailService.fetchAllEmailsByLabel(
        labelId: label,
        pageSize: GmailService.defaultPageSize,
        maxTotalResults: 500,
      )).map(_emailToMessage).toList();

      if (gmailList.isEmpty && gmailSignedIn && !GmailAuthService.hasUser) {
        print(
          '⚠ Gmail returned empty and auth lost — resetting signed-in state',
        );
        gmailSignedIn = false;
        gmailUserEmail = null;
        notifyListeners();
        return;
      }

      _gmailVisibleCount = _initialVisibleCount;
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
      _gmailVisibleCount = _initialVisibleCount;
      allMessages = allMessages.where((m) => m.source != 'gmail').toList();
      filterMessages();
      notifyListeners();
    } catch (e) {
      print('Error signing out from Gmail: $e');
    }
  }
}

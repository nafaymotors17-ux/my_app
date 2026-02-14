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
  String selectedFilter = 'all'; // 'all', 'sms', 'whatsapp', 'gmail'
  String selectedGmailLabel = GmailLabels.inbox; // INBOX or SPAM only
  bool notificationListenerEnabled = false;
  bool backgroundServiceRunning = false;
  bool gmailSignedIn = false;
  String? gmailUserEmail;
  SharedPreferences? _prefs;
  Set<String> readIds = <String>{}; 
  Set<String> clearedIds = <String>{};
  // Gmail pagination & loading
  String? _gmailNextPageToken;
  int _gmailTotalEstimate = 0;
  bool gmailLoadingMore = false;
  bool gmailLoading = false; // true when switching tabs or initial load
  bool get gmailHasMore => _gmailNextPageToken != null;
  int get gmailTotalEstimate => _gmailTotalEstimate;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    readIds = _prefs?.getStringList('read_ids')?.toSet() ?? <String>{};
    clearedIds = _prefs?.getStringList('cleared_ids')?.toSet() ?? <String>{};
    // Check Gmail status BEFORE loading messages, so gmailSignedIn is set
    // when loadAllMessages() decides whether to fetch Gmail emails.
    await _checkGmailStatus();
    await requestPermissionsAndLoadMessages();
    await checkBackgroundServiceStatus();
  }

  Future<void> checkBackgroundServiceStatus() async {
    try {
      final bool isRunning = await PlatformService.isBackgroundServiceRunning();
      backgroundServiceRunning = isRunning;
      notifyListeners();
    } catch (e) {
      print('Error checking background service: $e');
    }
  }

  Future<void> requestPermissionsAndLoadMessages() async {
    final PermissionStatus status = await Permission.sms.request();

    if (status.isGranted) {
      loadAllMessages();
      checkNotificationListenerStatus();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> checkNotificationListenerStatus() async {
    try {
      final bool isEnabled =
          await PlatformService.isNotificationListenerEnabled();
      notificationListenerEnabled = isEnabled;
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> startBackgroundService() async {
    try {
      final success = await PlatformService.startBackgroundService();
      if (success) {
        backgroundServiceRunning = true;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stopBackgroundService() async {
    try {
      final success = await PlatformService.stopBackgroundService();
      if (success) {
        backgroundServiceRunning = false;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadAllMessages() async {
    isLoading = true;
    notifyListeners();

    try {
      // Load SMS messages with read/unread status
      final List<dynamic> smsMessages =
          await PlatformService.getSmsMessagesWithReadStatus();
      final List<Message> smsList = (smsMessages).map((message) {
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
      }).toList();

      // Load WhatsApp notifications
      final List<dynamic> whatsAppMessages =
          await PlatformService.getWhatsAppNotifications();
      final List<Message> whatsappList = (whatsAppMessages).map((message) {
        final Map<dynamic, dynamic> msg = message as Map<dynamic, dynamic>;
        final int ts = msg['date'] as int? ?? 0;
        final String src = msg['source'] as String? ?? 'whatsapp';
        final String address = msg['address'] as String? ?? 'Unknown';
        // Use the ID from notification if available, otherwise generate one
        final String notificationId = msg['id'] as String? ?? '';
        final String id = notificationId.isNotEmpty
            ? notificationId
            : '${src}_${ts}_${address}';
        // Check if this WhatsApp message is marked as read locally
        final bool isLocallyRead = readIds.contains(id);
        return Message(
          id: id,
          address: address,
          body: msg['body'] as String? ?? 'No content',
          date: DateTime.fromMillisecondsSinceEpoch(ts),
          source: src,
          isRead: isLocallyRead, // Track read status locally for WhatsApp
        );
      }).toList();

      // Load Gmail first page when signed in (on-demand, unread only for inbox/spam)
      List<Message> gmailList = [];
      if (gmailSignedIn) {
        try {
          final result = await GmailService.fetchEmailsByLabelPage(
            labelId: selectedGmailLabel,
            maxResults: GmailService.defaultPageSize,
          );
          gmailList = result.emails.map((e) => _emailToMessage(e)).toList();
          _gmailNextPageToken = result.nextPageToken;
          _gmailTotalEstimate = result.resultSizeEstimate;
        } catch (e) {
          print('Error loading Gmail in loadAllMessages: $e');
        }
      }

      // Combine all messages
      final List<Message> combined = [...smsList, ...whatsappList, ...gmailList];
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
    if (selectedFilter == 'all') {
      filtered = allMessages;
    } else if (selectedFilter == 'gmail') {
      filtered = allMessages.where((msg) {
        if (msg.source != 'gmail') return false;
        return msg.gmailLabel == null || msg.gmailLabel == selectedGmailLabel;
      }).toList();
    } else {
      filtered = allMessages.where((msg) => msg.source == selectedFilter).toList();
    }
    displayedMessages = filtered.where((m) => !clearedIds.contains(m.id)).toList();
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
    _gmailNextPageToken = null;
    _gmailTotalEstimate = 0;
    filterMessages();
    notifyListeners();
    await Future.delayed(Duration.zero);
    await loadGmailEmails(labelId: labelId ?? selectedGmailLabel);
    gmailLoading = false;
    notifyListeners();
  }

  Future<void> enableNotificationListener() async {
    try {
      await PlatformService.enableNotificationListener();
      await Future.delayed(const Duration(milliseconds: 500));
      await checkNotificationListenerStatus();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> testNotificationListener() async {
    try {
      final result = await PlatformService.testNotificationListener();
      if (result == null) return null;
      return Map<String, dynamic>.from(
        result.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (e) {
      rethrow;
    }
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
    try {
      await PlatformService.clearWhatsAppNotifications();
    } catch (_) {}
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
        print('ℹ Gmail silent sign-in returned null — user needs to sign in again');
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
      address: isSent ? (email.to.isNotEmpty ? email.to : email.from) : email.from,
      body: email.body.isNotEmpty ? email.body : email.snippet,
      date: email.date,
      source: 'gmail',
      isRead: false,
      subject: email.subject,
      gmailTo: email.to.isNotEmpty ? email.to : null,
      gmailLabel: email.labelId,
    );
  }

  /// Load first page of Gmail emails (resets list). Does not set gmailLoading - caller handles that.
  Future<void> loadGmailEmails({String? labelId}) async {
    try {
      final label = labelId ?? selectedGmailLabel;
      final result = await GmailService.fetchEmailsByLabelPage(
        labelId: label,
        maxResults: GmailService.defaultPageSize,
      );

      // If the result is empty AND we thought we were signed in, the token
      // may have expired silently. Check whether auth is still valid.
      if (result.emails.isEmpty && gmailSignedIn && !GmailAuthService.hasUser) {
        print('⚠ Gmail returned empty and auth lost — resetting signed-in state');
        gmailSignedIn = false;
        gmailUserEmail = null;
        _gmailNextPageToken = null;
        _gmailTotalEstimate = 0;
        notifyListeners();
        return;
      }

      final gmailList = result.emails.map(_emailToMessage).toList();

      _gmailNextPageToken = result.nextPageToken;
      _gmailTotalEstimate = result.resultSizeEstimate;

      allMessages = [
        ...allMessages.where((m) => m.source != 'gmail'),
        ...gmailList,
      ];
      allMessages.sort((a, b) => b.date.compareTo(a.date));
      filterMessages();
    } catch (e) {
      print('Error loading Gmail emails: $e');
      _gmailNextPageToken = null;
      _gmailTotalEstimate = 0;

      // If auth is gone, reset state so the user sees the sign-in prompt
      if (!GmailAuthService.hasUser) {
        gmailSignedIn = false;
        gmailUserEmail = null;
        notifyListeners();
      }
    }
  }

  /// Load more Gmail emails (append next page - 31-60, 61-90, etc.)
  Future<void> loadMoreGmailEmails() async {
    if (gmailLoadingMore || !gmailHasMore || _gmailNextPageToken == null) return;
    gmailLoadingMore = true;
    notifyListeners();

    try {
      final pageToken = _gmailNextPageToken;
      final result = await GmailService.fetchEmailsByLabelPage(
        labelId: selectedGmailLabel,
        pageToken: pageToken,
        maxResults: GmailService.defaultPageSize,
      );
      final newGmailList = result.emails.map(_emailToMessage).toList();

      _gmailNextPageToken = result.nextPageToken;
      if (result.resultSizeEstimate > 0) {
        _gmailTotalEstimate = result.resultSizeEstimate;
      }

      final existingIds = allMessages
          .where((m) => m.source == 'gmail')
          .map((m) => m.id)
          .toSet();
      final toAppend = newGmailList
          .where((m) => !existingIds.contains(m.id))
          .toList();

      allMessages = [...allMessages, ...toAppend];
      allMessages.sort((a, b) => b.date.compareTo(a.date));
      filterMessages();
    } catch (e) {
      print('Error loading more Gmail: $e');
    } finally {
      gmailLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> signOutFromGmail() async {
    try {
      await GmailAuthService.signOut();
      gmailSignedIn = false;
      gmailUserEmail = null;
      _gmailNextPageToken = null;
      _gmailTotalEstimate = 0;
      allMessages = allMessages.where((m) => m.source != 'gmail').toList();
      filterMessages();
      notifyListeners();
    } catch (e) {
      print('Error signing out from Gmail: $e');
    }
  }
}

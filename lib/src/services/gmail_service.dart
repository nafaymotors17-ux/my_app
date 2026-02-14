import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:my_app/src/services/gmail_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// --- Gmail API behavior (why we fetch per-message) ---
// • messages.list returns only message IDs (and thread IDs), not subject/from/body.
//   It supports pagination: maxResults (1–500) and pageToken. We use this for "page size".
// • There is no API that returns "N full messages in one response". To get content you must
//   call messages.get per message. We do those in parallel (Future.wait) to avoid sequential
//   round-trips. Optional: Google supports batch HTTP (multipart) for up to 100 calls per
//   request if we need to reduce latency further.

class Email {
  final String id;
  final String subject;
  final String from;
  final String to;
  final String snippet;
  final String body;
  final DateTime date;
  final bool isPhishing;
  final String labelId; // INBOX, SENT, SPAM, etc.

  Email({
    required this.id,
    required this.subject,
    required this.from,
    this.to = '',
    required this.snippet,
    required this.body,
    required this.date,
    this.isPhishing = false,
    this.labelId = 'INBOX',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'from': from,
      'to': to,
      'snippet': snippet,
      'body': body,
      'date': date.millisecondsSinceEpoch,
      'isPhishing': isPhishing,
      'labelId': labelId,
    };
  }

  factory Email.fromMap(Map<String, dynamic> map) {
    return Email(
      id: map['id'] ?? '',
      subject: map['subject'] ?? '',
      from: map['from'] ?? '',
      to: map['to'] ?? '',
      snippet: map['snippet'] ?? '',
      body: map['body'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      isPhishing: map['isPhishing'] ?? false,
      labelId: map['labelId'] ?? 'INBOX',
    );
  }
}

/// Gmail label IDs (standard Gmail labels)
class GmailLabels {
  static const String inbox = 'INBOX';
  static const String sent = 'SENT';
  static const String spam = 'SPAM';
  static const String trash = 'TRASH';
}

/// Result of a paginated Gmail fetch
class GmailFetchResult {
  final List<Email> emails;
  final String? nextPageToken;
  final int resultSizeEstimate;

  const GmailFetchResult({
    required this.emails,
    this.nextPageToken,
    this.resultSizeEstimate = 0,
  });
}

class GmailService {
  static const String _storageKey = 'gmail_emails';
  static const String _lastSyncKey = 'gmail_last_sync';
  /// Page size for list; Gmail API allows up to 500. We fetch this many IDs per page, then get each in parallel.
  static const int defaultPageSize = 50;

  /// Inbox = unread only. Spam = all spam (no unread filter - spam is inherently "unread" to check).
  static bool _unreadOnlyForLabel(String labelId) {
    return labelId == GmailLabels.inbox;
  }

  /// Fetch emails by label with pagination. Unread only for Inbox and Spam.
  /// Uses metadata format for faster loading (snippet as preview, no full body).
  static Future<GmailFetchResult> fetchEmailsByLabelPage({
    required String labelId,
    String? pageToken,
    int maxResults = defaultPageSize,
    bool unreadOnly = true,
  }) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) {
        return const GmailFetchResult(emails: []);
      }

      final useUnread = unreadOnly && _unreadOnlyForLabel(labelId);
      final q = useUnread ? 'is:unread' : null;

      final listResponse = await gmailApi.users.messages.list(
        'me',
        labelIds: [labelId],
        q: q,
        maxResults: maxResults,
        pageToken: pageToken,
      );

      final messages = listResponse.messages ?? [];
      // Fetch all messages in parallel (was sequential = 30x slower)
      final futures = messages.map((msgRef) async {
        try {
          final msg = await gmailApi.users.messages.get(
            'me',
            msgRef.id!,
            format: 'metadata',
          );
          return _parseGmailMessage(msg, labelId: labelId);
        } catch (e) {
          return null;
        }
      });
      final results = await Future.wait(futures);
      final emails = results.whereType<Email>().toList();

      return GmailFetchResult(
        emails: emails,
        nextPageToken: listResponse.nextPageToken,
        resultSizeEstimate: listResponse.resultSizeEstimate ?? 0,
      );
    } catch (e, stackTrace) {
      print('Error fetching emails: $e');
      print('Stack trace: $stackTrace');
      return const GmailFetchResult(emails: []);
    }
  }

  /// Legacy: fetch emails (first page only, unread for inbox/spam)
  static Future<List<Email>> fetchEmailsByLabel({
    required String labelId,
    int maxResults = defaultPageSize,
  }) async {
    final result = await fetchEmailsByLabelPage(
      labelId: labelId,
      maxResults: maxResults,
    );
    return result.emails;
  }

  /// Fetch emails (convenience - uses INBOX, unread only)
  static Future<List<Email>> fetchEmails({
    int maxResults = defaultPageSize,
    String? labelId,
  }) async {
    final result = await fetchEmailsByLabelPage(
      labelId: labelId ?? GmailLabels.inbox,
      maxResults: maxResults,
    );
    return result.emails;
  }

  /// Fetch all emails (paginated). Uses parallel gets and metadata format for speed.
  /// [maxTotalResults] limits the total number of emails to fetch (null = no limit).
  static Future<List<Email>> fetchAllEmails({
    int pageSize = 50,
    int? maxTotalResults,
  }) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) return [];

      List<Email> allEmails = [];
      String? pageToken;

      do {
        final listResponse = await gmailApi.users.messages.list(
          'me',
          maxResults: pageSize,
          pageToken: pageToken,
        );

        final messages = listResponse.messages ?? [];
        if (messages.isEmpty) break;

        // Fetch this page of messages in parallel (metadata = no full body, faster)
        final futures = messages.map((msgRef) async {
          try {
            final msg = await gmailApi.users.messages.get(
              'me',
              msgRef.id!,
              format: 'metadata',
            );
            return _parseGmailMessage(msg);
          } catch (e) {
            print('Error fetching message: $e');
            return null;
          }
        });
        final results = await Future.wait(futures);
        final pageEmails = results.whereType<Email>().toList();
        if (maxTotalResults != null) {
          final remaining = maxTotalResults - allEmails.length;
          allEmails.addAll(pageEmails.take(remaining));
        } else {
          allEmails.addAll(pageEmails);
        }

        if (maxTotalResults != null && allEmails.length >= maxTotalResults) break;
        pageToken = listResponse.nextPageToken;
      } while (pageToken != null);

      await _saveEmails(allEmails);
      await _updateLastSync();

      return allEmails;
    } catch (e) {
      print('Error fetching all emails: $e');
      return await _loadEmails();
    }
  }

  /// Get email by ID
  static Future<Email?> getEmailById(String emailId) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) return null;

      final message = await gmailApi.users.messages.get(
        'me',
        emailId,
        format: 'full',
      );

      return _parseGmailMessage(message);
    } catch (e) {
      print('Error getting email: $e');
      return null;
    }
  }

  /// Get the full email body for display, preferring HTML for rich rendering
  /// (clickable links, formatting). Falls back to plain text body.
  static Future<String?> getEmailBodyForDisplay(String emailId) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) return null;

      final message = await gmailApi.users.messages.get(
        'me',
        emailId,
        format: 'full',
      );

      // Try HTML first for rich rendering (links, formatting)
      final htmlBody = _findHtmlInPart(message.payload);
      if (htmlBody != null && htmlBody.isNotEmpty) return htmlBody;

      // Fall back to plain text body
      return _extractEmailBody(message);
    } catch (e) {
      print('Error getting email body for display: $e');
      return null;
    }
  }

  /// Recursively search MIME parts for text/html content
  static String? _findHtmlInPart(gmail.MessagePart? part) {
    if (part == null) return null;

    if (part.mimeType == 'text/html' && part.body?.data != null) {
      return _decodeBase64(part.body!.data!);
    }

    if (part.parts != null) {
      for (var subPart in part.parts!) {
        final html = _findHtmlInPart(subPart);
        if (html != null) return html;
      }
    }

    return null;
  }

  /// Search emails. Uses list (with page size) then parallel gets with metadata for speed.
  static Future<List<Email>> searchEmails(String query, {int maxResults = 50}) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) return [];

      final listResponse = await gmailApi.users.messages.list(
        'me',
        q: query,
        maxResults: maxResults.clamp(1, 500),
      );

      final messageRefs = listResponse.messages ?? [];
      if (messageRefs.isEmpty) return [];

      final futures = messageRefs.map((msgRef) async {
        try {
          final msg = await gmailApi.users.messages.get(
            'me',
            msgRef.id!,
            format: 'metadata',
          );
          return _parseGmailMessage(msg);
        } catch (e) {
          print('Error fetching message: $e');
          return null;
        }
      });
      final results = await Future.wait(futures);
      return results.whereType<Email>().toList();
    } catch (e) {
      print('Error searching emails: $e');
      return [];
    }
  }

  /// Mark email as read
  static Future<bool> markAsRead(String emailId) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) return false;

      await gmailApi.users.messages.modify(
        gmail.ModifyMessageRequest(removeLabelIds: ['UNREAD']),
        'me',
        emailId,
      );
      return true;
    } catch (e) {
      print('Error marking email as read: $e');
      return false;
    }
  }

  /// Mark email as spam
  static Future<bool> markAsSpam(String emailId) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) return false;

      await gmailApi.users.messages.modify(
        gmail.ModifyMessageRequest(addLabelIds: ['SPAM']),
        'me',
        emailId,
      );
      return true;
    } catch (e) {
      print('Error marking email as spam: $e');
      return false;
    }
  }

  /// Trash (delete) email
  static Future<bool> trashEmail(String emailId) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) return false;
      await gmailApi.users.messages.trash('me', emailId);
      return true;
    } catch (e) {
      print('Error trashing email: $e');
      return false;
    }
  }

  /// Parse Gmail message to Email object
  static Email _parseGmailMessage(gmail.Message message, {String labelId = 'INBOX'}) {
    String subject = 'No Subject';
    String from = 'Unknown';
    String to = '';
    String snippet = message.snippet ?? '';
    String body = _extractEmailBody(message);

    if (message.payload?.headers != null) {
      for (var header in message.payload!.headers!) {
        final name = header.name?.toLowerCase() ?? '';
        if (name == 'subject') subject = header.value ?? 'No Subject';
        if (name == 'from') from = header.value ?? 'Unknown';
        if (name == 'to') to = header.value ?? '';
      }
    }

    DateTime date = DateTime.now();
    if (message.internalDate != null) {
      date = DateTime.fromMillisecondsSinceEpoch(
        int.parse(message.internalDate!),
      );
    }

    return Email(
      id: message.id ?? '',
      subject: subject,
      from: from,
      to: to,
      snippet: snippet,
      body: body,
      date: date,
      labelId: labelId,
    );
  }

  /// Extract email body from Gmail message
  static String _extractEmailBody(gmail.Message message) {
    try {
      if (message.payload?.parts == null || message.payload!.parts!.isEmpty) {
        // Simple email with no parts
        if (message.payload?.body?.data != null) {
          return _decodeBase64(message.payload!.body!.data!);
        }
        return message.snippet ?? '';
      }

      // Multi-part email - look for text/plain or text/html
      for (var part in message.payload!.parts!) {
        if (part.mimeType == 'text/plain' && part.body?.data != null) {
          return _decodeBase64(part.body!.data!);
        }
      }

      // If no plain text, try HTML
      for (var part in message.payload!.parts!) {
        if (part.mimeType == 'text/html' && part.body?.data != null) {
          return _decodeBase64(part.body!.data!);
        }
      }

      return message.snippet ?? '';
    } catch (e) {
      print('Error extracting body: $e');
      return message.snippet ?? '';
    }
  }

  /// Decode base64 string
  static String _decodeBase64(String encoded) {
    try {
      // Gmail uses URL-safe base64 encoding
      String normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');
      // Add padding if needed
      int padding = (4 - (normalized.length % 4)) % 4;
      normalized += '=' * padding;

      final bytes = base64.decode(normalized);
      return utf8.decode(bytes);
    } catch (e) {
      print('Error decoding base64: $e');
      return encoded;
    }
  }

  /// Save emails to local storage
  static Future<void> _saveEmails(List<Email> emails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = emails
          .map((email) => jsonEncode(email.toMap()))
          .toList();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (e) {
      print('Error saving emails: $e');
    }
  }

  /// Load emails from local storage
  static Future<List<Email>> _loadEmails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      return jsonList.map((json) => Email.fromMap(jsonDecode(json))).toList();
    } catch (e) {
      print('Error loading emails: $e');
      return [];
    }
  }

  /// Update last sync time
  static Future<void> _updateLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error updating sync time: $e');
    }
  }

  /// Get last sync time
  static Future<DateTime?> getLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastSyncKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      print('Error getting last sync: $e');
      return null;
    }
  }

  /// Clear all cached emails
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      await prefs.remove(_lastSyncKey);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}

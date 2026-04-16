import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:my_app/src/services/gmail_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Email {
  final String id;
  final String subject;
  final String from;
  final String snippet;
  final String body;
  final DateTime date;
  final bool isPhishing;

  Email({
    required this.id,
    required this.subject,
    required this.from,
    required this.snippet,
    required this.body,
    required this.date,
    required this.isPhishing,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'from': from,
      'snippet': snippet,
      'body': body,
      'date': date.millisecondsSinceEpoch,
      'isPhishing': isPhishing,
    };
  }

  factory Email.fromMap(Map<String, dynamic> map) {
    return Email(
      id: map['id'] ?? '',
      subject: map['subject'] ?? '',
      from: map['from'] ?? '',
      snippet: map['snippet'] ?? '',
      body: map['body'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      isPhishing: map['isPhishing'] ?? false,
    );
  }
}

class GmailService {
  static const String _storageKey = 'gmail_emails';
  static const String _lastSyncKey = 'gmail_last_sync';

  /// Fetch emails from Gmail
  static Future<List<Email>> fetchEmails({int maxResults = 20}) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) {
        print('Gmail service not available');
        return [];
      }

      final messages = await gmailApi.users.messages.list(
        'me',
        q: 'is:unread',
        maxResults: maxResults,
        pageToken: null,
      );

      List<Email> emails = [];

      if (messages.messages != null && messages.messages!.isNotEmpty) {
        for (var message in messages.messages!) {
          try {
            final fullMessage = await gmailApi.users.messages.get(
              'me',
              message.id!,
              format: 'full',
            );

            final email = _parseGmailMessage(fullMessage);
            emails.add(email);
          } catch (e) {
            print('Error fetching full message: $e');
          }
        }
      }

      // Save to local storage
      await _saveEmails(emails);
      await _updateLastSync();

      return emails;
    } catch (e) {
      print('Error fetching emails: $e');
      // Return cached emails if fetch fails
      return await _loadEmails();
    }
  }

  /// Fetch all emails (paginated)
  /// [maxTotalResults] limits the total number of emails to fetch (null = no limit)
  static Future<List<Email>> fetchAllEmails({
    int pageSize = 20,
    int? maxTotalResults,
  }) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) return [];

      List<Email> allEmails = [];
      String? pageToken;

      do {
        final messages = await gmailApi.users.messages.list(
          'me',
          maxResults: pageSize,
          pageToken: pageToken,
        );

        if (messages.messages == null || messages.messages!.isEmpty) {
          break;
        }

        for (var message in messages.messages!) {
          // Stop if we've reached the max limit
          if (maxTotalResults != null && allEmails.length >= maxTotalResults) {
            break;
          }

          try {
            final fullMessage = await gmailApi.users.messages.get(
              'me',
              message.id!,
              format: 'full',
            );
            allEmails.add(_parseGmailMessage(fullMessage));
          } catch (e) {
            print('Error fetching message: $e');
          }
        }

        // Break if we've reached the max limit
        if (maxTotalResults != null && allEmails.length >= maxTotalResults) {
          break;
        }

        pageToken = messages.nextPageToken;
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

  /// Search emails
  static Future<List<Email>> searchEmails(String query) async {
    try {
      final gmailApi = await GmailAuthService.getGmailService();
      if (gmailApi == null) return [];

      final messages = await gmailApi.users.messages.list(
        'me',
        q: query,
        maxResults: 50,
      );

      List<Email> searchResults = [];

      if (messages.messages != null) {
        for (var message in messages.messages!) {
          try {
            final fullMessage = await gmailApi.users.messages.get(
              'me',
              message.id!,
              format: 'full',
            );
            searchResults.add(_parseGmailMessage(fullMessage));
          } catch (e) {
            print('Error fetching message: $e');
          }
        }
      }

      return searchResults;
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

      await gmailApi.users.messages.trash('me', emailId);
      return true;
    } catch (e) {
      print('Error marking email as spam: $e');
      return false;
    }
  }

  /// Parse Gmail message to Email object
  static Email _parseGmailMessage(gmail.Message message) {
    String subject = 'No Subject';
    String from = 'Unknown';
    String snippet = message.snippet ?? '';
    String body = _extractEmailBody(message);

    // Parse headers
    if (message.payload?.headers != null) {
      for (var header in message.payload!.headers!) {
        if (header.name?.toLowerCase() == 'subject') {
          subject = header.value ?? 'No Subject';
        }
        if (header.name?.toLowerCase() == 'from') {
          from = header.value ?? 'Unknown';
        }
      }
    }

    // Parse date
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
      snippet: snippet,
      body: body,
      date: date,
      isPhishing: false,
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

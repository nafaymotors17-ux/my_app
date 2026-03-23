import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/src/services/prefs_service.dart';

class SmsAiResult {
  final int prediction; // 0=safe, 1=phishing
  final String result; // "Safe" / "Phishing"

  const SmsAiResult({required this.prediction, required this.result});

  factory SmsAiResult.fromJson(Map<String, dynamic> json) {
    return SmsAiResult(
      prediction: (json['prediction'] as num).toInt(),
      result: (json['result'] as String?) ?? '',
    );
  }
}

class EmailUrlPrediction {
  final String url;
  final int prediction;
  final String result;

  const EmailUrlPrediction({
    required this.url,
    required this.prediction,
    required this.result,
  });

  factory EmailUrlPrediction.fromJson(Map<String, dynamic> json) {
    return EmailUrlPrediction(
      url: (json['url'] as String?) ?? '',
      prediction: (json['prediction'] as num).toInt(),
      result: (json['result'] as String?) ?? '',
    );
  }
}

class EmailCheckResult {
  final int emailPrediction;
  final String emailResult;
  final List<EmailUrlPrediction> links;
  final int overallPrediction;
  final String overallResult;

  const EmailCheckResult({
    required this.emailPrediction,
    required this.emailResult,
    required this.links,
    required this.overallPrediction,
    required this.overallResult,
  });

  factory EmailCheckResult.fromJson(Map<String, dynamic> json) {
    final linksJson = (json['links'] as List?) ?? const [];
    return EmailCheckResult(
      emailPrediction: (json['email_prediction'] as num).toInt(),
      emailResult: (json['email_result'] as String?) ?? '',
      links: linksJson
          .map((e) => EmailUrlPrediction.fromJson(e as Map<String, dynamic>))
          .toList(),
      overallPrediction: (json['overall_prediction'] as num).toInt(),
      overallResult: (json['overall_result'] as String?) ?? '',
    );
  }
}

class UrlLinksResult {
  final List<EmailUrlPrediction> links;
  final int overallPrediction;
  final String overallResult;

  const UrlLinksResult({
    required this.links,
    required this.overallPrediction,
    required this.overallResult,
  });

  factory UrlLinksResult.fromJson(Map<String, dynamic> json) {
    final linksJson = (json['links'] as List?) ?? const [];
    return UrlLinksResult(
      links: linksJson
          .map((e) => EmailUrlPrediction.fromJson(e as Map<String, dynamic>))
          .toList(),
      overallPrediction: (json['overall_prediction'] as num).toInt(),
      overallResult: (json['overall_result'] as String?) ?? '',
    );
  }
}

class SmsAiService {
  static String defaultBaseUrl() {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    // Prefer USB-debug real device flow via adb reverse.
    if (Platform.isAndroid) return 'http://127.0.0.1:8000';
    return 'http://127.0.0.1:8000';
  }

  static Future<String> getBaseUrl() async {
    final saved = await PrefsService.getAiBaseUrl();
    return (saved == null || saved.trim().isEmpty) ? defaultBaseUrl() : saved;
  }

  static Future<SmsAiResult> checkSms(String message) async {
    final savedBaseUrl = await getBaseUrl();
    final androidUsbBaseUrl = 'http://127.0.0.1:8000';

    final candidates = <String>[savedBaseUrl];
    if (Platform.isAndroid && savedBaseUrl != androidUsbBaseUrl) {
      candidates.add(androidUsbBaseUrl);
    }

    Object? lastError;
    for (final baseUrl in candidates) {
      final uri = Uri.parse(baseUrl).replace(path: '/check_sms');
      try {
        final res = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'message': message}),
            )
            .timeout(const Duration(seconds: 6));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('API error ${res.statusCode}: ${res.body}');
        }

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return SmsAiResult.fromJson(data);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(
      lastError?.toString() ??
          'Could not connect to backend. On your PC run: adb reverse tcp:8000 tcp:8000',
    );
  }

  static Future<EmailCheckResult> checkEmail(String emailBody) async {
    final savedBaseUrl = await getBaseUrl();
    final androidUsbBaseUrl = 'http://127.0.0.1:8000';

    final candidates = <String>[savedBaseUrl];
    if (Platform.isAndroid && savedBaseUrl != androidUsbBaseUrl) {
      candidates.add(androidUsbBaseUrl);
    }

    Object? lastError;
    for (final baseUrl in candidates) {
      final uri = Uri.parse(baseUrl).replace(path: '/check_email');
      try {
        final res = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'message': emailBody}),
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('API error ${res.statusCode}: ${res.body}');
        }

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return EmailCheckResult.fromJson(data);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(
      lastError?.toString() ??
          'Could not connect to backend. On your PC run: adb reverse tcp:8000 tcp:8000',
    );
  }

  static Future<SmsAiResult> checkEmailText(String emailBody) async {
    final savedBaseUrl = await getBaseUrl();
    final androidUsbBaseUrl = 'http://127.0.0.1:8000';

    final candidates = <String>[savedBaseUrl];
    if (Platform.isAndroid && savedBaseUrl != androidUsbBaseUrl) {
      candidates.add(androidUsbBaseUrl);
    }

    Object? lastError;
    for (final baseUrl in candidates) {
      final uri = Uri.parse(baseUrl).replace(path: '/check_email_text');
      try {
        final res = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'message': emailBody}),
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('API error ${res.statusCode}: ${res.body}');
        }

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return SmsAiResult.fromJson(data);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(
      lastError?.toString() ??
          'Could not connect to backend. On your PC run: adb reverse tcp:8000 tcp:8000',
    );
  }

  static Future<UrlLinksResult> checkUrls(List<String> urls) async {
    final savedBaseUrl = await getBaseUrl();
    final androidUsbBaseUrl = 'http://127.0.0.1:8000';

    final candidates = <String>[savedBaseUrl];
    if (Platform.isAndroid && savedBaseUrl != androidUsbBaseUrl) {
      candidates.add(androidUsbBaseUrl);
    }

    Object? lastError;
    for (final baseUrl in candidates) {
      final uri = Uri.parse(baseUrl).replace(path: '/check_urls');
      try {
        final res = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'urls': urls}),
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('API error ${res.statusCode}: ${res.body}');
        }

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return UrlLinksResult.fromJson(data);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(
      lastError?.toString() ??
          'Could not connect to backend. On your PC run: adb reverse tcp:8000 tcp:8000',
    );
  }
}


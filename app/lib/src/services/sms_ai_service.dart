import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SmsAiResult {
  final int prediction; // 0=safe, 1=phishing
  final String result; // "Safe" / "Phishing"
  /// Class probability for phishing (0–1), when the model exposes `predict_proba`.
  final double? phishingProbability;

  const SmsAiResult({
    required this.prediction,
    required this.result,
    this.phishingProbability,
  });

  factory SmsAiResult.fromJson(Map<String, dynamic> json) {
    final predRaw = json['prediction'];
    if (predRaw is! num) {
      throw const FormatException('Invalid JSON: prediction');
    }
    final p = json['phishing_probability'] ?? json['phishingProbability'];
    return SmsAiResult(
      prediction: predRaw.toInt(),
      result: (json['result'] as String?) ?? '',
      phishingProbability: p is num ? p.toDouble() : null,
    );
  }

  /// Backend can return [prediction]==0 while probability is still high (uncertain).
  String? get phishingPercentLabel {
    final prob = phishingProbability;
    if (prob == null) return null;
    final pct = (prob * 100).clamp(0.0, 100.0);
    return '${pct.toStringAsFixed(1)}%';
  }

  /// Model confidence line — only meaningful when [prediction] is phishing.
  String? get phishingConfidenceLine {
    if (prediction != 1 || phishingProbability == null) return null;
    return 'Model confidence: $phishingPercentLabel';
  }
}

class EmailUrlPrediction {
  final String url;
  final int prediction;
  final String result;
  final double? phishingProbability;

  const EmailUrlPrediction({
    required this.url,
    required this.prediction,
    required this.result,
    this.phishingProbability,
  });

  factory EmailUrlPrediction.fromJson(Map<String, dynamic> json) {
    final p = json['phishing_probability'] ?? json['phishingProbability'];
    return EmailUrlPrediction(
      url: (json['url'] as String?) ?? '',
      prediction: (json['prediction'] as num).toInt(),
      result: (json['result'] as String?) ?? '',
      phishingProbability: p is num ? p.toDouble() : null,
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

class SmsAiService {
  /// Deployed FastAPI backend on Railway (HTTPS).
  static const String productionBaseUrl =
      'https://phishingdetector-production-7c38.up.railway.app';

  /// Human-readable + debug-console detail for http/io failures.
  static String describeNetworkError(Object e) {
    if (e is http.ClientException) {
      final u = e.uri;
      return 'ClientException: ${e.message}${u != null ? ' (uri: $u)' : ''}';
    }
    if (e is SocketException) {
      return 'SocketException: ${e.message} (${e.address?.address ?? e.osError})';
    }
    if (e is TimeoutException) {
      return 'Timeout: ${e.message ?? 'request took too long'}';
    }
    if (e is FormatException) {
      return 'Bad response (not JSON): ${e.message}';
    }
    final s = e.toString();
    if (s.startsWith('Exception: ')) {
      return s.substring('Exception: '.length);
    }
    return s;
  }

  static bool _isLocalDevBaseUrl(String baseUrl) {
    final lower = baseUrl.toLowerCase();
    return lower.contains('127.0.0.1') ||
        lower.contains('localhost') ||
        lower.contains('10.0.2.2');
  }

  /// Matches FastAPI `_normalize_text` so Postman and the app classify the same text.
  static String normalizeMessageForApi(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).join(' ');
  }

  /// SMS uses `/check_sms`; email body uses `/check_message` (same text model).
  static Future<SmsAiResult> _postMessage(
    String message,
    String endpointPath,
  ) async {
    final normalized = normalizeMessageForApi(message);
    const savedBaseUrl = productionBaseUrl;
    const androidUsbBaseUrl = 'http://127.0.0.1:8001';

    // Debug-only: try adb reverse (127.0.0.1) after emulator LAN IP. Release builds
    // should not touch 127.0.0.1 — it confused users when prefs still had local URLs.
    final candidates = <String>[savedBaseUrl];
    if (!kReleaseMode &&
        Platform.isAndroid &&
        _isLocalDevBaseUrl(savedBaseUrl) &&
        savedBaseUrl != androidUsbBaseUrl) {
      candidates.add(androidUsbBaseUrl);
    }

    Object? lastError;
    StackTrace? lastStack;
    for (final baseUrl in candidates) {
      final uri = Uri.parse(baseUrl).replace(path: endpointPath);
      try {
        developer.log('POST $uri', name: 'SmsAiService');
        if (kDebugMode) {
          developer.log(
            'AI payload len=${normalized.length} chars',
            name: 'SmsAiService',
          );
        }
        final res = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'message': normalized}),
            )
            .timeout(const Duration(seconds: 15));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('API error ${res.statusCode}: ${res.body}');
        }

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return SmsAiResult.fromJson(data);
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        final msg = describeNetworkError(e);
        developer.log(
          '_postMessage failed: $msg',
          name: 'SmsAiService',
          error: e,
          stackTrace: st,
        );
      }
    }

    final detail = lastError != null
        ? describeNetworkError(lastError)
        : 'Unknown error';
    if (lastStack != null) {
      developer.log('_postMessage giving up', stackTrace: lastStack);
    }
    final tried = candidates
        .map((b) => Uri.parse(b).replace(path: endpointPath).toString())
        .join(', ');
    throw Exception(
      'Could not reach the API ($detail). Tried: $tried. '
      'Check base URL in app settings, Wi‑Fi/mobile data, and that Railway is up.',
    );
  }

  static Future<SmsAiResult> checkSms(String message) async {
    return _postMessage(message, '/check_sms');
  }

  /// Same classifier as SMS; Railway uses POST `/check_message` for this path.
  static Future<EmailCheckResult> checkEmail(String emailBody) async {
    final sms = await _postMessage(emailBody, '/check_message');
    return EmailCheckResult(
      emailPrediction: sms.prediction,
      emailResult: sms.result,
      links: const [],
      overallPrediction: sms.prediction,
      overallResult: sms.result,
    );
  }

  static Future<SmsAiResult> checkEmailText(String emailBody) async {
    return _postMessage(emailBody, '/check_message');
  }
}


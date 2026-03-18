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

class SmsAiService {
  static String defaultBaseUrl() {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000'; // Android emulator
    return 'http://127.0.0.1:8000';
  }

  static Future<String> getBaseUrl() async {
    final saved = await PrefsService.getAiBaseUrl();
    return (saved == null || saved.trim().isEmpty) ? defaultBaseUrl() : saved;
  }

  static Future<SmsAiResult> checkSms(String message) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse(baseUrl).replace(path: '/check_sms');

    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return SmsAiResult.fromJson(data);
  }
}


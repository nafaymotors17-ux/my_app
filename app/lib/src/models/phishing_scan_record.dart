import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/services/sms_ai_service.dart';

/// Persisted result of an on-device AI phishing check for a single message.
class PhishingScanRecord {
  final String messageId;
  final String source; // sms | gmail
  final int prediction; // 0 safe, 1 phishing
  final double? phishingProbability;
  final int scannedAtMs;
  final String title;
  final String preview;
  final String address;

  const PhishingScanRecord({
    required this.messageId,
    required this.source,
    required this.prediction,
    this.phishingProbability,
    required this.scannedAtMs,
    required this.title,
    required this.preview,
    required this.address,
  });

  bool get isPhishing => prediction == 1;

  factory PhishingScanRecord.fromMessage(Message msg, SmsAiResult result) {
    final preview = msg.body.trim();
    final title = msg.source == 'gmail'
        ? (msg.subject ?? msg.address)
        : msg.address;
    return PhishingScanRecord(
      messageId: msg.id,
      source: msg.source,
      prediction: result.prediction,
      phishingProbability: result.phishingProbability,
      scannedAtMs: DateTime.now().millisecondsSinceEpoch,
      title: title,
      preview: preview.length > 280 ? '${preview.substring(0, 280)}…' : preview,
      address: msg.address,
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'source': source,
        'prediction': prediction,
        'phishingProbability': phishingProbability,
        'scannedAtMs': scannedAtMs,
        'title': title,
        'preview': preview,
        'address': address,
      };

  factory PhishingScanRecord.fromJson(Map<String, dynamic> json) {
    return PhishingScanRecord(
      messageId: json['messageId'] as String? ?? '',
      source: json['source'] as String? ?? 'sms',
      prediction: (json['prediction'] as num?)?.toInt() ?? 0,
      phishingProbability: (json['phishingProbability'] as num?)?.toDouble(),
      scannedAtMs: (json['scannedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      title: json['title'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }
}

import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/services/sms_ai_service.dart';

/// One row in a batch scan run.
class BatchScanResultItem {
  const BatchScanResultItem._({
    required this.message,
    this.result,
    this.errorMessage,
  });

  final Message message;
  final SmsAiResult? result;
  final String? errorMessage;

  factory BatchScanResultItem.success(Message m, SmsAiResult r) => BatchScanResultItem._(
        message: m,
        result: r,
      );

  factory BatchScanResultItem.failure(Message m, String err) => BatchScanResultItem._(
        message: m,
        errorMessage: err,
      );

  bool get isFailure => errorMessage != null;
  bool get isPhishing => result?.prediction == 1;
  bool get isSafe => result != null && result!.prediction == 0;
}

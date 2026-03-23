import 'package:flutter/services.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.sms_reader/sms',
  );

  static Future<List<dynamic>> getSmsMessages() async {
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getSmsMessages');
      return res ?? <dynamic>[];
    } on PlatformException {
      return <dynamic>[];
    }
  }

  // Get SMS messages with read/unread status
  static Future<List<dynamic>> getSmsMessagesWithReadStatus() async {
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getSmsMessagesWithReadStatus');
      return res ?? <dynamic>[];
    } on PlatformException {
      return <dynamic>[];
    }
  }
}

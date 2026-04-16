import 'dart:convert';

import 'package:my_app/src/models/phishing_scan_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static SharedPreferences? _prefs;

  static const String _phishingScansKey = 'phishing_scans_v1';
  static const String _onboardingCompletedKey = 'onboarding_completed_v1';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// First-run 3-slide intro (permissions, Gmail, how scanning works).
  static bool hasCompletedOnboarding() {
    return _prefs?.getBool(_onboardingCompletedKey) ?? false;
  }

  static Future<void> setOnboardingCompleted([bool completed = true]) async {
    await _prefs?.setBool(_onboardingCompletedKey, completed);
  }

  /// All persisted AI scan results keyed by message id.
  static Map<String, PhishingScanRecord> getPhishingScans() {
    final raw = _prefs?.getString(_phishingScansKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final out = <String, PhishingScanRecord>{};
      for (final e in decoded.entries) {
        final m = e.value;
        if (m is Map<String, dynamic>) {
          out[e.key] = PhishingScanRecord.fromJson(m);
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> savePhishingScans(Map<String, PhishingScanRecord> map) async {
    final encoded = jsonEncode(
      map.map((k, v) => MapEntry(k, v.toJson())),
    );
    await _prefs?.setString(_phishingScansKey, encoded);
  }

  static Future<void> removePhishingScan(String messageId) async {
    final m = getPhishingScans();
    m.remove(messageId);
    await savePhishingScans(m);
  }

  static Set<String> getReadIds() {
    return _prefs?.getStringList('read_ids')?.toSet() ?? <String>{};
  }

  static Set<String> getClearedIds() {
    return _prefs?.getStringList('cleared_ids')?.toSet() ?? <String>{};
  }

  static Future<void> saveReadIds(Set<String> ids) async {
    await _prefs?.setStringList('read_ids', ids.toList());
  }

  static Future<void> saveClearedIds(Set<String> ids) async {
    await _prefs?.setStringList('cleared_ids', ids.toList());
  }

  static Future<void> clearAll() async {
    await _prefs?.remove('read_ids');
    await _prefs?.remove('cleared_ids');
    await _prefs?.remove(_phishingScansKey);
    await _prefs?.remove(_onboardingCompletedKey);
  }

  /// Clears only AI phishing scan history (Threat inbox + list badges).
  static Future<void> clearPhishingScansOnly() async {
    await _prefs?.remove(_phishingScansKey);
  }
}

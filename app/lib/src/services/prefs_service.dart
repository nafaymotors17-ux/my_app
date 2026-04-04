import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static SharedPreferences? _prefs;
  /// Legacy key: older builds saved emulator/USB URLs here and they overrode Railway.
  static const String _aiBaseUrlKeyLegacy = 'ai_base_url';
  static const String _aiBaseUrlKey = 'ai_base_url_override';

  static bool _looksLikeLocalDevUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('127.0.0.1') ||
        lower.contains('localhost') ||
        lower.contains('10.0.2.2');
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final legacy = _prefs?.getString(_aiBaseUrlKeyLegacy);
    if (legacy != null) {
      final trimmed = legacy.trim();
      final current = _prefs?.getString(_aiBaseUrlKey)?.trim() ?? '';
      if (trimmed.isNotEmpty &&
          !_looksLikeLocalDevUrl(trimmed) &&
          current.isEmpty) {
        await _prefs?.setString(_aiBaseUrlKey, trimmed);
      }
      await _prefs?.remove(_aiBaseUrlKeyLegacy);
    }
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
    await _prefs?.remove(_aiBaseUrlKey);
    await _prefs?.remove(_aiBaseUrlKeyLegacy);
  }

  static Future<String?> getAiBaseUrl() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs?.getString(_aiBaseUrlKey);
  }

  static Future<void> setAiBaseUrl(String url) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_aiBaseUrlKey, url);
  }
}

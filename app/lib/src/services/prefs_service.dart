import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static SharedPreferences? _prefs;
  static const String _aiBaseUrlKey = 'ai_base_url';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

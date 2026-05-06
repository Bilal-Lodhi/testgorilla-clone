import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistence for test access codes
/// Stores access code per testId so candidates don't need to re-enter
/// after page refresh or re-navigation.
///
/// Security: This is a UX convenience layer only.
/// The backend is ALWAYS the source of truth for validation.
class AccessCodeStorage {
  static const String _prefix = 'testgorilla_access_';

  static String _key(String testId) => '$_prefix$testId';

  /// Store verified access code for a test
  static Future<void> setCode(String testId, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(testId), code.trim());
  }

  /// Get stored access code for a test, or null if not stored
  static Future<String?> getCode(String testId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(testId));
  }

  /// Check if an access code is stored for a test
  static Future<bool> hasCode(String testId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key(testId));
  }

  /// Clear stored access code for a specific test
  static Future<void> clearForTest(String testId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(testId));
  }

  /// Clear all stored access codes
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

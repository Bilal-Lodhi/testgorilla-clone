import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistence for the active test attempt.
/// Ensures the candidate can resume after a page refresh or app restart.
///
/// Backend is the source of truth for timing, status, and question index.
/// This storage is UX convenience — it tells the client which attempt to
/// query via GET /attempts/active or GET /attempts/:id.
class AttemptStorage {
  static const String _attemptIdKey = 'testgorilla_active_attempt_id';
  static const String _testIdKey = 'testgorilla_active_test_id';
  static const String _testDurationKey =
      'testgorilla_active_test_duration_minutes';

  /// Persist active attempt identifiers so the resume flow knows where to
  /// pick up after a refresh / restart.
  static Future<void> setActiveAttempt({
    required String attemptId,
    required String testId,
    required int durationMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_attemptIdKey, attemptId);
    await prefs.setString(_testIdKey, testId);
    await prefs.setInt(_testDurationKey, durationMinutes);
  }

  /// Clear persisted attempt data — call when attempt is submitted or expired.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attemptIdKey);
    await prefs.remove(_testIdKey);
    await prefs.remove(_testDurationKey);
  }

  /// Get the previously stored active attempt id, or `null` if none.
  static Future<String?> getAttemptId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_attemptIdKey);
  }

  /// Get the previously stored active test id, or `null` if none.
  static Future<String?> getTestId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_testIdKey);
  }

  /// Get the previously stored test duration in minutes, or `null` if none.
  static Future<int?> getDurationMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_testDurationKey);
    return value;
  }

  /// True when an attempt was active before the session ended.
  static Future<bool> hasActiveAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_attemptIdKey);
  }
}

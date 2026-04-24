import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class JwtStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _roleKey = 'user_role';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save JWT token
  static Future<bool> saveToken(String token) async {
    return await _prefs.setString(_tokenKey, token);
  }

  /// Get JWT token
  static String? getToken() {
    return _prefs.getString(_tokenKey);
  }

  /// Check if token exists
  static bool hasToken() {
    return _prefs.containsKey(_tokenKey);
  }

  /// Save user data
  static Future<bool> saveUser(Map<String, dynamic> userData) async {
    return await _prefs.setString(_userKey, jsonEncode(userData));
  }

  /// Get user data
  static Map<String, dynamic>? getUser() {
    final userJson = _prefs.getString(_userKey);
    if (userJson == null) return null;
    return jsonDecode(userJson) as Map<String, dynamic>;
  }

  /// Save user role
  static Future<bool> saveRole(String role) async {
    return await _prefs.setString(_roleKey, role);
  }

  /// Get user role
  static String? getRole() {
    return _prefs.getString(_roleKey);
  }

  /// Check if logged in
  static bool isLoggedIn() {
    return hasToken();
  }

  /// Clear all auth data
  static Future<bool> clearAuth() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
    await _prefs.remove(_roleKey);
    return true;
  }

  /// Get user ID from stored user data
  static String? getUserId() {
    final user = getUser();
    return user?['id'] as String?;
  }
}

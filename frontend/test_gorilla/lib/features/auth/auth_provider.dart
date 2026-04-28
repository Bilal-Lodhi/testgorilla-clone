import 'package:flutter/material.dart';
import 'package:test_gorilla/features/auth/auth_service.dart';
import 'package:test_gorilla/core/api/api_client.dart';

class AuthProvider extends ChangeNotifier {
  late AuthService _authService;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;
  String? _userRole;
  Map<String, dynamic>? _userData;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  String? get userRole => _userRole;
  Map<String, dynamic>? get userData => _userData;

  AuthProvider(ApiClient apiClient) {
    _authService = AuthService(apiClient);
    _initializeAuth();
  }

  String _mapAuthError(Object error, {bool isLogin = false}) {
    if (error is ApiException) {
      if (isLogin && error.statusCode == 401) {
        return 'Invalid email or password';
      }

      if (error.statusCode >= 500) {
        return 'Something went wrong. Please try again.';
      }

      return error.message;
    }

    if (error is TimeoutException) {
      return 'Request timed out. Please check your connection and try again.';
    }

    return 'Unable to complete request. Please try again.';
  }

  /// Initialize auth state on startup
  Future<void> _initializeAuth() async {
    _isLoggedIn = _authService.isLoggedIn();
    _userRole = _authService.getUserRole();
    _userData = _authService.getUserData();
    notifyListeners();
  }

  /// Login user
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.login(email: email, password: password);
      _isLoggedIn = true;
      _userRole = _authService.getUserRole();
      _userData = _authService.getUserData();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapAuthError(e, isLogin: true);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register user
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.register(
        email: email,
        password: password,
        name: name,
        role: role,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.logout();
    } catch (e) {
      _error = _mapAuthError(e);
    } finally {
      _isLoggedIn = false;
      _userRole = null;
      _userData = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if user is admin
  bool isAdmin() {
    return _userRole == 'admin';
  }

  /// Check if user is candidate
  bool isCandidate() {
    return _userRole == 'candidate';
  }

  /// Delete account
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.deleteAccount();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

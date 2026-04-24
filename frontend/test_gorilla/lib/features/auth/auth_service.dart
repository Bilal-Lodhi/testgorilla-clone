import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';
import 'package:test_gorilla/core/utils/jwt_storage.dart';

class AuthService {
  final ApiClient apiClient;

  AuthService(this.apiClient);

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final response = await apiClient.post(
        ApiConstants.authRegister,
        body: {
          'email': email,
          'password': password,
          'name': name,
          'role': role,
        },
      );

      return response as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await apiClient.post(
        ApiConstants.authLogin,
        body: {'email': email, 'password': password},
      );

      final data = response as Map<String, dynamic>;

      // Save token
      if (data['data'] != null && data['data']['accessToken'] != null) {
        await JwtStorage.saveToken(data['data']['accessToken']);
      }

      // Save user data
      if (data['data'] != null && data['data']['user'] != null) {
        await JwtStorage.saveUser(data['data']['user']);
        final role = data['data']['user']['role'];
        if (role != null) {
          await JwtStorage.saveRole(role);
        }
      }

      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Get current user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await apiClient.get(ApiConstants.authProfile);
      return response as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await apiClient.post(ApiConstants.authLogout);
    } catch (e) {
      // Best-effort logout: the app should still clear local auth state.
    }

    await JwtStorage.clearAuth();
  }

  /// Check if logged in
  bool isLoggedIn() {
    return JwtStorage.isLoggedIn();
  }

  /// Get user role
  String? getUserRole() {
    return JwtStorage.getRole();
  }

  /// Get user data
  Map<String, dynamic>? getUserData() {
    return JwtStorage.getUser();
  }
}

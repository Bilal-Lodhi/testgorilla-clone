import 'package:test_gorilla/core/constants/api_constants.dart';

/// Production-safe configuration validator
/// Ensures all required environment variables are set at startup
class ConfigValidator {
  /// Validates that all required configuration is present
  /// Throws [Exception] if API_BASE_URL is missing
  ///
  /// MUST be called in main() before running the app
  static void validate() {
    _validateApiBaseUrl();
  }

  /// Validates that API_BASE_URL is set and not empty
  static void _validateApiBaseUrl() {
    if (ApiConstants.baseUrl.isEmpty) {
      throw Exception(
        'FATAL: API_BASE_URL is not set!\n'
        'This is a production-safety requirement.\n'
        'Build commands MUST include:\n'
        '  Web: flutter build web --dart-define=API_BASE_URL=https://...\n'
        '  APK: flutter build apk --dart-define=API_BASE_URL=https://...\n'
        'Development:\n'
        '  flutter run --dart-define=API_BASE_URL=http://localhost:5000/api/v1',
      );
    }
  }
}

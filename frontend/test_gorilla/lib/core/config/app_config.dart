import 'package:test_gorilla/core/constants/api_constants.dart';

class AppConfig {
  static const String appName = 'TestGorilla';
  static const String appVersion = '1.0.0';

  // API configuration
  static String get apiBaseUrl => ApiConstants.baseUrl;
  static const int apiTimeoutSeconds = 30;

  // Feature flags
  static const bool enableDebugLogging = true;

  // UI configuration
  static const int mobileBreakpoint = 600;
  static const int tabletBreakpoint = 1024;
}

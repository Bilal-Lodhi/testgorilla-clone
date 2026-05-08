import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/utils/jwt_storage.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/config/app_config.dart';
import 'package:test_gorilla/core/config/config_validator.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';
import 'package:test_gorilla/core/theme/theme_provider.dart';
import 'package:test_gorilla/features/auth/auth_provider.dart';
import 'package:test_gorilla/features/auth/login_screen.dart';
import 'package:test_gorilla/features/navigation/app_router.dart';
import 'package:test_gorilla/features/admin/dashboard_screen.dart';
import 'package:test_gorilla/features/candidate/candidate_dashboard_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Validate production-safe configuration
  ConfigValidator.validate();

  // Log resolved API base URL for debugging (helps verify --dart-define)
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    // ignore: avoid_print
    print('[Startup] Resolved API_BASE_URL=${ApiConstants.baseUrl}');
  }

  // Initialize JWT storage
  await JwtStorage.init();

  // Initialize theme provider (restore persisted preference)
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const MyApp({Key? key, required this.themeProvider}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final authProvider = AuthProvider(apiClient);
    apiClient.setUnauthorizedHandler(authProvider.handleSessionExpired);

    return MultiProvider(
      providers: [
        // API Client
        Provider<ApiClient>(create: (_) => apiClient),

        // Auth Provider
        ChangeNotifierProvider(create: (_) => authProvider),

        // Theme Provider
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppConfig.appName,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: const SplashScreenWrapper(),
            onGenerateRoute: AppRouter.generateRoute,
          );
        },
      ),
    );
  }
}

// Wrapper for admin dashboard with logout
class AdminDashboardWrapper extends StatelessWidget {
  const AdminDashboardWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardScreen();
  }
}

// Wrapper for candidate app with logout
class CandidateDashboardWrapper extends StatelessWidget {
  const CandidateDashboardWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CandidateDashboardShell();
  }
}

// Splash screen wrapper
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({Key? key}) : super(key: key);

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Image.asset(
            'assets/images/main.png',
            fit: BoxFit.contain,
            width: MediaQuery.of(context).size.width * 0.8,
          ),
        ),
      );
    }

    // After splash, show auth-based content
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Check authentication state
        if (authProvider.isLoggedIn) {
          // Route based on user role
          if (authProvider.isAdmin()) {
            return WillPopScope(
              onWillPop: () async => false,
              child: const AdminDashboardWrapper(),
            );
          } else {
            return WillPopScope(
              onWillPop: () async => false,
              child: const CandidateDashboardWrapper(),
            );
          }
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

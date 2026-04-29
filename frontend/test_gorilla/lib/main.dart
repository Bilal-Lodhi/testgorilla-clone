import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/utils/jwt_storage.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/config/app_config.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';
import 'package:test_gorilla/features/auth/auth_provider.dart';
import 'package:test_gorilla/features/auth/login_screen.dart';
import 'package:test_gorilla/features/navigation/app_router.dart';
import 'package:test_gorilla/features/admin/dashboard_screen.dart';
import 'package:test_gorilla/features/candidate/candidate_dashboard_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize JWT storage
  await JwtStorage.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreenWrapper(),
        onGenerateRoute: AppRouter.generateRoute,
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
        backgroundColor: Colors.white,
        body: Center(
          child: Image.asset(
            'lib/core/utils/main.png',
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

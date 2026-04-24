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

    return MultiProvider(
      providers: [
        // API Client
        Provider<ApiClient>(create: (_) => apiClient),

        // Auth Provider
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient)),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: Consumer<AuthProvider>(
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
        ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('TestGorilla Admin'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: const AdminDashboardScreen(),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
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

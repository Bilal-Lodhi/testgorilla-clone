import 'package:flutter/material.dart';
import 'package:test_gorilla/features/auth/login_screen.dart';
import 'package:test_gorilla/features/admin/dashboard_screen.dart';
import 'package:test_gorilla/features/admin/create_test_screen.dart';
import 'package:test_gorilla/features/admin/add_questions_screen.dart';
import 'package:test_gorilla/features/candidate/test_list_screen.dart';
import 'package:test_gorilla/features/candidate/attempt_screen.dart';
import 'package:test_gorilla/features/candidate/result_screen.dart';
import 'package:test_gorilla/features/shared/models/models.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case '/admin/dashboard':
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
      
      case '/admin/create-test':
        return MaterialPageRoute(builder: (_) => const CreateTestScreen());
      
      case '/admin/add-questions':
        final testId = settings.arguments as String?;
        if (testId == null) {
          return _errorRoute('Test ID required');
        }
        return MaterialPageRoute(
          builder: (_) => AddQuestionsScreen(testId: testId),
        );
      
      case '/candidate/test-list':
        return MaterialPageRoute(builder: (_) => const TestListScreen());
      
      case '/candidate/attempt':
        final test = settings.arguments as Test?;
        if (test == null) {
          return _errorRoute('Test data required');
        }
        return MaterialPageRoute(
          builder: (_) => AttemptScreen(test: test),
        );
      
      case '/candidate/result':
        final attemptId = settings.arguments as String?;
        if (attemptId == null) {
          return _errorRoute('Attempt ID required');
        }
        return MaterialPageRoute(
          builder: (_) => ResultScreen(attemptId: attemptId),
        );
      
      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }
  
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}

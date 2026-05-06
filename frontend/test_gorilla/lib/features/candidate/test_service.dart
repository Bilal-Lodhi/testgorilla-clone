import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';
import 'package:test_gorilla/features/shared/models/models.dart';

class TestService {
  final ApiClient apiClient;

  TestService(this.apiClient);

  /// Get all available tests for candidate
  Future<List<Test>> getAvailableTests() async {
    try {
      final response = await apiClient.get(ApiConstants.tests);
      if (response['data'] is List) {
        return (response['data'] as List)
            .map((t) => Test.fromJson(t as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Get single test details
  Future<Test> getTest(String testId) async {
    try {
      final response = await apiClient.get(ApiConstants.testById(testId));
      return Test.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all questions for a test
  Future<List<Question>> getTestQuestions(String testId) async {
    try {
      final response = await apiClient.get(ApiConstants.questions(testId));
      if (response['data'] is List) {
        return (response['data'] as List)
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Start test attempt (requires access_code for server-side verification)
  Future<Map<String, dynamic>> startAttempt(
    String testId, {
    required String accessCode,
  }) async {
    try {
      final response = await apiClient.post(
        ApiConstants.startAttempt(testId),
        body: {'access_code': accessCode},
      );
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Get a single attempt by id — returns full resume payload:
  /// { attempt, current_question_index, start_time, duration }
  Future<Map<String, dynamic>> getAttempt(String attemptId) async {
    try {
      final response = await apiClient.get(ApiConstants.getAttempt(attemptId));
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Get the active (in_progress) attempt for the currently logged-in user.
  /// Returns null if no active attempt exists.
  Future<Map<String, dynamic>?> getActiveAttempt() async {
    try {
      final response = await apiClient.get(ApiConstants.activeAttempt);
      final data = response['data'];
      if (data is Map<String, dynamic> && data.isNotEmpty) {
        return data;
      }
      return null;
    } catch (e) {
      // 404 means no active attempt — expected, not an error
      rethrow;
    }
  }

  /// Submit answer to a question
  Future<void> submitResponse(
    String attemptId, {
    required String questionId,
    String? selectedOptionId,
    String? codeAnswer,
  }) async {
    try {
      await apiClient.post(
        ApiConstants.submitResponse(attemptId),
        body: {
          'questionId': questionId,
          if (selectedOptionId != null) 'selected_option': selectedOptionId,
          if (codeAnswer != null) 'codeAnswer': codeAnswer,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Verify test access code before starting
  Future<bool> verifyAccessCode(String testId, String accessCode) async {
    try {
      final response = await apiClient.post(
        ApiConstants.verifyAccess(testId),
        body: {'access_code': accessCode},
      );
      return response?['data']?['verified'] == true;
    } catch (e) {
      rethrow;
    }
  }

  /// Submit test attempt
  Future<void> submitAttempt(String attemptId) async {
    try {
      await apiClient.post(ApiConstants.submitAttempt(attemptId));
    } catch (e) {
      rethrow;
    }
  }

  /// Get result for an attempt
  Future<Map<String, dynamic>> getResult(String attemptId) async {
    try {
      final response = await apiClient.get(ApiConstants.getResult(attemptId));
      return response as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Get candidate attempts
  Future<List<TestAttempt>> getCandidateAttempts() async {
    try {
      final response = await apiClient.get(ApiConstants.candidateAttempts);
      final data = response['data'];

      if (data is List) {
        return data
            .map((a) => TestAttempt.fromJson(a as Map<String, dynamic>))
            .toList();
      }

      if (data is Map && data['attempts'] is List) {
        return (data['attempts'] as List)
            .map((a) => TestAttempt.fromJson(a as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }
}

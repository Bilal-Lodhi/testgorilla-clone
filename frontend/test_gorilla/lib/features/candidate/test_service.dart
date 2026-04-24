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

  /// Start test attempt
  Future<TestAttempt> startAttempt(String testId) async {
    try {
      final response = await apiClient.post(ApiConstants.startAttempt(testId));
      final data = response['data'] as Map<String, dynamic>;
      return TestAttempt.fromJson(data['attempt'] as Map<String, dynamic>);
    } catch (e) {
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
      if (response['data'] is List) {
        return (response['data'] as List)
            .map((a) => TestAttempt.fromJson(a as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}

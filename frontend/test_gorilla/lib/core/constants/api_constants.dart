class ApiConstants {
  static const String baseUrl = 'http://localhost:5000/api/v1';
  
  // Auth endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authProfile = '/auth/me';
  static const String authLogout = '/auth/logout';
  
  // Test endpoints
  static const String tests = '/tests';
  static String testById(String testId) => '/tests/$testId';
  static String publishTest(String testId) => '/tests/$testId/publish';
  static String archiveTest(String testId) => '/tests/$testId/archive';
  
  // Question endpoints
  static String questions(String testId) => '/tests/$testId/questions';
  static String questionById(String testId, String questionId) =>
      '/tests/$testId/questions/$questionId';
  
  // Attempt endpoints
  static String startAttempt(String testId) => '/tests/$testId/attempts';
  static String getAttempt(String attemptId) => '/attempts/$attemptId';
  static String submitResponse(String attemptId) => '/attempts/$attemptId/responses';
  static String submitAttempt(String attemptId) => '/attempts/$attemptId/submit';
  static const String candidateAttempts = '/candidates/attempts';
  static String testAttempts(String testId) => '/tests/$testId/attempts';
  
  // Result endpoints
  static String getResult(String attemptId) => '/results/$attemptId';
  static String getTestResults(String testId) => '/tests/$testId/results';
  static String getTestStatistics(String testId) => '/tests/$testId/results/statistics';
  static String getCandidateResults(String userId) => '/candidates/$userId/results';
  
  // Health check
  static const String health = '/health';
}

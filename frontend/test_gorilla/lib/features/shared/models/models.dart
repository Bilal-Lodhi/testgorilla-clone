import 'dart:convert';

class Test {
  final String id;
  final String title;
  final String? description;
  final int durationMinutes;
  final String status;
  final double passPercentage;
  final int totalQuestions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  Test({
    required this.id,
    required this.title,
    this.description,
    required this.durationMinutes,
    required this.status,
    required this.passPercentage,
    required this.totalQuestions,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory Test.fromJson(Map<String, dynamic> json) {
    double parsePercentage(dynamic value) {
      if (value == null) return 60.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 60.0;
      return 60.0;
    }

    return Test(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      durationMinutes: json['duration_minutes'] ?? 60,
      status: json['status'] ?? 'draft',
      passPercentage: parsePercentage(json['pass_percentage']),
      totalQuestions: json['total_questions'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toString(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toString(),
      ),
      createdBy: json['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'duration_minutes': durationMinutes,
    'status': status,
    'pass_percentage': passPercentage,
    'total_questions': totalQuestions,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'created_by': createdBy,
  };
}

class Question {
  final String id;
  final String testId;
  final String type;
  final String questionText;
  final int marks;
  final int orderIndex;
  final List<Option>? options;

  Question({
    required this.id,
    required this.testId,
    required this.type,
    required this.questionText,
    required this.marks,
    required this.orderIndex,
    this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] ?? '',
      testId: json['test_id'] ?? '',
      type: json['type'] ?? 'mcq',
      questionText: json['question_text'] ?? '',
      marks: json['marks'] ?? 1,
      orderIndex: json['order_index'] ?? 0,
      options: json['options'] != null
          ? List<Option>.from(json['options'].map((o) => Option.fromJson(o)))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'test_id': testId,
    'type': type,
    'question_text': questionText,
    'marks': marks,
    'order_index': orderIndex,
    'options': options?.map((o) => o.toJson()).toList(),
  };
}

class Option {
  final String id;
  final String questionId;
  final String optionText;
  final bool isCorrect;
  final int orderIndex;

  Option({
    required this.id,
    required this.questionId,
    required this.optionText,
    required this.isCorrect,
    required this.orderIndex,
  });

  factory Option.fromJson(Map<String, dynamic> json) {
    final normalizedOptionText = _normalizeOptionText(json['option_text']);

    return Option(
      id: json['id'] ?? '',
      questionId: json['question_id'] ?? '',
      optionText: normalizedOptionText,
      isCorrect: json['is_correct'] ?? false,
      orderIndex: json['order_index'] ?? 0,
    );
  }

  static String _normalizeOptionText(dynamic rawValue) {
    if (rawValue == null) return '';

    if (rawValue is Map<String, dynamic>) {
      return (rawValue['option_text'] ?? rawValue['text'] ?? '').toString();
    }

    final value = rawValue.toString();
    if (value.isEmpty) return value;

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        final nested = decoded['option_text'] ?? decoded['text'];
        if (nested != null) {
          return nested.toString();
        }
      }
    } catch (_) {
      // Fall through to regex extraction or raw value.
    }

    final match = RegExp(
      r'"?option_text"?\s*[:=]\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(value);

    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? value;
    }

    return value;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question_id': questionId,
    'option_text': optionText,
    'is_correct': isCorrect,
    'order_index': orderIndex,
  };
}

class TestAttempt {
  final String id;
  final String testId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final int score;
  final DateTime createdAt;
  final DateTime updatedAt;

  TestAttempt({
    required this.id,
    required this.testId,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.score,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TestAttempt.fromJson(Map<String, dynamic> json) {
    return TestAttempt(
      id: json['id'] ?? '',
      testId: json['test_id'] ?? '',
      userId: json['user_id'] ?? '',
      startTime: DateTime.parse(
        json['start_time'] ?? DateTime.now().toString(),
      ),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'])
          : null,
      status: json['status'] ?? 'in_progress',
      score: json['score'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toString(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'test_id': testId,
    'user_id': userId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'status': status,
    'score': score,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class Result {
  final String id;
  final String attemptId;
  final String testId;
  final String userId;
  final int score;
  final int totalMarks;
  final double percentage;
  final bool isPassed;
  final DateTime createdAt;

  Result({
    required this.id,
    required this.attemptId,
    required this.testId,
    required this.userId,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    required this.isPassed,
    required this.createdAt,
  });

  factory Result.fromJson(Map<String, dynamic> json) {
    return Result(
      id: json['id'] ?? '',
      attemptId: json['attempt_id'] ?? '',
      testId: json['test_id'] ?? '',
      userId: json['user_id'] ?? '',
      score: json['score'] ?? 0,
      totalMarks: json['total_marks'] ?? 100,
      percentage: (json['percentage'] ?? 0).toDouble(),
      isPassed: json['is_passed'] ?? false,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toString(),
      ),
    );
  }
}

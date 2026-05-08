import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;
import 'package:test_gorilla/features/candidate/test_service.dart';

class ResultScreen extends StatefulWidget {
  final String attemptId;

  const ResultScreen({Key? key, required this.attemptId}) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late TestService _testService;
  late Future<Map<String, dynamic>> _resultFuture;

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Color _secondaryTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _testService = TestService(apiClient);
    _resultFuture = _testService.getResult(widget.attemptId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _resultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const app_widgets.LoadingWidget(
              message: 'Loading results...',
            );
          }

          if (snapshot.hasError) {
            return app_widgets.ErrorWidget(
              message: snapshot.error.toString(),
              onRetry: () {
                setState(() {
                  _resultFuture = _testService.getResult(widget.attemptId);
                });
              },
            );
          }

          final data = snapshot.data ?? {};
          final payload = data['data'] as Map<String, dynamic>?;

          if (payload == null) {
            return const app_widgets.EmptyStateWidget(
              title: 'No Result',
              subtitle: 'Result not found',
            );
          }

          final result = payload['result'] as Map<String, dynamic>? ?? {};
          final attempt = payload['attempt'] as Map<String, dynamic>? ?? {};
          final test = payload['test'] as Map<String, dynamic>? ?? {};
          final breakdown = payload['breakdown'] as Map<String, dynamic>? ?? {};
          final responsesRaw = payload['responses'] as List<dynamic>? ?? [];
          final responses = responsesRaw
              .map((r) => r as Map<String, dynamic>)
              .toList();

          final score = _toDouble(
            attempt['score'],
            fallback: _toDouble(result['obtained_marks']),
          );
          final totalMarks = _toDouble(result['total_marks']);
          final percentage = _toDouble(
            result['percentage'],
            fallback: totalMarks > 0 ? (score / totalMarks) * 100 : 0,
          );
          final totalQuestions = _toInt(breakdown['total_questions']);
          final totalMcqQuestions = _toInt(breakdown['total_mcq_questions']);
          final totalCodingQuestions = _toInt(
            breakdown['total_coding_questions'],
          );
          final totalMcqMarks = _toDouble(breakdown['total_mcq_marks']);
          final obtainedMcqMarks = _toDouble(breakdown['obtained_mcq_marks']);
          final correctMcqCount = _toInt(breakdown['correct_mcq_count']);
          final wrongMcqCount = _toInt(breakdown['wrong_mcq_count']);
          final correctCodingCount = _toInt(breakdown['correct_coding_count']);
          final pendingManualCount = _toInt(breakdown['pending_manual_count']);
          final reviewedManualCount = _toInt(
            breakdown['reviewed_manual_count'],
          );

          final isPendingReview = pendingManualCount > 0;
          final displayedScore = isPendingReview ? obtainedMcqMarks : score;
          final displayedTotalMarks = isPendingReview && totalMcqMarks > 0
              ? totalMcqMarks
              : totalMarks;
          final displayedPercentage = isPendingReview
              ? (totalMcqMarks > 0
                    ? (obtainedMcqMarks / totalMcqMarks) * 100
                    : 0)
              : percentage;

          final passPercentage = _toDouble(
            test['pass_percentage'],
            fallback: 60,
          );
          final isPassed = !isPendingReview && percentage >= passPercentage;

          final questionsReviewText = totalQuestions > 0
              ? '$totalMcqQuestions/$totalQuestions'
              : '$totalMcqQuestions';

          // Separate responses by type
          final mcqResponses = responses
              .where((r) => r['type'] == 'mcq')
              .toList();
          final manualResponses = responses
              .where((r) => r['type'] == 'coding' || r['type'] == 'essay')
              .toList();
          final hasManualResponses = manualResponses.isNotEmpty;

          return app_widgets.AppPageScaffold(
            maxContentWidth: 900,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Score summary card
                  app_widgets.GlassPanel(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPendingReview
                                        ? 'Current Score (MCQ Evaluated)'
                                        : 'Final Score',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${displayedPercentage.toStringAsFixed(1)}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(
                                          color: isPendingReview
                                              ? AppTheme.warningColor
                                              : isPassed
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isPendingReview
                                        ? 'MCQ Score ${displayedScore.toStringAsFixed(0)} / ${displayedTotalMarks.toStringAsFixed(0)} marks'
                                        : 'Score ${displayedScore.toStringAsFixed(0)} / ${displayedTotalMarks.toStringAsFixed(0)} marks',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            app_widgets.StatusBadge(
                              label: isPendingReview
                                  ? 'PENDING REVIEW'
                                  : isPassed
                                  ? 'PASS'
                                  : 'FAIL',
                              status: isPendingReview
                                  ? 'pending'
                                  : isPassed
                                  ? 'success'
                                  : 'error',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: (displayedPercentage.clamp(0, 100)) / 100,
                            color: isPendingReview
                                ? AppTheme.warningColor
                                : isPassed
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPendingReview) ...[
                    const SizedBox(height: 14),
                    app_widgets.GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Showing result for $questionsReviewText questions',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'MCQ questions are evaluated immediately. Remaining coding/written questions will be reviewed by admin/teacher later and your result will be updated in test history.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reviewed manual answers: $reviewedManualCount | Pending manual answers: $pendingManualCount',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: _secondaryTextColor(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  // Summary metric cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 700;

                      final summaryCards = [
                        _SummaryMetricCard(
                          title: 'MCQ Correct',
                          value: '$correctMcqCount',
                          color: AppTheme.successColor,
                        ),
                        _SummaryMetricCard(
                          title: 'MCQ Wrong',
                          value: '$wrongMcqCount',
                          color: AppTheme.errorColor,
                        ),
                        _SummaryMetricCard(
                          title: 'Coding Correct',
                          value: '$correctCodingCount / $totalCodingQuestions',
                          color: totalCodingQuestions == 0
                              ? _secondaryTextColor(context)
                              : (correctCodingCount == totalCodingQuestions
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor),
                        ),
                        _SummaryMetricCard(
                          title: isPendingReview
                              ? 'Final Pass Cutoff'
                              : 'Pass Cutoff',
                          value: '${passPercentage.toStringAsFixed(0)}%',
                          color: AppTheme.warningColor,
                        ),
                      ];

                      if (stacked) {
                        return Column(
                          children: summaryCards
                              .map(
                                (card) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: card,
                                ),
                              )
                              .toList(),
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: summaryCards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: summaryCards[1]),
                          const SizedBox(width: 12),
                          Expanded(child: summaryCards[2]),
                          const SizedBox(width: 12),
                          Expanded(child: summaryCards[3]),
                        ],
                      );
                    },
                  ),

                  // ===== Per-Question Review Section =====
                  if (mcqResponses.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text(
                      'MCQ Questions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...mcqResponses.map(
                      (r) => _buildMcqResponseCard(context, r),
                    ),
                  ],

                  if (hasManualResponses) ...[
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Text(
                          'Coding & Written Questions',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        if (pendingManualCount > 0)
                          app_widgets.StatusBadge(
                            label: '$pendingManualCount pending',
                            status: 'pending',
                          ),
                        if (reviewedManualCount > 0) ...[
                          const SizedBox(width: 6),
                          app_widgets.StatusBadge(
                            label: '$reviewedManualCount reviewed',
                            status: 'success',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...manualResponses.map((r) => _buildReviewCard(context, r)),
                  ],

                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text('Back To Home'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build a card for an MCQ response showing correct/incorrect
  Widget _buildMcqResponseCard(
    BuildContext context,
    Map<String, dynamic> response,
  ) {
    final questionText = response['question_text'] ?? 'Unknown question';
    final selectedOptionText =
        response['selected_option_text'] ?? 'No answer submitted';
    final isCorrect = response['is_correct'] == true;
    final marksObtained = _toInt(response['marks_obtained']);
    final maxMarks = _toInt(response['max_marks']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: app_widgets.GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    questionText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppTheme.successColor.withOpacity(0.08)
                    : AppTheme.errorColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect
                      ? AppTheme.successColor.withOpacity(0.3)
                      : AppTheme.errorColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Your answer: $selectedOptionText',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isCorrect
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Marks: $marksObtained / $maxMarks',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _secondaryTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a review card for coding/essay responses showing admin feedback
  Widget _buildReviewCard(BuildContext context, Map<String, dynamic> response) {
    final questionText = response['question_text'] ?? 'Unknown question';
    final type = response['type'] ?? 'coding';
    final codeAnswer = response['code_answer'] ?? '';
    final gradingStatus = response['grading_status'] ?? 'pending_review';
    final marksObtained = _toInt(response['marks_obtained']);
    final maxMarks = _toInt(response['max_marks']);
    final reviewNotes = response['review_notes'] ?? '';
    final reviewedAt = response['reviewed_at'];

    final isReviewed = gradingStatus == 'reviewed';
    final hasReviewNotes =
        reviewNotes is String && reviewNotes.trim().isNotEmpty;
    final hasAnswer = codeAnswer is String && codeAnswer.trim().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Code block colors - always dark-themed like an IDE
    final codeBlockBg = isDark
        ? AppTheme.surfaceMutedDark
        : const Color(0xFF1E293B);
    final codeBlockBorder = isDark
        ? AppTheme.borderDark
        : const Color(0xFF334155);
    final codeTextColor = isDark
        ? AppTheme.onSurfaceDark
        : const Color(0xFFE2E8F0);
    final reviewerFeedbackBg = isDark
        ? AppTheme.surfaceMutedDark
        : const Color(0xFF0F172A);
    final infoAccentColor = AppTheme.accentColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: app_widgets.GlassPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header with type badge and grading status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: type == 'coding'
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : AppTheme.secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type == 'coding' ? 'CODING' : 'ESSAY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: type == 'coding'
                          ? AppTheme.primaryColor
                          : AppTheme.secondaryColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    questionText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                app_widgets.StatusBadge(
                  label: isReviewed ? 'REVIEWED' : 'PENDING',
                  status: isReviewed ? 'success' : 'pending',
                ),
              ],
            ),

            // Candidate's submitted answer
            if (hasAnswer) ...[
              const SizedBox(height: 14),
              Text(
                'Your Answer:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _secondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: codeBlockBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: codeBlockBorder),
                ),
                child: SelectableText(
                  codeAnswer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: codeTextColor,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'No answer submitted',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: _secondaryTextColor(context),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Marks awarded
            Row(
              children: [
                Icon(Icons.grade, size: 18, color: AppTheme.warningColor),
                const SizedBox(width: 6),
                Text(
                  isReviewed
                      ? 'Marks: $marksObtained / $maxMarks'
                      : 'Max Marks: $maxMarks (not yet graded)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _secondaryTextColor(context),
                  ),
                ),
              ],
            ),

            // Admin Review Notes
            if (isReviewed && hasReviewNotes) ...[
              const SizedBox(height: 14),
              Divider(color: Theme.of(context).dividerColor),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 18,
                    color: infoAccentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reviewer Feedback:',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: infoAccentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: reviewerFeedbackBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: infoAccentColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewNotes,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppTheme.onSurfaceDark
                            : const Color(0xFFCBD5E1),
                        height: 1.6,
                      ),
                    ),
                    if (reviewedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reviewed on ${_formatDateTime(reviewedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _secondaryTextColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // No review notes message
            if (isReviewed && !hasReviewNotes) ...[
              const SizedBox(height: 14),
              Divider(color: Theme.of(context).dividerColor),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: _secondaryTextColor(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reviewed with no additional feedback notes.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ],

            // Pending review message
            if (!isReviewed) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warningColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This answer is awaiting review by an admin/teacher. Your score will be updated once reviewed.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'Unknown date';
    try {
      final dt = DateTime.parse(dateTime.toString());
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime.toString();
    }
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryMetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return app_widgets.GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

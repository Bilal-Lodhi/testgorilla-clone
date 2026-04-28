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
        automaticallyImplyLeading: false,
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

          return app_widgets.AppPageScaffold(
            maxContentWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                  style: Theme.of(context).textTheme.bodyMedium,
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
                          backgroundColor: const Color(0xFFE2E8F0),
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
                              ?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
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
                            ? const Color(0xFF64748B)
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
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Back To Home'),
                ),
              ],
            ),
          );
        },
      ),
    );
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
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

// ignore_for_file: unnecessary_cast

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/features/auth/auth_provider.dart';
import 'package:test_gorilla/features/candidate/test_list_screen.dart';
import 'package:test_gorilla/features/candidate/test_service.dart';
import 'package:test_gorilla/features/shared/models/models.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;

class CandidateDashboardShell extends StatefulWidget {
  const CandidateDashboardShell({Key? key}) : super(key: key);

  @override
  State<CandidateDashboardShell> createState() =>
      _CandidateDashboardShellState();
}

class _CandidateDashboardShellState extends State<CandidateDashboardShell> {
  late TestService _testService;
  late Future<List<_CandidateAttemptSummary>> _historyFuture;
  String? _selectedAttemptId;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _testService = TestService(apiClient);
    _historyFuture = _loadHistory();
  }

  Future<List<_CandidateAttemptSummary>> _loadHistory() async {
    final attempts = await _testService.getCandidateAttempts();
    final summaries = await Future.wait(attempts.map(_buildSummaryForAttempt));

    summaries.sort((left, right) {
      return right.attempt.createdAt.compareTo(left.attempt.createdAt);
    });

    return summaries;
  }

  Future<_CandidateAttemptSummary> _buildSummaryForAttempt(
    TestAttempt attempt,
  ) async {
    final normalizedStatus = attempt.status.toLowerCase();

    if (normalizedStatus == 'in_progress' ||
        normalizedStatus == 'ongoing' ||
        normalizedStatus == 'draft') {
      return _CandidateAttemptSummary(
        attempt: attempt,
        testTitle: 'Test ${attempt.testId}',
        statusLabel: _formatStatusLabel(attempt.status),
        completedAt: attempt.endTime ?? attempt.updatedAt,
      );
    }

    try {
      final response = await _testService.getResult(attempt.id);
      final data = response['data'];
      var payload = data is Map ? data : response;

      final resultPayload = _valueForKey(payload, 'result');
      final testPayload = _valueForKey(payload, 'test');
      final result = _asStringMap(resultPayload);
      final test = _asStringMap(testPayload);

      final percentage = _toDouble(
        result['percentage'],
        fallback: _toDouble(result['obtained_marks']),
      );
      final passPercentage = _toDouble(test['pass_percentage'], fallback: 60);
      final isPassed = result['is_passed'] is bool
          ? result['is_passed'] as bool
          : percentage >= passPercentage;

      return _CandidateAttemptSummary(
        attempt: attempt,
        testTitle: test['title']?.toString() ?? 'Test ${attempt.testId}',
        statusLabel: isPassed ? 'Passed' : 'Failed',
        percentage: percentage,
        totalMarks: _toDouble(result['total_marks']),
        correctCount: _toInt(result['correct_count']),
        wrongCount: _toInt(result['wrong_count']),
        isPassed: isPassed,
        completedAt: _parseDateTime(
          result['created_at']?.toString() ??
              attempt.endTime?.toIso8601String(),
        ),
      );
    } catch (_) {
      return _CandidateAttemptSummary(
        attempt: attempt,
        testTitle: 'Test ${attempt.testId}',
        statusLabel: _formatStatusLabel(attempt.status),
        completedAt: attempt.endTime ?? attempt.updatedAt,
      );
    }
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  dynamic _valueForKey(Map payload, String key) {
    for (final entry in payload.entries) {
      if (entry.key == key) {
        return entry.value;
      }
    }

    return null;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String _formatStatusLabel(String value) {
    switch (value.toLowerCase()) {
      case 'in_progress':
        return 'In progress';
      case 'submitted':
        return 'Submitted';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'passed':
        return 'Passed';
      default:
        return value.isEmpty ? 'Unknown' : value;
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Unknown';
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  void _openResult(String attemptId) {
    Navigator.of(context).pushNamed('/candidate/result', arguments: attemptId);
  }

  void _showLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.of(context).size.width >= 900;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final candidateName =
            authProvider.userData?['name']?.toString().trim() ?? '';
        final welcomeTitle = candidateName.isEmpty
            ? 'Welcome'
            : 'Welcome, $candidateName';

        return Scaffold(
          appBar: AppBar(
            title: Text(welcomeTitle),
            elevation: 0,
            leading: isWideLayout
                ? null
                : Builder(
                    builder: (drawerContext) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(drawerContext).openDrawer(),
                      tooltip: 'Open history',
                    ),
                  ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _showLogout(context),
                tooltip: 'Logout',
              ),
            ],
          ),
          drawer: isWideLayout
              ? null
              : Drawer(
                  child: SafeArea(
                    child: _HistorySidebar(
                      historyFuture: _historyFuture,
                      selectedAttemptId: _selectedAttemptId,
                      onSelectAttempt: (attemptId) {
                        setState(() {
                          _selectedAttemptId = attemptId;
                        });
                      },
                      onOpenResult: _openResult,
                      formatDateTime: _formatDateTime,
                    ),
                  ),
                ),
          body: SafeArea(
            child: isWideLayout
                ? Row(
                    children: [
                      SizedBox(
                        width: 360,
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: _HistorySidebar(
                            historyFuture: _historyFuture,
                            selectedAttemptId: _selectedAttemptId,
                            onSelectAttempt: (attemptId) {
                              setState(() {
                                _selectedAttemptId = attemptId;
                              });
                            },
                            onOpenResult: _openResult,
                            formatDateTime: _formatDateTime,
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: TestListScreen(embedded: true),
                        ),
                      ),
                    ],
                  )
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: TestListScreen(embedded: true),
                  ),
          ),
        );
      },
    );
  }
}

class _HistorySidebar extends StatelessWidget {
  final Future<List<_CandidateAttemptSummary>> historyFuture;
  final String? selectedAttemptId;
  final ValueChanged<String> onSelectAttempt;
  final ValueChanged<String> onOpenResult;
  final String Function(DateTime? value) formatDateTime;

  const _HistorySidebar({
    required this.historyFuture,
    required this.selectedAttemptId,
    required this.onSelectAttempt,
    required this.onOpenResult,
    required this.formatDateTime,
  });

  Color _statusColor(_CandidateAttemptSummary summary, BuildContext context) {
    if (summary.isPassed == true) return Colors.green;
    if (summary.isPassed == false) return Colors.red;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_CandidateAttemptSummary>>(
      future: historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const app_widgets.LoadingWidget(message: 'Loading history...');
        }

        if (snapshot.hasError) {
          return app_widgets.ErrorWidget(
            message: snapshot.error.toString(),
            onRetry: null,
          );
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return const app_widgets.EmptyStateWidget(
            title: 'No Test History',
            subtitle: 'Your submitted attempts will appear here.',
            icon: Icons.history_outlined,
          );
        }

        final selectedAttempt = selectedAttemptId == null
            ? history.first
            : history.firstWhere(
                (item) => item.attempt.id == selectedAttemptId,
                orElse: () => history.first,
              );

        final totalAttempts = history.length;
        final completedAttempts = history
            .where((item) => item.isCompleted)
            .length;
        final passedAttempts = history
            .where((item) => item.isPassed == true)
            .length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Test History', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Track recent attempts and open the detailed result view.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _statusColor(
                            selectedAttempt,
                            context,
                          ).withOpacity(0.12),
                          child: Icon(
                            selectedAttempt.isCompleted
                                ? (selectedAttempt.isPassed == true
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined)
                                : Icons.pending_outlined,
                            color: _statusColor(selectedAttempt, context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedAttempt.testTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedAttempt.statusLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatPill(label: 'Attempts', value: '$totalAttempts'),
                        _StatPill(
                          label: 'Completed',
                          value: '$completedAttempts',
                        ),
                        _StatPill(label: 'Passed', value: '$passedAttempts'),
                      ],
                    ),
                    if (selectedAttempt.isCompleted) ...[
                      const SizedBox(height: 16),
                      _DetailRow(
                        label: 'Score',
                        value: selectedAttempt.scoreText,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        label: 'Result',
                        value: selectedAttempt.resultText,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        label: 'Submitted',
                        value: formatDateTime(selectedAttempt.completedAt),
                      ),
                      if (selectedAttempt.correctCount != null ||
                          selectedAttempt.wrongCount != null) ...[
                        const SizedBox(height: 8),
                        _DetailRow(
                          label: 'Answers',
                          value:
                              '${selectedAttempt.correctCount ?? 0} correct / ${selectedAttempt.wrongCount ?? 0} wrong',
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              onOpenResult(selectedAttempt.attempt.id),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open Result'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...history.map((item) {
              final isSelected =
                  item.attempt.id == selectedAttemptId ||
                  (selectedAttemptId == null &&
                      identical(item, selectedAttempt));
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => onSelectAttempt(item.attempt.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Card(
                    elevation: isSelected ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.testTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    item,
                                    context,
                                  ).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.statusLabel,
                                  style: TextStyle(
                                    color: _statusColor(item, context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.isCompleted
                                ? item.resultText
                                : 'Started ${formatDateTime(item.attempt.startTime)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.isCompleted
                                ? 'Submitted ${formatDateTime(item.completedAt)}'
                                : 'In progress',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _CandidateAttemptSummary {
  final TestAttempt attempt;
  final String testTitle;
  final String statusLabel;
  final double? percentage;
  final double? totalMarks;
  final int? correctCount;
  final int? wrongCount;
  final bool? isPassed;
  final DateTime? completedAt;

  const _CandidateAttemptSummary({
    required this.attempt,
    required this.testTitle,
    required this.statusLabel,
    this.percentage,
    this.totalMarks,
    this.correctCount,
    this.wrongCount,
    this.isPassed,
    this.completedAt,
  });

  bool get isCompleted => isPassed != null || percentage != null;

  String get resultText {
    if (percentage == null) {
      return 'Result pending';
    }

    final score = percentage!.toStringAsFixed(1);
    final markText = totalMarks == null
        ? ''
        : ' / ${totalMarks!.toStringAsFixed(0)}';
    return '$score%$markText';
  }

  String get scoreText {
    if (percentage == null) {
      return 'Pending';
    }

    return '${percentage!.toStringAsFixed(1)}%';
  }
}

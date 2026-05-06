// ignore_for_file: unnecessary_cast

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/storage/attempt_storage.dart';
import 'package:test_gorilla/core/storage/access_code_storage.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';
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
  bool _isHistoryPanelExpanded = false;

  /// Active attempt available for resume
  Map<String, dynamic>? _resumableAttempt;
  bool _isCheckingResume = true;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _testService = TestService(apiClient);
    _refreshHistory(resetSelection: true);
    unawaited(_checkForResumableAttempt());
  }

  void _refreshHistory({bool resetSelection = false}) {
    setState(() {
      if (resetSelection) {
        _selectedAttemptId = null;
      }
      _historyFuture = _loadHistory();
    });
  }

  /// Check for an in_progress attempt. Store it in state so the UI can show
  /// a Resume button rather than auto-redirecting.
  Future<void> _checkForResumableAttempt() async {
    try {
      final attemptId = await AttemptStorage.getAttemptId();
      if (attemptId == null) {
        if (mounted) setState(() => _isCheckingResume = false);
        return;
      }

      final data = await _testService.getAttempt(attemptId);
      final attempt = data['attempt'] as Map<String, dynamic>?;

      if (attempt == null) {
        await AttemptStorage.clear();
        if (mounted) setState(() => _isCheckingResume = false);
        return;
      }

      final status = (attempt['status'] as String?) ?? '';

      if (status == 'in_progress') {
        // Valid resume target — store for UI
        if (mounted) {
          setState(() {
            _resumableAttempt = data;
            _isCheckingResume = false;
          });
        }
      } else {
        // Submitted, expired, or otherwise done — clear
        await AttemptStorage.clear();
        if (mounted) setState(() => _isCheckingResume = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingResume = false);
      // Keep storage for later retry
    }
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
        testTitle: attempt.testTitle?.trim().isNotEmpty == true
            ? attempt.testTitle!.trim()
            : 'Test ${attempt.testId}',
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
      final breakdownPayload = _valueForKey(payload, 'breakdown');
      final result = _asStringMap(resultPayload);
      final test = _asStringMap(testPayload);
      final breakdown = _asStringMap(breakdownPayload);

      final percentage = _toDouble(
        result['percentage'],
        fallback: _toDouble(result['obtained_marks']),
      );
      final passPercentage = _toDouble(test['pass_percentage'], fallback: 60);
      final pendingManualCount = _toInt(breakdown['pending_manual_count']) ?? 0;
      final totalMcqQuestions = _toInt(breakdown['total_mcq_questions']) ?? 0;
      final totalQuestions = _toInt(breakdown['total_questions']) ?? 0;
      final totalMcqMarks = _toDouble(breakdown['total_mcq_marks']);
      final obtainedMcqMarks = _toDouble(breakdown['obtained_mcq_marks']);
      final hasPendingReview = pendingManualCount > 0;

      final double displayedPercentage = hasPendingReview
          ? (totalMcqMarks > 0 ? (obtainedMcqMarks / totalMcqMarks) * 100 : 0)
          : percentage;

      final isPassed = hasPendingReview
          ? null
          : (result['is_passed'] is bool
                ? result['is_passed'] as bool
                : percentage >= passPercentage);

      return _CandidateAttemptSummary(
        attempt: attempt,
        testTitle:
            test['title']?.toString() ??
            attempt.testTitle?.toString() ??
            'Test ${attempt.testId}',
        statusLabel: hasPendingReview
            ? 'Pending Review'
            : (isPassed == true ? 'Passed' : 'Failed'),
        percentage: displayedPercentage,
        totalMarks: hasPendingReview
            ? totalMcqMarks
            : _toDouble(result['total_marks']),
        correctCount: _toInt(breakdown['correct_mcq_count']),
        wrongCount: _toInt(breakdown['wrong_mcq_count']),
        isPassed: isPassed,
        hasPendingReview: hasPendingReview,
        pendingManualCount: pendingManualCount,
        totalMcqQuestions: totalMcqQuestions,
        totalQuestions: totalQuestions,
        completedAt: _parseDateTime(
          result['created_at']?.toString() ??
              attempt.endTime?.toIso8601String(),
        ),
      );
    } catch (_) {
      return _CandidateAttemptSummary(
        attempt: attempt,
        testTitle: attempt.testTitle?.trim().isNotEmpty == true
            ? attempt.testTitle!.trim()
            : 'Test ${attempt.testId}',
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

  /// Build a "Resume Test" banner shown when an active attempt exists
  Widget _buildResumeBanner() {
    if (_isCheckingResume || _resumableAttempt == null) {
      return const SizedBox.shrink();
    }

    final attempt = _resumableAttempt!['attempt'] as Map<String, dynamic>?;
    final testTitle =
        (attempt?['test_title'] as String?) ??
        _resumableAttempt!['test_title'] as String? ??
        'Test';

    // Calculate remaining time
    String remainingText = '';
    final startTimeStr =
        _resumableAttempt!['start_time'] as String? ??
        attempt?['start_time'] as String?;
    final durationMinutes =
        _resumableAttempt!['duration'] as int? ??
        attempt?['duration_minutes'] as int? ??
        60;

    if (startTimeStr != null) {
      final startTime = DateTime.tryParse(startTimeStr)?.toUtc();
      if (startTime != null) {
        final endTime = startTime.add(Duration(minutes: durationMinutes));
        final remaining = endTime.difference(DateTime.now().toUtc());
        if (remaining.inSeconds > 0) {
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          remainingText =
              '${mins}m ${secs.toString().padLeft(2, '0')}s remaining';
        } else {
          remainingText = 'Time expired';
        }
      }
    }

    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.play_circle_filled, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have an active test in progress',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    testTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  if (remainingText.isNotEmpty)
                    Text(
                      remainingText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _resumeTest,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Resume'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to attempt screen with resume data
  Future<void> _resumeTest() async {
    if (_resumableAttempt == null) return;

    final data = _resumableAttempt!;
    final attempt = data['attempt'] as Map<String, dynamic>?;
    if (attempt == null) return;

    final attemptId = attempt['id'] as String?;
    final testId = attempt['test_id'] as String?;
    if (attemptId == null || testId == null) return;

    final accessCode = await AccessCodeStorage.getCode(testId) ?? '';

    final now = DateTime.now();
    final durationMinutes =
        data['duration'] as int? ?? attempt['duration_minutes'] as int? ?? 60;

    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      '/candidate/attempt',
      arguments: {
        'test': Test(
          id: testId,
          title:
              (attempt['test_title'] as String?) ??
              data['test_title'] as String? ??
              'Test',
          durationMinutes: durationMinutes,
          status: 'active',
          passPercentage: 60.0,
          totalQuestions: 0,
          createdAt: now,
          updatedAt: now,
          createdBy: '',
        ),
        'accessCode': accessCode,
        'resumeAttemptId': attemptId,
      },
    );

    // Re-check state after returning (attempt may have been submitted)
    if (mounted) {
      setState(() {
        _resumableAttempt = null;
        _isCheckingResume = true;
      });
      unawaited(_checkForResumableAttempt());
      _refreshHistory();
    }
  }

  Future<void> _openResult(String attemptId) async {
    await Navigator.of(
      context,
    ).pushNamed('/candidate/result', arguments: attemptId);
    if (mounted) {
      _refreshHistory();
    }
  }

  void _toggleHistoryPanel() {
    setState(() {
      _isHistoryPanelExpanded = !_isHistoryPanelExpanded;
    });
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

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          '⚠️ WARNING: This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await context.read<ApiClient>().delete('/auth/account');
                if (context.mounted) {
                  await context.read<AuthProvider>().logout();
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Delete Account'),
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
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _showDeleteAccountDialog(context),
                tooltip: 'Delete Account',
              ),
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
                      onRefresh: _refreshHistory,
                      formatDateTime: _formatDateTime,
                      onCollapse: () => Navigator.of(context).pop(),
                      showCollapseButton: true,
                    ),
                  ),
                ),
          body: SafeArea(
            child: isWideLayout
                ? Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: _isHistoryPanelExpanded ? 360 : 72,
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: _isHistoryPanelExpanded
                              ? _HistorySidebar(
                                  historyFuture: _historyFuture,
                                  selectedAttemptId: _selectedAttemptId,
                                  onSelectAttempt: (attemptId) {
                                    setState(() {
                                      _selectedAttemptId = attemptId;
                                    });
                                  },
                                  onOpenResult: _openResult,
                                  onRefresh: _refreshHistory,
                                  formatDateTime: _formatDateTime,
                                  onCollapse: _toggleHistoryPanel,
                                  showCollapseButton: true,
                                )
                              : _CollapsedHistoryRail(
                                  historyFuture: _historyFuture,
                                  onExpand: _toggleHistoryPanel,
                                  onRefresh: _refreshHistory,
                                ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _buildResumeBanner(),
                              Expanded(
                                child: TestListScreen(
                                  embedded: true,
                                  onAttemptFlowCompleted: () =>
                                      _refreshHistory(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildResumeBanner(),
                        Expanded(
                          child: TestListScreen(
                            embedded: true,
                            onAttemptFlowCompleted: () => _refreshHistory(),
                          ),
                        ),
                      ],
                    ),
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
  final Future<void> Function(String) onOpenResult;
  final void Function({bool resetSelection}) onRefresh;
  final String Function(DateTime? value) formatDateTime;
  final VoidCallback? onCollapse;
  final bool showCollapseButton;

  const _HistorySidebar({
    required this.historyFuture,
    required this.selectedAttemptId,
    required this.onSelectAttempt,
    required this.onOpenResult,
    required this.onRefresh,
    required this.formatDateTime,
    this.onCollapse,
    this.showCollapseButton = false,
  });

  Color _statusColor(_CandidateAttemptSummary summary, BuildContext context) {
    if (summary.hasPendingReview) return AppTheme.warningColor;
    if (summary.isPassed == true) return Colors.green;
    if (summary.isPassed == false) return Colors.red;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_CandidateAttemptSummary>>(
      future: historyFuture,
      builder: (context, snapshot) {
        final history = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;

        // Build header that's always visible
        final header = LayoutBuilder(
          builder: (context, constraints) {
            final actions = <Widget>[
              IconButton(
                onPressed: () => onRefresh(),
                tooltip: 'Refresh history',
                icon: const Icon(Icons.refresh),
              ),
              if (showCollapseButton)
                IconButton(
                  onPressed: onCollapse,
                  tooltip: 'Collapse history panel',
                  icon: const Icon(Icons.keyboard_double_arrow_left),
                ),
            ];

            if (constraints.maxWidth < 280) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test History',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Wrap(spacing: 4, runSpacing: 4, children: actions),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Test History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ...actions,
              ],
            );
          },
        );

        // Build content based on state
        Widget content;
        if (isLoading) {
          content = const app_widgets.LoadingWidget(
            message: 'Loading history...',
          );
        } else if (hasError) {
          content = app_widgets.ErrorWidget(
            message: snapshot.error.toString(),
            onRetry: () => onRefresh(),
          );
        } else if (history.isEmpty) {
          content = const app_widgets.EmptyStateWidget(
            title: 'No Test History',
            subtitle: 'Your submitted attempts will appear here.',
            icon: Icons.history_outlined,
          );
        } else {
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

          content = _buildHistoryContent(
            context,
            history,
            selectedAttempt,
            totalAttempts,
            completedAttempts,
            passedAttempts,
          );
        }

        return Column(
          children: [
            Padding(padding: const EdgeInsets.all(16), child: header),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: content,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryContent(
    BuildContext context,
    List<_CandidateAttemptSummary> history,
    _CandidateAttemptSummary selectedAttempt,
    int totalAttempts,
    int completedAttempts,
    int passedAttempts,
  ) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
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
                    _StatPill(label: 'Completed', value: '$completedAttempts'),
                    _StatPill(label: 'Passed', value: '$passedAttempts'),
                  ],
                ),
                if (selectedAttempt.isCompleted) ...[
                  const SizedBox(height: 16),
                  _DetailRow(label: 'Score', value: selectedAttempt.scoreText),
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: 'Result',
                    value: selectedAttempt.resultText,
                  ),
                  if (selectedAttempt.hasPendingReview) ...[
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Review Progress',
                      value:
                          '${selectedAttempt.totalMcqQuestions}/${selectedAttempt.totalQuestions} questions evaluated',
                    ),
                  ],
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
                      onPressed: () => onOpenResult(selectedAttempt.attempt.id),
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
              (selectedAttemptId == null && identical(item, selectedAttempt));
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox.shrink(),
        ),
      ],
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

class _CollapsedHistoryRail extends StatelessWidget {
  final Future<List<_CandidateAttemptSummary>> historyFuture;
  final VoidCallback onExpand;
  final void Function({bool resetSelection}) onRefresh;

  const _CollapsedHistoryRail({
    required this.historyFuture,
    required this.onExpand,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_CandidateAttemptSummary>>(
      future: historyFuture,
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              IconButton(
                onPressed: onExpand,
                tooltip: 'Expand history panel',
                icon: const Icon(Icons.keyboard_double_arrow_right),
              ),
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.12),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'History',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => onRefresh(),
                tooltip: 'Refresh history',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      },
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
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
  final bool hasPendingReview;
  final int pendingManualCount;
  final int totalMcqQuestions;
  final int totalQuestions;
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
    this.hasPendingReview = false,
    this.pendingManualCount = 0,
    this.totalMcqQuestions = 0,
    this.totalQuestions = 0,
    this.completedAt,
  });

  bool get isCompleted => isPassed != null || percentage != null;

  String get resultText {
    if (hasPendingReview) {
      return 'MCQ evaluated ($totalMcqQuestions/$totalQuestions). Pending manual review for $pendingManualCount question(s).';
    }

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
    if (hasPendingReview && percentage != null) {
      return 'MCQ ${percentage!.toStringAsFixed(1)}%';
    }

    if (percentage == null) {
      return 'Pending';
    }

    return '${percentage!.toStringAsFixed(1)}%';
  }
}

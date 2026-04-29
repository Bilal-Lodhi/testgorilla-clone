import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';
import 'package:test_gorilla/features/auth/auth_provider.dart';
import 'package:test_gorilla/features/shared/models/models.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late ApiClient _apiClient;
  late Future<List<Test>> _testsFuture;
  late Future<Map<String, dynamic>> _pendingEvaluationsFuture;
  bool _sidebarExpanded = true;
  int _currentTab = 0; // 0: Tests, 1: Analytics, 2: Pending Evaluations
  int _pendingResponsesCount = 0;

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<ApiClient>();
    _loadTests();
    _loadPendingEvaluations();
  }

  void _loadTests() {
    _testsFuture = _getTests();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  void _loadPendingEvaluations() {
    _pendingEvaluationsFuture = _getPendingEvaluations();
  }

  Future<Map<String, dynamic>> _getPendingEvaluations() async {
    final response = await _apiClient.get(ApiConstants.pendingEvaluations);
    final data = _asMap(response['data']);
    final summary = _asMap(data['summary']);
    final pendingCount = _asInt(summary['responses']);

    if (mounted && pendingCount != _pendingResponsesCount) {
      setState(() {
        _pendingResponsesCount = pendingCount;
      });
    } else {
      _pendingResponsesCount = pendingCount;
    }

    return data;
  }

  Future<void> _reviewResponse({
    required String attemptId,
    required String responseId,
    required int maxMarks,
  }) async {
    final marksController = TextEditingController();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Evaluate Answer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign marks (0 to $maxMarks)'),
              const SizedBox(height: 8),
              TextField(
                controller: marksController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter awarded marks',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Review Notes (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Explain the grading decision...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit Evaluation'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final marksValue = double.tryParse(marksController.text.trim());
    if (marksValue == null || marksValue < 0 || marksValue > maxMarks) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marks must be between 0 and $maxMarks'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await _apiClient.patch(
      ApiConstants.reviewResponse(attemptId, responseId),
      body: {
        'marksObtained': marksValue,
        if (notesController.text.trim().isNotEmpty)
          'reviewNotes': notesController.text.trim(),
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evaluation submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _loadPendingEvaluations();
      });
    }
  }

  Widget _buildPendingEvaluationsContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _pendingEvaluationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const app_widgets.LoadingWidget(
            message: 'Loading pending evaluations...',
          );
        }

        if (snapshot.hasError) {
          return app_widgets.ErrorWidget(
            message: snapshot.error.toString(),
            onRetry: () {
              setState(() {
                _loadPendingEvaluations();
              });
            },
          );
        }

        final data = snapshot.data ?? {};
        final pendingEvaluationsRaw = data['pendingEvaluations'];
        final pendingEvaluations = pendingEvaluationsRaw is List
            ? pendingEvaluationsRaw.map((item) => _asMap(item)).toList()
            : <Map<String, dynamic>>[];

        if (pendingEvaluations.isEmpty) {
          return const app_widgets.EmptyStateWidget(
            title: 'No Pending Evaluations',
            subtitle: 'All coding/written answers have been reviewed.',
            icon: Icons.fact_check_outlined,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            app_widgets.GlassPanel(
              child: Row(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pending Evaluations (${pendingEvaluations.length} attempts)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _loadPendingEvaluations();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...pendingEvaluations.map((attempt) {
              final responsesRaw = attempt['pendingResponses'];
              final responses = responsesRaw is List
                  ? responsesRaw.map((item) => _asMap(item)).toList()
                  : <Map<String, dynamic>>[];

              final submittedAt =
                  attempt['submittedAt']?.toString() ?? 'Unknown';

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: app_widgets.GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attempt['testTitle']?.toString() ?? 'Untitled Test',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Candidate: ${attempt['candidateName'] ?? 'Unknown'} (${attempt['candidateEmail'] ?? 'N/A'})',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Submitted at: $submittedAt | Pending answers: ${attempt['pendingCount'] ?? responses.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...responses.map((response) {
                        final questionMarks = _asInt(response['questionMarks']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      response['questionText']?.toString() ??
                                          'Question',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  app_widgets.StatusBadge(
                                    label:
                                        '${response['questionType'] ?? 'coding'} | $questionMarks marks',
                                    status: 'pending',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: SelectableText(
                                  response['answer']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? response['answer'].toString()
                                      : 'No answer submitted',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () => _reviewResponse(
                                    attemptId: attempt['attemptId'].toString(),
                                    responseId: response['responseId']
                                        .toString(),
                                    maxMarks: questionMarks,
                                  ),
                                  icon: const Icon(Icons.task_alt),
                                  label: const Text('Evaluate'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<List<Test>> _getTests() async {
    try {
      final response = await _apiClient.get(ApiConstants.tests);
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

  Future<void> _publishTest(Test test) async {
    if (test.totalQuestions < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add at least 1 question before publishing this test.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await _apiClient.patch(ApiConstants.publishTest(test.id));
    if (mounted) {
      setState(() => _loadTests());
    }
  }

  Future<void> _archiveTest(String testId) async {
    await _apiClient.patch(ApiConstants.archiveTest(testId));
    if (mounted) {
      setState(() => _loadTests());
    }
  }

  Future<void> _deleteTest(String testId, String testTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Test'),
          content: SingleChildScrollView(
            child: Text(
              'Are you sure you want to delete "$testTitle"? This action cannot be undone.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _apiClient.delete(ApiConstants.testById(testId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _loadTests());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete test: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _createTest() async {
    final result = await Navigator.of(context).pushNamed('/admin/create-test');
    if (result == true && mounted) {
      setState(() => _loadTests());
    }
  }

  void _openAddQuestions(String testId) async {
    final result = await Navigator.of(
      context,
    ).pushNamed('/admin/add-questions', arguments: testId);
    // Refresh after returning so the test card reflects any new question count.
    if (mounted) {
      if (result == true) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (mounted) {
        setState(() => _loadTests());
      }
    }
  }

  void _showLogoutDialog() {
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
              if (mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
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
                await _apiClient.delete('/auth/account');
                if (mounted) {
                  await context.read<AuthProvider>().logout();
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                if (mounted) {
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

  Widget _buildMobileContent(List<Test> tests, int gridCount) {
    final testsView = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCount,
        childAspectRatio: gridCount == 1 ? 1.55 : 1.28,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final test = tests[index];
        return app_widgets.TestCard(
          title: test.title,
          description: test.description,
          duration: test.durationMinutes,
          questions: test.totalQuestions,
          status: test.status,
          onTap: () => _openAddQuestions(test.id),
          actionLabel: test.status == 'draft'
              ? 'Publish'
              : test.status == 'published'
              ? 'Archive'
              : test.status == 'archived'
              ? 'Republish'
              : null,
          onAction: test.status == 'draft'
              ? () async {
                  await _publishTest(test);
                }
              : test.status == 'published'
              ? () async {
                  await _archiveTest(test.id);
                }
              : test.status == 'archived'
              ? () async {
                  await _publishTest(test);
                }
              : null,
          destructiveActionLabel: 'Delete',
          onDestructiveAction: () async {
            await _deleteTest(test.id, test.title);
          },
        );
      },
    );

    return app_widgets.AppPageScaffold(
      maxContentWidth: 1120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          app_widgets.GlassPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTab == 0
                            ? 'Test Workspace'
                            : _currentTab == 2
                            ? 'Pending Evaluations'
                            : 'Analytics Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentTab == 0
                            ? 'Manage, publish, and organize your assessments in one place.'
                            : _currentTab == 2
                            ? 'Review coding/written answers waiting for manual evaluation.'
                            : 'View detailed analytics and statistics.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (_currentTab == 0)
                  ElevatedButton.icon(
                    onPressed: _createTest,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Test'),
                  )
                else if (_currentTab == 2)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _loadPendingEvaluations();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Reviews'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_currentTab == 0) ...[
            Row(
              children: [
                Text(
                  'Created Tests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 10),
                app_widgets.StatusBadge(
                  label: '${tests.length} TOTAL',
                  status: 'published',
                ),
              ],
            ),
            const SizedBox(height: 16),
            testsView,
          ] else if (_currentTab == 2) ...[
            _buildPendingEvaluationsContent(),
          ] else ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Analytics Coming Soon',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detailed analytics and test statistics will be available soon.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopContent(List<Test> tests, int gridCount) {
    final testsView = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCount,
        childAspectRatio: 1.35,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final test = tests[index];
        return app_widgets.TestCard(
          title: test.title,
          description: test.description,
          duration: test.durationMinutes,
          questions: test.totalQuestions,
          status: test.status,
          onTap: () => _openAddQuestions(test.id),
          actionLabel: test.status == 'draft'
              ? 'Publish'
              : test.status == 'published'
              ? 'Archive'
              : test.status == 'archived'
              ? 'Republish'
              : null,
          onAction: test.status == 'draft'
              ? () async {
                  await _publishTest(test);
                }
              : test.status == 'published'
              ? () async {
                  await _archiveTest(test.id);
                }
              : test.status == 'archived'
              ? () async {
                  await _publishTest(test);
                }
              : null,
          destructiveActionLabel: 'Delete',
          onDestructiveAction: () async {
            await _deleteTest(test.id, test.title);
          },
        );
      },
    );

    final dashboardBody = app_widgets.AppPageScaffold(
      maxContentWidth: 1120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          app_widgets.GlassPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTab == 0
                            ? 'Test Workspace'
                            : _currentTab == 2
                            ? 'Pending Evaluations'
                            : 'Analytics Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentTab == 0
                            ? 'Manage, publish, and organize your assessments in one place.'
                            : _currentTab == 2
                            ? 'Review coding/written answers waiting for manual evaluation.'
                            : 'View detailed analytics and statistics.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (_currentTab == 0)
                  ElevatedButton.icon(
                    onPressed: _createTest,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Test'),
                  )
                else if (_currentTab == 2)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _loadPendingEvaluations();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Reviews'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_currentTab == 0) ...[
            Row(
              children: [
                Text(
                  'Created Tests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 10),
                app_widgets.StatusBadge(
                  label: '${tests.length} TOTAL',
                  status: 'published',
                ),
              ],
            ),
            const SizedBox(height: 16),
            testsView,
          ] else if (_currentTab == 2) ...[
            _buildPendingEvaluationsContent(),
          ] else ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Analytics Coming Soon',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detailed analytics and test statistics will be available soon.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return Row(
      children: [
        Container(
          width: _sidebarExpanded ? 250 : 80,
          decoration: const BoxDecoration(color: Color(0xFF0F172A)),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(_sidebarExpanded ? 20 : 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_sidebarExpanded)
                        Text(
                          'Test Gorilla',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      IconButton(
                        icon: Icon(
                          _sidebarExpanded
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _sidebarExpanded = !_sidebarExpanded;
                          });
                        },
                        tooltip: _sidebarExpanded ? 'Collapse' : 'Expand',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _sidebarExpanded ? 12 : 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SidebarItem(
                            icon: Icons.dashboard_outlined,
                            label: 'Dashboard',
                            selected: _currentTab == 0,
                            expanded: _sidebarExpanded,
                            onTap: () {
                              setState(() => _currentTab = 0);
                            },
                          ),
                          const SizedBox(height: 10),
                          _SidebarItem(
                            icon: Icons.analytics_outlined,
                            label: 'Analytics',
                            selected: _currentTab == 1,
                            expanded: _sidebarExpanded,
                            onTap: () {
                              setState(() => _currentTab = 1);
                            },
                          ),
                          const SizedBox(height: 10),
                          _SidebarItem(
                            icon: Icons.rate_review_outlined,
                            label: 'Pending Reviews',
                            selected: _currentTab == 2,
                            expanded: _sidebarExpanded,
                            badgeCount: _pendingResponsesCount,
                            onTap: () {
                              setState(() {
                                _currentTab = 2;
                                _loadPendingEvaluations();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_sidebarExpanded)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Text(
                        'Use Create Test to draft new assessments and publish once questions are ready.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ),
                const Spacer(),
                // Delete Account Button
                if (_sidebarExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _showDeleteAccountDialog,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete Account'),
                    ),
                  ),
                const SizedBox(height: 12),
                // Profile section at bottom
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final userName =
                        authProvider.userData?['name']?.toString() ?? 'Admin';
                    final userEmail =
                        authProvider.userData?['email']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: _sidebarExpanded
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.white.withOpacity(
                                      0.2,
                                    ),
                                    child: Text(
                                      userName.isNotEmpty
                                          ? userName[0].toUpperCase()
                                          : 'A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          userName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          userEmail,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.white70),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(child: dashboardBody),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: isMobile
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Open navigation',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        actions: [
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: MediaQuery.of(context).size.width < 900
          ? _buildSidebarDrawer()
          : null,
      body: FutureBuilder<List<Test>>(
        future: _testsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const app_widgets.LoadingWidget(message: 'Loading tests...');
          }

          if (snapshot.hasError) {
            return app_widgets.ErrorWidget(
              message: snapshot.error.toString(),
              onRetry: () {
                setState(() => _loadTests());
              },
            );
          }

          final tests = snapshot.data ?? [];

          if (tests.isEmpty && _currentTab == 0) {
            return app_widgets.AppPageScaffold(
              child: app_widgets.EmptyStateWidget(
                title: 'No Tests Created',
                subtitle: 'Create your first test to get started',
                icon: Icons.description_outlined,
                onAction: _createTest,
                actionLabel: 'Create Test',
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return _buildMobileContent(
                  tests,
                  constraints.maxWidth >= 600 ? 2 : 1,
                );
              }
              return _buildDesktopContent(tests, 3);
            },
          );
        },
      ),
    );
  }

  Widget _buildSidebarDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Test Gorilla',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SidebarItem(
                        icon: Icons.dashboard_outlined,
                        label: 'Dashboard',
                        selected: _currentTab == 0,
                        expanded: true,
                        onTap: () {
                          setState(() => _currentTab = 0);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 10),
                      _SidebarItem(
                        icon: Icons.analytics_outlined,
                        label: 'Analytics',
                        selected: _currentTab == 1,
                        expanded: true,
                        onTap: () {
                          setState(() => _currentTab = 1);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 10),
                      _SidebarItem(
                        icon: Icons.rate_review_outlined,
                        label: 'Pending Reviews',
                        selected: _currentTab == 2,
                        expanded: true,
                        badgeCount: _pendingResponsesCount,
                        onTap: () {
                          setState(() {
                            _currentTab = 2;
                            _loadPendingEvaluations();
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (true)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    'Use Create Test to draft new assessments and publish once questions are ready.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: _showDeleteAccountDialog,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete Account'),
              ),
            ),
            const SizedBox(height: 12),
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final userName =
                    authProvider.userData?['name']?.toString() ?? 'Admin';
                final userEmail =
                    authProvider.userData?['email']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue[700],
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                userEmail,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final int? badgeCount;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.expanded,
    this.badgeCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: expanded
                ? Row(
                    children: [
                      Icon(icon, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                      if ((badgeCount ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${badgeCount ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  )
                : Center(child: Icon(icon, color: Colors.white70, size: 24)),
          ),
        ),
      ),
    );
  }
}

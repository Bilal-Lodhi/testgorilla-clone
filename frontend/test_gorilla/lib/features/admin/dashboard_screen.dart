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
  bool _sidebarExpanded = true;
  int _currentTab = 0; // 0: Dashboard, 1: Tests, 2: Analysis

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<ApiClient>();
    _loadTests();
  }

  void _loadTests() {
    _testsFuture = _getTests();
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

  Widget _buildMobileContent(List<Test> tests, int gridCount) {
    final testsView = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCount,
        childAspectRatio: gridCount == 1 ? 1.95 : 1.35,
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
                        'Test Workspace',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage, publish, and organize your assessments in one place.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _createTest,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Test'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                            : 'Analytics Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentTab == 0
                            ? 'Manage, publish, and organize your assessments in one place.'
                            : 'View detailed analytics and statistics.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _createTest,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Test'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
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

          if (tests.isEmpty) {
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
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.expanded,
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
                    ],
                  )
                : Center(child: Icon(icon, color: Colors.white70, size: 24)),
          ),
        ),
      ),
    );
  }
}

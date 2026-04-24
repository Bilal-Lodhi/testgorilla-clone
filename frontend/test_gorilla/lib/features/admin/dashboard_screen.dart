import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard'), elevation: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTest,
        child: const Icon(Icons.add),
        tooltip: 'Create Test',
      ),
      body: FutureBuilder<List<Test>>(
        future: _testsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return app_widgets.LoadingWidget(message: 'Loading tests...');
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
            return app_widgets.EmptyStateWidget(
              title: 'No Tests Created',
              subtitle: 'Create your first test to get started',
              icon: Icons.description_outlined,
              onAction: _createTest,
              actionLabel: 'Create Test',
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Tests (${tests.length})',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      ElevatedButton.icon(
                        onPressed: _createTest,
                        icon: const Icon(Icons.add),
                        label: const Text('New Test'),
                      ),
                    ],
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 1 : 2,
                    childAspectRatio: 1.2,
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
                          : null,
                      onAction: test.status == 'draft'
                          ? () async {
                              await _publishTest(test);
                            }
                          : test.status == 'published'
                          ? () async {
                              await _archiveTest(test.id);
                            }
                          : null,
                      destructiveActionLabel: 'Delete',
                      onDestructiveAction: () async {
                        await _deleteTest(test.id, test.title);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

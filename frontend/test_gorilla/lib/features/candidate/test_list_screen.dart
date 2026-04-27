import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/features/shared/models/models.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;
import 'test_service.dart';

class TestListScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onAttemptFlowCompleted;

  const TestListScreen({
    Key? key,
    this.embedded = false,
    this.onAttemptFlowCompleted,
  }) : super(key: key);

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> {
  late TestService _testService;
  late Future<List<Test>> _testsFuture;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _testService = TestService(apiClient);
    _loadTests();
  }

  void _loadTests() {
    _testsFuture = _testService.getAvailableTests();
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<Test>>(
      future: _testsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const app_widgets.LoadingWidget(message: 'Loading tests...');
        }

        if (snapshot.hasError) {
          return app_widgets.ErrorWidget(
            message: snapshot.error?.toString() ?? 'Unknown error occurred',
            onRetry: () {
              setState(() {
                _loadTests();
              });
            },
          );
        }

        final tests = snapshot.data ?? [];
        final publishedTests = tests
            .where((t) => t.status == 'published')
            .toList();

        if (publishedTests.isEmpty) {
          return const app_widgets.AppPageScaffold(
            child: app_widgets.EmptyStateWidget(
              title: 'No Tests Available',
              subtitle: 'Check back later for new tests',
              icon: Icons.description_outlined,
            ),
          );
        }

        return app_widgets.AppPageScaffold(
          maxContentWidth: 980,
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
                            'Available Tests',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pick a published assessment and start when you are ready.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    app_widgets.StatusBadge(
                      label: '${publishedTests.length} LIVE',
                      status: 'published',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...publishedTests.map((test) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: app_widgets.TestCard(
                    title: test.title,
                    description: test.description,
                    duration: test.durationMinutes,
                    questions: test.totalQuestions,
                    status: test.status,
                    onTap: () {
                      _startTest(test);
                    },
                    actionLabel: 'Start Test',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: () {
                      _startTest(test);
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Available Tests')),
      body: content,
    );
  }

  Future<void> _startTest(Test test) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start Test: ${test.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duration: ${test.durationMinutes} minutes'),
              Text('Questions: ${test.totalQuestions}'),
              Text('Pass Percentage: ${test.passPercentage}%'),
              const SizedBox(height: 12),
              const Text('Are you ready to start?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.of(
                context,
              ).pushNamed('/candidate/attempt', arguments: test);

              if (mounted) {
                setState(() {
                  _loadTests();
                });
                widget.onAttemptFlowCompleted?.call();
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

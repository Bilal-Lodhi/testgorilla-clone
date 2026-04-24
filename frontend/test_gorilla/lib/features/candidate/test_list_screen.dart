import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/features/shared/models/models.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;
import 'test_service.dart';

class TestListScreen extends StatefulWidget {
  final bool embedded;

  const TestListScreen({Key? key, this.embedded = false}) : super(key: key);

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
    final isMobile = MediaQuery.of(context).size.width < 600;

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
          return const app_widgets.EmptyStateWidget(
            title: 'No Tests Available',
            subtitle: 'Check back later for new tests',
            icon: Icons.description_outlined,
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Tests (${publishedTests.length})',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ...publishedTests.map((test) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: app_widgets.TestCard(
                    title: test.title,
                    description: test.description,
                    duration: test.durationMinutes,
                    questions: test.totalQuestions,
                    status: test.status,
                    onTap: () {
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
      appBar: AppBar(title: const Text('Available Tests'), elevation: 0),
      body: content,
    );
  }

  void _startTest(Test test) {
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(
                context,
              ).pushNamed('/candidate/attempt', arguments: test);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

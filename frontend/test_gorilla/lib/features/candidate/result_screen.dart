import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Result'),
        elevation: 0,
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

          final score = _toDouble(
            attempt['score'],
            fallback: _toDouble(result['obtained_marks']),
          );
          final totalMarks = _toDouble(result['total_marks']);
          final percentage = _toDouble(
            result['percentage'],
            fallback: totalMarks > 0 ? (score / totalMarks) * 100 : 0,
          );
          final passPercentage = _toDouble(
            test['pass_percentage'],
            fallback: 60,
          );
          final isPassed = percentage >= passPercentage;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Result Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPassed ? Colors.green[50] : Colors.red[50],
                            border: Border.all(
                              color: isPassed ? Colors.green : Colors.red,
                              width: 4,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isPassed ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isPassed ? 'PASSED' : 'FAILED',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isPassed ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Score: ${score.toStringAsFixed(0)} / ${totalMarks.toStringAsFixed(0)} marks',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Details
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Correct Answers:'),
                            Text(
                              '${result['correct_count'] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Wrong Answers:'),
                            Text(
                              '${result['wrong_count'] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pass Percentage:'),
                            Text(
                              '${passPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Actions
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Text('BACK TO HOME'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

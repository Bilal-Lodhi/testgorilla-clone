import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/features/shared/models/models.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;
import 'package:test_gorilla/features/candidate/test_service.dart';

class AttemptScreen extends StatefulWidget {
  final Test test;

  const AttemptScreen({Key? key, required this.test}) : super(key: key);

  @override
  State<AttemptScreen> createState() => _AttemptScreenState();
}

class _AttemptScreenState extends State<AttemptScreen> {
  late TestService _testService;
  late Future<List<Question>> _questionsFuture;
  List<Question> _questionsCache = [];
  TestAttempt? _currentAttempt;
  int _currentQuestionIndex = 0;
  Timer? _timer;
  late Duration _remainingTime;
  Map<String, String> _answers = {};
  final Map<String, TextEditingController> _codeControllers = {};
  bool _isLoading = false;
  bool _isSubmittingResponse = false;
  bool _isBlocked = false;
  String _blockedMessage = '';

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _testService = TestService(apiClient);
    _remainingTime = Duration(minutes: widget.test.durationMinutes);
    _initializeAttempt();
  }

  Future<void> _initializeAttempt() async {
    _questionsFuture = _testService.getTestQuestions(widget.test.id).then((
      questions,
    ) {
      _questionsCache = questions;
      return questions;
    });
    await _startAttempt();
    if (_currentAttempt != null) {
      _startTimer();
    }
  }

  TextEditingController _getCodeController(String questionId) {
    return _codeControllers.putIfAbsent(
      questionId,
      () => TextEditingController(text: _answers[questionId] ?? ''),
    );
  }

  Future<void> _startAttempt() async {
    try {
      _currentAttempt = await _testService.startAttempt(widget.test.id);
    } catch (e) {
      if (e is ApiException && e.statusCode == 409) {
        if (!mounted) return;

        setState(() {
          _isBlocked = true;
          _blockedMessage =
              'This test has already been started for your account. Reattempts and resume are disabled.';
        });
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting attempt: $e')));
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime = _remainingTime - Duration(seconds: 1);
        }
      });

      // Auto-submit when time runs out
      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        _submitAttempt();
      }
    });
  }

  String _formatTimerDisplay(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(String questionId, String answerId) {
    setState(() {
      _answers[questionId] = answerId;
    });

    if (_currentAttempt == null || _isSubmittingResponse) {
      return;
    }

    _submitAnswer(questionId, answerId);
  }

  Future<bool> _saveCodingAnswer(Question question) async {
    if (_currentAttempt == null || _isSubmittingResponse) {
      return false;
    }

    final controller = _getCodeController(question.id);
    final codeAnswer = controller.text;

    setState(() {
      _isSubmittingResponse = true;
      _answers[question.id] = codeAnswer;
    });

    try {
      await _testService.submitResponse(
        _currentAttempt!.id,
        questionId: question.id,
        codeAnswer: codeAnswer,
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving answer: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSubmittingResponse = false);
      }
    }
  }

  void _submitAnswer(String questionId, String answerId) async {
    if (_isSubmittingResponse || _currentAttempt == null) return;

    setState(() {
      _isSubmittingResponse = true;
    });

    try {
      await _testService.submitResponse(
        _currentAttempt!.id,
        questionId: questionId,
        selectedOptionId: answerId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving answer: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingResponse = false);
      }
    }
  }

  Future<void> _submitAttempt({Question? currentQuestion}) async {
    if (_isLoading || _currentAttempt == null) return;

    setState(() => _isLoading = true);
    _timer?.cancel();

    try {
      // Save current coding answer if available
      final questionToSave =
          currentQuestion ??
          (_questionsCache.isNotEmpty &&
                  _currentQuestionIndex < _questionsCache.length
              ? _questionsCache[_currentQuestionIndex]
              : null);

      if (questionToSave != null && questionToSave.type == 'coding') {
        final controller = _getCodeController(questionToSave.id);
        final codeAnswer = controller.text;

        try {
          await _testService.submitResponse(
            _currentAttempt!.id,
            questionId: questionToSave.id,
            codeAnswer: codeAnswer,
          );
        } catch (e) {
          // Continue with attempt submission even if saving answer fails
        }
      }

      // Submit the test attempt
      await _testService.submitAttempt(_currentAttempt!.id);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/candidate/result',
          arguments: _currentAttempt!.id,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting test: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _codeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isBlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.test.title), elevation: 0),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Test Locked',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(_blockedMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit Test?'),
                content: const Text('Your progress will be lost'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.test.title),
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Container(
                width: 90,
                decoration: BoxDecoration(
                  color: _remainingTime.inSeconds < 300
                      ? Colors.red
                      : Colors.green,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _formatTimerDisplay(_remainingTime),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: FutureBuilder<List<Question>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const app_widgets.LoadingWidget(
                message: 'Loading questions...',
              );
            }

            if (snapshot.hasError) {
              return app_widgets.ErrorWidget(
                message: snapshot.error.toString(),
              );
            }

            final questions = snapshot.data ?? [];
            if (questions.isEmpty) {
              return const app_widgets.EmptyStateWidget(title: 'No Questions');
            }

            final currentQuestion = questions[_currentQuestionIndex];

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                            ),
                            Text('${currentQuestion.marks} marks'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (_currentQuestionIndex + 1) / questions.length,
                        ),
                      ],
                    ),
                  ),

                  // Question
                  Text(
                    currentQuestion.questionText,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),

                  // Options (for MCQ)
                  if (currentQuestion.type == 'mcq' &&
                      currentQuestion.options != null) ...[
                    ...currentQuestion.options!.asMap().entries.map((entry) {
                      final optionIndex = entry.key;
                      final option = entry.value;
                      final isSelected =
                          _answers[currentQuestion.id] ==
                          optionIndex.toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          color: isSelected ? Colors.blue[50] : null,
                          child: ListTile(
                            title: Text(option.optionText),
                            leading: Radio<String>(
                              value: optionIndex.toString(),
                              groupValue: _answers[currentQuestion.id],
                              onChanged: (value) {
                                if (value != null) {
                                  _selectAnswer(currentQuestion.id, value);
                                }
                              },
                            ),
                            onTap: () {
                              _selectAnswer(
                                currentQuestion.id,
                                optionIndex.toString(),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ] else if (currentQuestion.type == 'coding') ...[
                    Text(
                      'Write your answer below',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _getCodeController(currentQuestion.id),
                      minLines: 10,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'Type your code or explanation here',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (value) {
                        _answers[currentQuestion.id] = value;
                      },
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Navigation buttons
                  Row(
                    children: [
                      if (_currentQuestionIndex > 0)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_isLoading || _isSubmittingResponse)
                                ? null
                                : () async {
                                    if (currentQuestion.type == 'coding') {
                                      final saved = await _saveCodingAnswer(
                                        currentQuestion,
                                      );
                                      if (!saved || !mounted) {
                                        return;
                                      }
                                    }

                                    setState(() => _currentQuestionIndex--);
                                  },
                            child: const Text('Previous'),
                          ),
                        ),
                      if (_currentQuestionIndex > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _currentQuestionIndex == questions.length - 1
                            ? ElevatedButton(
                                onPressed: (_isLoading || _isSubmittingResponse)
                                    ? null
                                    : () => _submitAttempt(
                                        currentQuestion: currentQuestion,
                                      ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('SUBMIT'),
                              )
                            : ElevatedButton(
                                onPressed: (_isLoading || _isSubmittingResponse)
                                    ? null
                                    : () async {
                                        if (currentQuestion.type == 'coding') {
                                          final saved = await _saveCodingAnswer(
                                            currentQuestion,
                                          );
                                          if (!saved || !mounted) {
                                            return;
                                          }
                                        }

                                        setState(() => _currentQuestionIndex++);
                                      },
                                child: const Text('Next'),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

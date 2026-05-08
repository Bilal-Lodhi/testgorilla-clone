import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;

class Question {
  final String id;
  final String questionText;
  final String type;
  final int marks;
  final int orderIndex;
  final List<String>? options;
  final int? correctOption;

  Question({
    required this.id,
    required this.questionText,
    required this.type,
    required this.marks,
    required this.orderIndex,
    this.options,
    this.correctOption,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      questionText: json['question_text'] as String,
      type: json['type'] as String,
      marks: json['marks'] as int,
      orderIndex: json['order_index'] as int,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      correctOption: json['correct_option'] as int?,
    );
  }
}

class AddQuestionsScreen extends StatefulWidget {
  final String testId;

  const AddQuestionsScreen({Key? key, required this.testId}) : super(key: key);

  @override
  State<AddQuestionsScreen> createState() => _AddQuestionsScreenState();
}

class _AddQuestionsScreenState extends State<AddQuestionsScreen> {
  final _formKey = GlobalKey<FormState>();
  late ApiClient _apiClient;

  late TextEditingController _questionController;
  late TextEditingController _marksController;
  String _questionType = 'mcq';
  final List<TextEditingController> _optionControllers = [];
  final List<bool> _correctAnswers = [false, false, false, false];
  int _orderIndex = 0;
  bool _isLoading = false;
  String? _error;
  List<Question> _existingQuestions = [];

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<ApiClient>();
    _questionController = TextEditingController();
    _marksController = TextEditingController(text: '1');

    for (int i = 0; i < 4; i++) {
      _optionControllers.add(TextEditingController());
    }

    _loadExistingQuestions();
  }

  Future<void> _loadExistingQuestions() async {
    try {
      final response = await _apiClient.get(
        ApiConstants.questions(widget.testId),
      );

      if (response['data'] is List) {
        final questions = response['data'] as List;
        if (!mounted) {
          return;
        }

        setState(() {
          _existingQuestions = questions
              .map((q) => Question.fromJson(q as Map<String, dynamic>))
              .toList();
          _orderIndex = _existingQuestions.isEmpty
              ? 0
              : _existingQuestions
                        .map((question) => question.orderIndex)
                        .reduce(
                          (maxIndex, currentIndex) =>
                              currentIndex > maxIndex ? currentIndex : maxIndex,
                        ) +
                    1;
        });
      }
    } catch (_) {
      // Ignore preload errors and continue from zero.
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _marksController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _addQuestion() async {
    if (_isLoading) {
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<String>? options;
      int? correctOptionIndex;

      if (_questionType == 'mcq') {
        options = [];

        for (int i = 0; i < 4; i++) {
          final value = _optionControllers[i].text.trim();
          if (value.isNotEmpty) {
            options.add(value);
            if (_correctAnswers[i]) {
              correctOptionIndex = i;
            }
          }
        }

        if (options.isEmpty || correctOptionIndex == null) {
          setState(() {
            _error = 'Please add at least one option and mark a correct answer';
            _isLoading = false;
          });
          return;
        }
      }

      final body = {
        'test_id': widget.testId,
        'question_text': _questionController.text.trim(),
        'type': _questionType,
        'marks': int.parse(_marksController.text),
        'order_index': _orderIndex,
      };

      if (options != null && correctOptionIndex != null) {
        body['options'] = options;
        body['correct_option'] = correctOptionIndex;
      }

      await _apiClient.post(
        '${ApiConstants.tests}/${widget.testId}/questions',
        body: body,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question added successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _questionController.clear();
          _marksController.text = '1';
          for (var controller in _optionControllers) {
            controller.clear();
          }
          for (int i = 0; i < _correctAnswers.length; i++) {
            _correctAnswers[i] = false;
          }
          _orderIndex++;
          _error = null;
          _isLoading = false;
        });

        await _loadExistingQuestions();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Questions')),
      body: SafeArea(
        child: app_widgets.AppPageScaffold(
          maxContentWidth: 860,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              app_widgets.GlassPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question Builder',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add one question at a time. Each saved question increments the order automatically.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Question Type',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(label: Text('MCQ'), value: 'mcq'),
                        ButtonSegment(label: Text('Coding'), value: 'coding'),
                      ],
                      selected: {_questionType},
                      onSelectionChanged: _isLoading
                          ? null
                          : (Set<String> newSelection) {
                              setState(() {
                                _questionType = newSelection.first;
                              });
                            },
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _questionController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Question',
                              hintText: 'Enter the question text',
                              prefixIcon: Icon(Icons.help_outline),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Question is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _marksController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Marks',
                              hintText: '1',
                              prefixIcon: Icon(Icons.star_outline),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Marks is required';
                              }
                              if (int.tryParse(value!) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_questionType == 'mcq') ...[
                const SizedBox(height: 16),
                app_widgets.GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Answer Options',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose one correct option using radio selection.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 4,
                        itemBuilder: (context, index) {
                          final letter = String.fromCharCode(65 + index);
                          final selectedCorrectIndex = _correctAnswers
                              .indexWhere((item) => item);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceMutedOf(context),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<int>(
                                  value: index,
                                  groupValue: selectedCorrectIndex < 0
                                      ? null
                                      : selectedCorrectIndex,
                                  onChanged: _isLoading
                                      ? null
                                      : (value) {
                                          setState(() {
                                            for (
                                              int i = 0;
                                              i < _correctAnswers.length;
                                              i++
                                            ) {
                                              _correctAnswers[i] = i == value;
                                            }
                                          });
                                        },
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    controller: _optionControllers[index],
                                    decoration: InputDecoration(
                                      labelText: '$letter. Option',
                                      hintText: 'Enter option text',
                                    ),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Option is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 560;
                  final doneButton = OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.pop(context, true),
                    child: const Text('Done'),
                  );
                  final addButton = ElevatedButton(
                    onPressed: _isLoading ? null : _addQuestion,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Add Question'),
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        SizedBox(width: double.infinity, child: addButton),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: doneButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: doneButton),
                      const SizedBox(width: 12),
                      Expanded(child: addButton),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

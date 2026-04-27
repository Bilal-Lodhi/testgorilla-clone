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
  bool _showExistingQuestions = true;

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

  Future<void> _deleteQuestion(String questionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Question'),
          content: const Text(
            'Are you sure you want to delete this question? This action cannot be undone.',
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
      await _apiClient.delete(
        '${ApiConstants.tests}/${widget.testId}/questions/$questionId',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadExistingQuestions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete question: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          if (_optionControllers[i].text.isNotEmpty) {
            options.add(_optionControllers[i].text.trim());
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
        child: SingleChildScrollView(
          child: app_widgets.AppPageScaffold(
            maxContentWidth: 860,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Existing Questions Section
                if (_existingQuestions.isNotEmpty) ...[
                  app_widgets.GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Questions Added',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_existingQuestions.length} question${_existingQuestions.length == 1 ? '' : 's'} added',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF64748B),
                                      ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                _showExistingQuestions
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showExistingQuestions =
                                      !_showExistingQuestions;
                                });
                              },
                            ),
                          ],
                        ),
                        if (_showExistingQuestions) ...[
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _existingQuestions.length,
                            itemBuilder: (context, index) {
                              final question = _existingQuestions[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceMuted,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'Q${question.orderIndex + 1}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                question.questionText,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            3,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      question.type
                                                          .toUpperCase(),
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.labelSmall,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${question.marks} mark${question.marks == 1 ? '' : 's'}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelSmall,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _deleteQuestion(question.id),
                                          tooltip: 'Delete Question',
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                    if (question.options != null &&
                                        question.options!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Options:',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...question.options!.asMap().entries.map((
                                        entry,
                                      ) {
                                        final idx = entry.key;
                                        final option = entry.value;
                                        final isCorrect =
                                            idx == question.correctOption;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                '${String.fromCharCode(65 + idx)}.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  option,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: isCorrect
                                                            ? Colors.green
                                                            : null,
                                                        fontWeight: isCorrect
                                                            ? FontWeight.w600
                                                            : null,
                                                      ),
                                                ),
                                              ),
                                              if (isCorrect)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    left: 8,
                                                  ),
                                                  child: Icon(
                                                    Icons.check_circle,
                                                    size: 16,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Add New Question Section
                app_widgets.GlassPanel(
                  child: Column(
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
                          color: const Color(0xFF64748B),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Answer Options',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose one correct option using radio selection.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF64748B)),
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
                                color: AppTheme.surfaceMuted,
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
      ),
    );
  }
}

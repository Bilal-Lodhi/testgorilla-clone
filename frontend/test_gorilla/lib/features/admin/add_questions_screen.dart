import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';

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

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<ApiClient>();
    _questionController = TextEditingController();
    _marksController = TextEditingController(text: '1');

    // Initialize MCQ options controllers
    for (int i = 0; i < 4; i++) {
      _optionControllers.add(TextEditingController());
    }

    // Load existing questions to set correct order_index
    _loadExistingQuestions();
  }

  Future<void> _loadExistingQuestions() async {
    try {
      final response = await _apiClient.get(
        ApiConstants.questions(widget.testId),
      );
      if (response['data'] is List) {
        final questions = response['data'] as List;
        // Set order_index to the count of existing questions
        setState(() {
          _orderIndex = questions.length;
        });
      }
    } catch (e) {
      // If error loading questions, just start at 0
      // (might fail later if questions exist, but user will see error)
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

            // Track which option is marked as correct
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
          // Reset form for next question
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
      appBar: AppBar(title: const Text('Add Questions'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error Message
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Question Type Selection
                    Text(
                      'Question Type',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(label: Text('MCQ'), value: 'mcq'),
                              ButtonSegment(
                                label: Text('Coding'),
                                value: 'coding',
                              ),
                            ],
                            selected: {_questionType},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _questionType = newSelection.first;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Question Text
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

                    // Marks
                    TextFormField(
                      controller: _marksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Marks',
                        hintText: '1',
                        prefixIcon: Icon(Icons.star),
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
                    const SizedBox(height: 24),

                    // MCQ Options
                    if (_questionType == 'mcq') ...[
                      Text(
                        'Options',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 4,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _optionControllers[index],
                                    decoration: InputDecoration(
                                      labelText:
                                          '${String.fromCharCode(65 + index)}. Option',
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
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Mark as correct',
                                  child: Checkbox(
                                    value: _correctAnswers[index],
                                    onChanged: (value) {
                                      setState(() {
                                        // Only one correct answer
                                        for (
                                          int i = 0;
                                          i < _correctAnswers.length;
                                          i++
                                        ) {
                                          _correctAnswers[i] =
                                              (i == index) && (value ?? false);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context, true),
                            child: const Text('Done'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
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
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

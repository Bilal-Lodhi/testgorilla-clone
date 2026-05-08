import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({Key? key}) : super(key: key);

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _passPercentageController = TextEditingController();
  final _accessCodeController = TextEditingController();
  String _selectedStatus = 'draft';

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _passPercentageController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  void _handleCreateTest() async {
    if (_isLoading) {
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<ApiClient>();

      await apiClient.post(
        ApiConstants.tests,
        body: {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'duration_minutes': int.parse(_durationController.text),
          'pass_percentage': int.parse(_passPercentageController.text),
          'access_code': _accessCodeController.text.trim(),
          'status': _selectedStatus,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test created successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('Create Test')),
      body: app_widgets.AppPageScaffold(
        maxContentWidth: 840,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              app_widgets.GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Assessment',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure basic details now. You can add questions right after creating the test.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Test Title',
                        prefixIcon: Icon(Icons.title),
                        hintText: 'Frontend Engineer Screening',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Title is required';
                        }
                        if (value.length < 3) {
                          return 'Title must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description_outlined),
                        hintText: 'Briefly describe what this test evaluates',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 620;

                        final durationField = TextFormField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duration (minutes)',
                            prefixIcon: Icon(Icons.timer_outlined),
                            hintText: '60',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Duration is required';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            if (int.parse(value) <= 0) {
                              return 'Duration must be greater than 0';
                            }
                            return null;
                          },
                        );

                        final passField = TextFormField(
                          controller: _passPercentageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Pass Percentage',
                            prefixIcon: Icon(Icons.percent),
                            hintText: '60',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Pass percentage is required';
                            }
                            final percentage = int.tryParse(value);
                            if (percentage == null) {
                              return 'Please enter a valid number';
                            }
                            if (percentage < 0 || percentage > 100) {
                              return 'Percentage must be between 0 and 100';
                            }
                            return null;
                          },
                        );

                        if (stacked) {
                          return Column(
                            children: [
                              durationField,
                              const SizedBox(height: 16),
                              passField,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: durationField),
                            const SizedBox(width: 16),
                            Expanded(child: passField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accessCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Test Access Code / Passcode',
                        prefixIcon: Icon(Icons.lock_outline),
                        hintText: 'e.g. TEST123',
                        helperText:
                            'Candidates must enter this code to start the test.',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Access code is required';
                        }
                        if (value.trim().length < 3) {
                          return 'Access code must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Initial Status',
                        prefixIcon: Icon(Icons.flag_outlined),
                        helperText:
                            'Tests start as drafts. Publish after adding questions.',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _selectedStatus = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleCreateTest,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Test'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

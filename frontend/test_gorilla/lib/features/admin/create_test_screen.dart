import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/constants/api_constants.dart';

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
  String _selectedStatus = 'draft';

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _passPercentageController.dispose();
    super.dispose();
  }

  void _handleCreateTest() async {
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(title: Text('Create Test'), elevation: 0),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Test Title',
                      prefixIcon: Icon(Icons.title),
                      hintText: 'Enter test title',
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
                  SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                      hintText: 'Enter test description',
                    ),
                    maxLines: 4,
                  ),
                  SizedBox(height: 16),

                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Duration (minutes)',
                      prefixIcon: Icon(Icons.timer),
                      hintText: 'Enter test duration',
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
                  ),
                  SizedBox(height: 16),

                  TextFormField(
                    controller: _passPercentageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Pass Percentage',
                      prefixIcon: Icon(Icons.percent),
                      hintText: 'Enter pass percentage',
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
                  ),
                  SizedBox(height: 24),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Initial Status',
                      prefixIcon: Icon(Icons.flag_outlined),
                      helperText:
                          'Tests start as drafts. Publish them after adding questions.',
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
                  SizedBox(height: 24),

                  if (_error != null) ...[
                    Container(
                      padding: EdgeInsets.all(12),
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
                    SizedBox(height: 16),
                  ],

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreateTest,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('CREATE TEST'),
                    ),
                  ),
                  SizedBox(height: 12),

                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('CANCEL'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

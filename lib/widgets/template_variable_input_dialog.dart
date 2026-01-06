import 'package:flutter/material.dart';
import '../models/template_model.dart';

class TemplateVariableInputDialog extends StatefulWidget {
  final List<TemplateVariable> variables;
  final Function(Map<String, String>) onComplete;

  const TemplateVariableInputDialog({
    super.key,
    required this.variables,
    required this.onComplete,
  });

  @override
  State<TemplateVariableInputDialog> createState() =>
      _TemplateVariableInputDialogState();
}

class _TemplateVariableInputDialogState
    extends State<TemplateVariableInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers for each variable
    for (final variable in widget.variables) {
      _controllers[variable.name] = TextEditingController();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _complete() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Collect all values
    final values = <String, String>{};
    for (final variable in widget.variables) {
      values[variable.name] = _controllers[variable.name]!.text.trim();
    }

    try {
      widget.onComplete(values);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _skip() {
    // Return empty values for all variables
    final values = <String, String>{};
    for (final variable in widget.variables) {
      values[variable.name] = '';
    }
    widget.onComplete(values);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variables.isEmpty) {
      // No variables to fill, complete immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onComplete({});
        Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.edit_note, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Fill Template Variables',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Please fill in the following variables to customize your template:',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Variables List
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: List.generate(widget.variables.length, (index) {
                      final variable = widget.variables[index];
                      final controller = _controllers[variable.name]!;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  variable.name
                                      .replaceAll('_', ' ')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (variable.required) ...[
                                  const SizedBox(width: 4),
                                  const Text(
                                    '*',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: controller,
                              decoration: InputDecoration(
                                hintText: variable.placeholder,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              maxLines:
                                  _isMultilineVariable(variable.name) ? 3 : 1,
                              validator: (value) {
                                if (variable.required &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'This field is required';
                                }
                                return null;
                              },
                              textCapitalization: _getTextCapitalization(
                                variable.name,
                              ),
                              keyboardType: _getKeyboardType(variable.name),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _skip,
                      child: const Text('Skip Variables'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _complete,
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Apply Template'),
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

  bool _isMultilineVariable(String variableName) {
    // Variables that should have multiple lines
    final multilineVariables = {
      'description',
      'content',
      'notes',
      'summary',
      'objectives',
      'discussion',
      'reflection',
      'insights',
      'tips',
      'instructions',
    };

    return multilineVariables.any(
      (keyword) => variableName.toLowerCase().contains(keyword),
    );
  }

  TextCapitalization _getTextCapitalization(String variableName) {
    // Variables that should be capitalized
    final titleVariables = {
      'title',
      'name',
      'author',
      'project',
      'meeting',
      'book',
      'recipe',
    };

    if (titleVariables.any(
      (keyword) => variableName.toLowerCase().contains(keyword),
    )) {
      return TextCapitalization.words;
    }

    return TextCapitalization.sentences;
  }

  TextInputType _getKeyboardType(String variableName) {
    // Variables that should use specific keyboard types
    if (variableName.toLowerCase().contains('email')) {
      return TextInputType.emailAddress;
    }

    if (variableName.toLowerCase().contains('phone')) {
      return TextInputType.phone;
    }

    if (variableName.toLowerCase().contains('url') ||
        variableName.toLowerCase().contains('link')) {
      return TextInputType.url;
    }

    if (variableName.toLowerCase().contains('number') ||
        variableName.toLowerCase().contains('count') ||
        variableName.toLowerCase().contains('rating') ||
        variableName.toLowerCase().contains('page')) {
      return TextInputType.number;
    }

    return TextInputType.text;
  }
}

import 'package:flutter/material.dart';
import '../models/template_model.dart';

class SaveAsTemplateDialog extends StatefulWidget {
  final String noteTitle;
  final String noteContent;
  final Function(TemplateModel) onSave;

  const SaveAsTemplateDialog({
    super.key,
    required this.noteTitle,
    required this.noteContent,
    required this.onSave,
  });

  @override
  State<SaveAsTemplateDialog> createState() => _SaveAsTemplateDialogState();
}

class _SaveAsTemplateDialogState extends State<SaveAsTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final List<TemplateVariable> _variables = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.noteTitle;
    _contentController.text = widget.noteContent;
    _extractVariables();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _extractVariables() {
    // Extract variables from content using regex to find {{variable_name}} patterns
    final regex = RegExp(r'\{\{([^}]+)\}\}');
    final matches = regex.allMatches(widget.noteContent);
    final variableNames = <String>{};

    for (final match in matches) {
      final variableName = match.group(1)?.trim();
      if (variableName != null && variableName.isNotEmpty) {
        variableNames.add(variableName);
      }
    }

    // Create TemplateVariable objects for each unique variable
    _variables.clear();
    for (final name in variableNames) {
      _variables.add(
        TemplateVariable(
          name: name,
          placeholder: 'Enter $name',
          required: false,
        ),
      );
    }
  }

  void _addVariable() {
    showDialog(
      context: context,
      builder:
          (context) => _AddVariableDialog(
            onAdd: (variable) {
              setState(() {
                _variables.add(variable);
                // Add the variable placeholder to content if not already present
                final placeholder = '{{${variable.name}}}';
                if (!_contentController.text.contains(placeholder)) {
                  _contentController.text += '\n\n$placeholder';
                }
              });
            },
          ),
    );
  }

  void _removeVariable(int index) {
    setState(() {
      final variable = _variables[index];
      _variables.removeAt(index);
      // Optionally remove the placeholder from content
      final placeholder = '{{${variable.name}}}';
      _contentController.text = _contentController.text.replaceAll(
        placeholder,
        '',
      );
    });
  }

  void _editVariable(int index) {
    final variable = _variables[index];
    showDialog(
      context: context,
      builder:
          (context) => _EditVariableDialog(
            variable: variable,
            onEdit: (editedVariable) {
              setState(() {
                // Update placeholder in content if name changed
                if (variable.name != editedVariable.name) {
                  final oldPlaceholder = '{{${variable.name}}}';
                  final newPlaceholder = '{{${editedVariable.name}}}';
                  _contentController.text = _contentController.text.replaceAll(
                    oldPlaceholder,
                    newPlaceholder,
                  );
                }
                _variables[index] = editedVariable;
              });
            },
          ),
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final template = TemplateModel(
        id: '', // Will be set by Firestore
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        content: _contentController.text.trim(),
        variables: _variables,
        isCustom: true,
      );

      widget.onSave(template);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving template: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.save_alt, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Save as Template',
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
              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Template Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Template Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a template name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Template Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(),
                          hintText: 'Describe what this template is for',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Template Content
                      const Text(
                        'Template Content',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use {{variable_name}} syntax to create placeholders that will be filled when using the template.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter template content with {{variables}}',
                        ),
                        maxLines: 8,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter template content';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // Re-extract variables when content changes
                          _extractVariables();
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 24),

                      // Variables Section
                      Row(
                        children: [
                          const Text(
                            'Template Variables',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addVariable,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Variable'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_variables.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Center(
                            child: Text(
                              'No variables found. Add {{variable_name}} to your content to create variables.',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...List.generate(_variables.length, (index) {
                          final variable = _variables[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '{{${variable.name}}}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      if (variable.placeholder.isNotEmpty)
                                        Text(
                                          variable.placeholder,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      if (variable.required)
                                        const Text(
                                          'Required',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _editVariable(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () => _removeVariable(index),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveTemplate,
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Save Template'),
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

class _AddVariableDialog extends StatefulWidget {
  final Function(TemplateVariable) onAdd;

  const _AddVariableDialog({required this.onAdd});

  @override
  State<_AddVariableDialog> createState() => _AddVariableDialogState();
}

class _AddVariableDialogState extends State<_AddVariableDialog> {
  final _nameController = TextEditingController();
  final _placeholderController = TextEditingController();
  bool _isRequired = false;

  @override
  void dispose() {
    _nameController.dispose();
    _placeholderController.dispose();
    super.dispose();
  }

  void _addVariable() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final variable = TemplateVariable(
      name: name,
      placeholder:
          _placeholderController.text.trim().isEmpty
              ? 'Enter $name'
              : _placeholderController.text.trim(),
      required: _isRequired,
    );

    widget.onAdd(variable);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Variable'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Variable Name',
              hintText: 'e.g., project_name, date, author',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _placeholderController,
            decoration: const InputDecoration(
              labelText: 'Placeholder Text',
              hintText: 'Hint text for users',
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Required'),
            subtitle: const Text('User must fill this field'),
            value: _isRequired,
            onChanged: (value) {
              setState(() {
                _isRequired = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _addVariable, child: const Text('Add')),
      ],
    );
  }
}

class _EditVariableDialog extends StatefulWidget {
  final TemplateVariable variable;
  final Function(TemplateVariable) onEdit;

  const _EditVariableDialog({required this.variable, required this.onEdit});

  @override
  State<_EditVariableDialog> createState() => _EditVariableDialogState();
}

class _EditVariableDialogState extends State<_EditVariableDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _placeholderController;
  late bool _isRequired;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.variable.name);
    _placeholderController = TextEditingController(
      text: widget.variable.placeholder,
    );
    _isRequired = widget.variable.required;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _placeholderController.dispose();
    super.dispose();
  }

  void _saveVariable() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final variable = TemplateVariable(
      name: name,
      placeholder:
          _placeholderController.text.trim().isEmpty
              ? 'Enter $name'
              : _placeholderController.text.trim(),
      required: _isRequired,
    );

    widget.onEdit(variable);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Variable'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Variable Name',
              hintText: 'e.g., project_name, date, author',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _placeholderController,
            decoration: const InputDecoration(
              labelText: 'Placeholder Text',
              hintText: 'Hint text for users',
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Required'),
            subtitle: const Text('User must fill this field'),
            value: _isRequired,
            onChanged: (value) {
              setState(() {
                _isRequired = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveVariable, child: const Text('Save')),
      ],
    );
  }
}

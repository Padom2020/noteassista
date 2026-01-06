import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:file_picker/file_picker.dart'; // Removed due to Gradle compatibility issues
import '../services/supabase_service.dart';

class ImportTemplateDialog extends StatefulWidget {
  final VoidCallback? onImportSuccess;

  const ImportTemplateDialog({super.key, this.onImportSuccess});

  @override
  State<ImportTemplateDialog> createState() => _ImportTemplateDialogState();
}

class _ImportTemplateDialogState extends State<ImportTemplateDialog> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final TextEditingController _jsonController = TextEditingController();

  bool _isImporting = false;
  String? _validationError;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _importFromFile() async {
    // File picker functionality temporarily disabled due to Gradle compatibility issues
    // Users can paste JSON content directly using the clipboard import instead
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File import temporarily unavailable. Please use "Import from Clipboard" instead.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _importFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        setState(() {
          _jsonController.text = clipboardData!.text!;
          _validationError = null;
        });

        _validateTemplate(clipboardData!.text!);
      } else {
        setState(() {
          _validationError = 'No text found in clipboard';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = 'Error reading clipboard: $e';
        });
      }
    }
  }

  void _validateTemplate(String jsonString) {
    if (jsonString.trim().isEmpty) {
      setState(() {
        _validationError = null;
      });
      return;
    }

    final result = _supabaseService.validateImportedTemplate(jsonString);
    setState(() {
      _validationError = result.success ? null : result.error;
    });
  }

  Future<void> _importTemplate() async {
    final jsonString = _jsonController.text.trim();
    if (jsonString.isEmpty) {
      setState(() {
        _validationError = 'Please enter template data';
      });
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final result = await _supabaseService.importTemplate(jsonString);

      if (mounted) {
        if (result.success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template imported successfully'),
              backgroundColor: Colors.green,
            ),
          );

          widget.onImportSuccess?.call();
        } else {
          setState(() {
            _validationError = result.error;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Template'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import a template from JSON data',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // Import options
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isImporting ? null : _importFromFile,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('From File'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isImporting ? null : _importFromClipboard,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('From Clipboard'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // JSON input field
            Text(
              'Template JSON:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _jsonController,
                onChanged: _validateTemplate,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Paste template JSON here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),

            // Validation error
            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              (_isImporting ||
                      _validationError != null ||
                      _jsonController.text.trim().isEmpty)
                  ? null
                  : _importTemplate,
          child:
              _isImporting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Import'),
        ),
      ],
    );
  }
}

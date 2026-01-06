import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../services/supabase_service.dart';

/// Dialog for renaming an existing folder
class RenameFolderDialog extends StatefulWidget {
  /// The folder to rename
  final FolderModel folder;

  const RenameFolderDialog({super.key, required this.folder});

  @override
  State<RenameFolderDialog> createState() => _RenameFolderDialogState();
}

class _RenameFolderDialogState extends State<RenameFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final SupabaseService _supabaseService = SupabaseService.instance;

  bool _isRenaming = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _renameFolder() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();

    // Check if name actually changed
    if (newName == widget.folder.name) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isRenaming = true);

    try {
      final updatedFolder = widget.folder.copyWith(name: newName);
      final result = await _supabaseService.updateFolder(
        widget.folder.id,
        updatedFolder,
      );

      if (mounted) {
        if (result.success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Folder renamed to "$newName"'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error renaming folder: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renaming folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRenaming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Folder'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Folder Name',
                hintText: 'Enter new folder name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a folder name';
                }
                if (value.trim().length > 50) {
                  return 'Folder name must be 50 characters or less';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRenaming ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isRenaming ? null : _renameFolder,
          child:
              _isRenaming
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Rename'),
        ),
      ],
    );
  }
}

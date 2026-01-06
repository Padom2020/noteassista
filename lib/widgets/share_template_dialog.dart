import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/template_model.dart';
import '../services/supabase_service.dart';

class ShareTemplateDialog extends StatefulWidget {
  final TemplateModel template;

  const ShareTemplateDialog({super.key, required this.template});

  @override
  State<ShareTemplateDialog> createState() => _ShareTemplateDialogState();
}

class _ShareTemplateDialogState extends State<ShareTemplateDialog> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  bool _isExporting = false;

  Future<void> _exportAsJson() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final result = _supabaseService.exportTemplate(widget.template);
      if (!result.success) {
        throw Exception(result.error);
      }

      final jsonString = result.data!;

      // Create a temporary file
      final directory = await getTemporaryDirectory();
      final fileName =
          '${widget.template.name.replaceAll(RegExp(r'[^\w\s-]'), '')}_template.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Template: ${widget.template.name}',
        subject: 'NoteAssista Template Export',
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      final result = _supabaseService.exportTemplate(widget.template);
      if (!result.success) {
        throw Exception(result.error);
      }

      final jsonString = result.data!;
      await Clipboard.setData(ClipboardData(text: jsonString));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template copied to clipboard'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Template'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share "${widget.template.name}" with others',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose how you want to share this template:',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isExporting ? null : _copyToClipboard,
          child: const Text('Copy to Clipboard'),
        ),
        ElevatedButton(
          onPressed: _isExporting ? null : _exportAsJson,
          child:
              _isExporting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Export as File'),
        ),
      ],
    );
  }
}

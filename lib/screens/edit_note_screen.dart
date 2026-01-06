import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/voice_service.dart';
import '../services/link_management_service.dart';
import '../services/collaboration_service.dart';
import '../services/ocr_service.dart';
import '../services/reminder_service.dart';
import '../models/note_model.dart';
import '../models/collaborator_model.dart';
import '../models/folder_model.dart';
import '../utils/timestamp_utils.dart';
import '../widgets/voice_capture_button.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/link_autocomplete_dropdown.dart';
import '../widgets/backlinks_section.dart';
import '../widgets/collaborator_avatar_list.dart';
import '../widgets/cursor_indicator.dart';
import '../widgets/share_note_dialog.dart';
import '../widgets/image_thumbnail_grid.dart';
import '../widgets/drawing_thumbnail_grid.dart';
import '../screens/ocr_processing_screen.dart';
import '../screens/drawing_screen.dart';
import '../widgets/save_as_template_dialog.dart';
import '../widgets/reminder_dialog.dart';
import '../widgets/feature_tooltip.dart';

class EditNoteScreen extends StatefulWidget {
  final NoteModel note;

  const EditNoteScreen({super.key, required this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;
  final VoiceService _voiceService = VoiceService();
  final LinkManagementService _linkService = LinkManagementService();
  final CollaborationService _collaborationService = CollaborationService();
  final OCRService _ocrService = OCRService();

  late int _selectedCategoryIndex;
  bool _isLoading = false;
  bool _isRecordingAudio = false;
  late List<String> _audioUrls;
  late List<String> _imageUrls;
  late List<String> _drawingUrls;
  String? _currentRecordingPath;
  final List<String> _newOcrImagePaths = [];

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  // Keys for feature tooltips
  final GlobalKey _shareButtonKey = GlobalKey();

  bool _canEdit = true;
  bool _isCheckingPermissions = true;
  CollaboratorRole? _userRole;

  // Folder management
  String? _selectedFolderId;
  List<FolderModel> _folders = [];

  // Reminder
  ReminderModel? _reminder;

  @override
  void initState() {
    super.initState();
    // Pre-populate form with existing note data
    _titleController = TextEditingController(text: widget.note.title);
    _descriptionController = TextEditingController(
      text: widget.note.description,
    );
    _selectedCategoryIndex = widget.note.categoryImageIndex;
    _audioUrls = List<String>.from(widget.note.audioUrls);
    _imageUrls = List<String>.from(widget.note.imageUrls);
    _drawingUrls = List<String>.from(widget.note.drawingUrls);
    _selectedFolderId = widget.note.folderId;
    _reminder = widget.note.reminder;

    // Check permissions
    _checkPermissions();

    // Load folders
    _loadFolders();

    // Update presence to viewing when screen opens
    _updatePresence(PresenceStatus.viewing);

    // Listen for focus changes to update presence
    _descriptionFocusNode.addListener(_onDescriptionFocusChange);
  }

  Future<void> _checkPermissions() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _canEdit = false;
        _isCheckingPermissions = false;
      });
      return;
    }

    try {
      // If note has an owner, check permissions
      if (widget.note.ownerId != null) {
        final canEdit = await _collaborationService.canEdit(
          userId,
          widget.note.id,
          widget.note.ownerId!,
        );
        final userRole = await _collaborationService.getUserRole(
          userId,
          widget.note.id,
          widget.note.ownerId!,
        );

        // Convert string to enum
        CollaboratorRole? roleEnum;
        switch (userRole) {
          case 'owner':
            roleEnum = CollaboratorRole.owner;
            break;
          case 'editor':
            roleEnum = CollaboratorRole.editor;
            break;
          case 'viewer':
            roleEnum = CollaboratorRole.viewer;
            break;
          default:
            roleEnum = null;
        }

        setState(() {
          _canEdit = canEdit;
          _userRole = roleEnum;
          _isCheckingPermissions = false;
        });
      } else {
        // No owner set, user is the owner
        setState(() {
          _canEdit = true;
          _userRole = CollaboratorRole.owner;
          _isCheckingPermissions = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      setState(() {
        _canEdit = false;
        _isCheckingPermissions = false;
      });
    }
  }

  void _onDescriptionFocusChange() {
    if (_descriptionFocusNode.hasFocus) {
      _updatePresence(PresenceStatus.editing);
    } else {
      _updatePresence(PresenceStatus.viewing);
    }
  }

  Future<void> _updatePresence(PresenceStatus status) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      final user = _authService.currentUser!;
      await _collaborationService.updatePresence(
        widget.note.id,
        userId,
        user.email ?? '',
        user.displayName ?? user.email ?? 'User',
        status,
      );
    } catch (e) {
      // Silently fail - presence is not critical
      debugPrint('Error updating presence: $e');
    }
  }

  @override
  void dispose() {
    // Clean up presence when leaving
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      _collaborationService.cleanupPresence(widget.note.id, userId);
    }

    _descriptionFocusNode.removeListener(_onDescriptionFocusChange);
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _voiceService.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  void _selectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
  }

  Future<void> _startAudioRecording() async {
    try {
      setState(() {
        _isRecordingAudio = true;
      });

      _currentRecordingPath = await _voiceService.recordAudio();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecordingAudio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopAudioRecording() async {
    try {
      final recordingPath = await _voiceService.stopRecording();

      if (recordingPath != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _isRecordingAudio = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecordingAudio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeAudioUrl(String url) async {
    try {
      // Delete from cloud storage
      await _voiceService.deleteAudio(url);

      setState(() {
        _audioUrls.remove(url);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateNote() async {
    // Check if user has edit permission
    if (!_canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You don\'t have permission to edit this note'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Get current user
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload audio recording if exists
      if (_currentRecordingPath != null) {
        final audioUrl = await _voiceService.saveAudio(
          _currentRecordingPath!,
          userId,
          widget.note.id,
        );
        _audioUrls.add(audioUrl);
      }

      // Upload new OCR images if exist
      if (_newOcrImagePaths.isNotEmpty) {
        for (final imagePath in _newOcrImagePaths) {
          final imageUrl = await _ocrService.uploadImage(
            imagePath,
            userId,
            widget.note.id,
          );
          _imageUrls.add(imageUrl);
        }
      }

      // Generate new timestamp
      final timestamp = generateTimestamp();

      // Calculate word count
      final wordCount =
          _descriptionController.text.trim().split(RegExp(r'\s+')).length;

      // Extract outgoing links from description
      final links = _linkService.parseLinks(_descriptionController.text.trim());
      final outgoingLinks =
          links.map((link) => link.targetTitle).toSet().toList();

      // Create updated note model, preserving note ID and isDone status
      final updatedNote = NoteModel(
        id: widget.note.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        timestamp: timestamp,
        categoryImageIndex: _selectedCategoryIndex,
        isDone: widget.note.isDone, // Preserve completion status
        audioUrls: _audioUrls,
        imageUrls: _imageUrls, // Updated with new OCR images
        drawingUrls: _drawingUrls, // Updated with new drawings
        wordCount: wordCount,
        outgoingLinks: outgoingLinks,
        // Preserve other fields
        tags: widget.note.tags,
        isPinned: widget.note.isPinned,
        customImageUrl: widget.note.customImageUrl,
        folderId: _selectedFolderId,
        isShared: widget.note.isShared,
        collaboratorIds: widget.note.collaboratorIds,
        collaborators: widget.note.collaborators,
        sourceUrl: widget.note.sourceUrl,
        reminder: _reminder, // Use updated reminder
        viewCount: widget.note.viewCount,
        createdAt: widget.note.createdAt,
        ownerId: widget.note.ownerId, // Preserve owner
      );

      // Update in Supabase
      final result = await _supabaseService.updateNote(
        widget.note.id,
        updatedNote,
      );
      if (!result.success) {
        throw Exception(result.error ?? 'Failed to update note');
      }

      // Navigate back to HomeScreen
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on Exception catch (e) {
      // Display user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Display generic error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating note: $e'),
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

  Widget _buildCategoryGrid() {
    final categoryImages = [
      'assets/images/0.png',
      'assets/images/1.png',
      'assets/images/2.png',
      'assets/images/3.png',
      'assets/images/4.png',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 5,
      itemBuilder: (context, index) {
        final isSelected = _selectedCategoryIndex == index;

        return GestureDetector(
          onTap: () => _selectCategory(index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                categoryImages[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.image, color: Colors.grey[400]),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _onVoiceTranscription(String transcription) {
    // Append transcription to description
    final currentText = _descriptionController.text;
    final newText =
        currentText.isEmpty ? transcription : '$currentText\n\n$transcription';
    _descriptionController.text = newText;
  }

  Future<void> _captureImagesForOCR() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show dialog to choose single or multiple images
      final choice = await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Capture Images'),
              content: const Text('How would you like to capture images?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'single'),
                  child: const Text('Single Image'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'multiple'),
                  child: const Text('Multiple Images'),
                ),
              ],
            ),
      );

      if (choice == null || choice == 'cancel') return;

      List<File> images = [];

      if (choice == 'single') {
        // Capture single image
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (photo != null) {
          images.add(File(photo.path));
        }
      } else {
        // Capture multiple images from gallery
        final List<XFile> photos = await picker.pickMultiImage(
          imageQuality: 85,
        );

        images = photos.map((photo) => File(photo.path)).toList();
      }

      if (images.isEmpty) return;

      // Navigate to OCR processing screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => OCRProcessingScreen(
                  images: images,
                  onComplete: _onOCRComplete,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onOCRComplete(String extractedText, List<String> imagePaths) {
    // Append extracted text to description
    if (extractedText.isNotEmpty) {
      final currentText = _descriptionController.text;
      final newText =
          currentText.isEmpty
              ? extractedText
              : '$currentText\n\n$extractedText';
      _descriptionController.text = newText;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text extracted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Store image paths for display
    setState(() {
      _newOcrImagePaths.addAll(imagePaths);
    });
  }

  Future<void> _openDrawingScreen() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder:
            (context) => DrawingScreen(userId: userId, noteId: widget.note.id),
      ),
    );

    if (result != null) {
      // Handle different return types from DrawingScreen
      if (result is String) {
        // Simple drawing URL
        setState(() {
          _drawingUrls.add(result);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Drawing added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (result is Map<String, dynamic>) {
        final type = result['type'] as String?;

        if (type == 'text') {
          // User chose to replace drawing with text
          final text = result['content'] as String;
          setState(() {
            // Append recognized text to description
            if (_descriptionController.text.isNotEmpty) {
              _descriptionController.text += '\n\n$text';
            } else {
              _descriptionController.text = text;
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Handwriting converted to text'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (type == 'both') {
          // User chose to keep both drawing and text
          final drawingUrl = result['drawingUrl'] as String;
          final text = result['text'] as String;

          setState(() {
            _drawingUrls.add(drawingUrl);
            // Append recognized text to description
            if (_descriptionController.text.isNotEmpty) {
              _descriptionController.text += '\n\n$text';
            } else {
              _descriptionController.text = text;
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Drawing and text added successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    }
  }

  void _onDrawingAdded(String drawingUrl) {
    setState(() {
      _drawingUrls.add(drawingUrl);
    });
  }

  void _onDrawingRemoved(int index) {
    setState(() {
      _drawingUrls.removeAt(index);
    });
  }

  Future<void> _loadFolders() async {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      try {
        final result = await _supabaseService.getFolders();
        if (result.success && result.data != null) {
          final folders = result.data!;
          if (mounted) {
            setState(() {
              _folders = folders;
            });
          }
        }
      } catch (e) {
        // Handle error silently for now
      }
    }
  }

  Future<void> _saveAsTemplate() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty && description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add some content before saving as template'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save templates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder:
          (context) => SaveAsTemplateDialog(
            noteTitle: title.isEmpty ? 'Untitled Template' : title,
            noteContent: description,
            onSave: (template) async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                final result = await _supabaseService.createTemplate(template);
                if (!result.success) {
                  throw Exception(result.error ?? 'Failed to create template');
                }

                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Template "${template.name}" saved successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error saving template: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
    );
  }

  void _showReminderDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ReminderDialog(
            existingReminder: _reminder,
            onReminderSet: (reminder) async {
              setState(() {
                _reminder = reminder;
              });
              if (reminder != null) {
                // Schedule the reminder with ReminderService
                try {
                  final reminderService = ReminderService();

                  debugPrint(
                    'Scheduling reminder: type=${reminder.type}, id=${reminder.id}',
                  );

                  if (reminder.type == ReminderType.time &&
                      reminder.triggerTime != null) {
                    debugPrint(
                      'Scheduling time reminder for ${reminder.triggerTime}',
                    );
                    await reminderService.scheduleTimeReminder(
                      widget.note.id,
                      reminder.triggerTime!,
                      recurring: reminder.recurring,
                      pattern: reminder.pattern,
                    );
                    debugPrint('Time reminder scheduled successfully');
                  } else if (reminder.type == ReminderType.location &&
                      reminder.latitude != null &&
                      reminder.longitude != null) {
                    debugPrint(
                      'Scheduling location reminder at ${reminder.latitude}, ${reminder.longitude}',
                    );
                    await reminderService.scheduleLocationReminder(
                      widget.note.id,
                      reminder.latitude!,
                      reminder.longitude!,
                      reminder.radiusMeters ?? 100.0,
                    );
                    debugPrint('Location reminder scheduled successfully');
                  } else {
                    debugPrint(
                      'Invalid reminder data: type=${reminder.type}, triggerTime=${reminder.triggerTime}, lat=${reminder.latitude}, lng=${reminder.longitude}',
                    );
                  }

                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reminder scheduled successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error scheduling reminder: $e');
                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error scheduling reminder: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminder removed'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
    );
  }

  Widget _buildFolderBreadcrumb() {
    if (_selectedFolderId == null) {
      return const SizedBox.shrink();
    }

    final folder =
        _folders.where((f) => f.id == _selectedFolderId).isNotEmpty
            ? _folders.where((f) => f.id == _selectedFolderId).first
            : null;
    if (folder == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(
          int.parse(folder.color.replaceFirst('#', '0xFF')),
        ).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(
            int.parse(folder.color.replaceFirst('#', '0xFF')),
          ).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder,
            color: Color(int.parse(folder.color.replaceFirst('#', '0xFF'))),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'In folder: ${folder.name}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(int.parse(folder.color.replaceFirst('#', '0xFF'))),
            ),
          ),
          const Spacer(),
          if (_canEdit)
            TextButton(
              onPressed: () => _showFolderSelectionDialog(),
              child: const Text('Move'),
            ),
        ],
      ),
    );
  }

  Future<void> _showFolderSelectionDialog() async {
    final newFolderId = await showDialog<String?>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Move to Folder'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('Root Folder (No folder)'),
                    selected: _selectedFolderId == null,
                    onTap: () => Navigator.pop(context, 'root'),
                  ),
                  ..._folders.map((folder) {
                    return ListTile(
                      leading: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(folder.color.replaceFirst('#', '0xFF')),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      title: Text(folder.name),
                      selected: _selectedFolderId == folder.id,
                      onTap: () => Navigator.pop(context, folder.id),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );

    if (newFolderId != null) {
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        try {
          final targetFolderId = newFolderId == 'root' ? null : newFolderId;
          final result = await _supabaseService.moveNoteToFolder(
            widget.note.id,
            targetFolderId,
          );
          if (!result.success) {
            throw Exception(result.error ?? 'Failed to move note');
          }

          setState(() {
            _selectedFolderId = targetFolderId;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Note moved successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error moving note: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;

    // Show loading while checking permissions
    if (_isCheckingPermissions) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Note')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Expanded(child: Text('Edit Note')),
            // Collaborator avatars
            if (widget.note.isShared && userId != null)
              CollaboratorAvatarList(
                noteId: widget.note.id,
                collaborationService: _collaborationService,
                onTap: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => ShareNoteDialog(
                          userId: userId,
                          noteId: widget.note.id,
                          collaborationService: _collaborationService,
                        ),
                  );
                },
              ),
          ],
        ),
        actions: [
          // Camera button for OCR (only if can edit)
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _captureImagesForOCR,
              tooltip: 'Capture image for text extraction',
            ),
          // Drawing button (only if can edit)
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.brush),
              onPressed: _openDrawingScreen,
              tooltip: 'Create drawing',
            ),
          // Reminder button (only if can edit)
          if (_canEdit)
            IconButton(
              icon: Icon(
                _reminder != null
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: _reminder != null ? Colors.orange : null,
              ),
              onPressed: _showReminderDialog,
              tooltip: 'Set reminder',
            ),
          // Share button
          if (userId != null)
            FeatureTooltip(
              tooltipId: 'collaboration_share_feature',
              message: 'Share notes and edit together in real-time',
              direction: TooltipDirection.bottom,
              child: IconButton(
                key: _shareButtonKey,
                icon: Icon(
                  widget.note.isShared ? Icons.people : Icons.person_add,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => ShareNoteDialog(
                          userId: userId,
                          noteId: widget.note.id,
                          collaborationService: _collaborationService,
                        ),
                  );
                },
                tooltip: 'Share note',
              ),
            ),
          // Save as template button
          if (_canEdit && userId != null)
            IconButton(
              icon: const Icon(Icons.save_alt),
              onPressed: _saveAsTemplate,
              tooltip: 'Save as template',
            ),
          // Voice capture button in app bar (only if can edit)
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.mic),
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Voice Input',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),
                              VoiceCaptureButton(
                                voiceService: _voiceService,
                                onTranscriptionComplete: (transcription) {
                                  Navigator.pop(context);
                                  _onVoiceTranscription(transcription);
                                },
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      ),
                );
              },
              tooltip: 'Voice input',
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Permission banner for read-only mode
                  if (!_canEdit)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _userRole == CollaboratorRole.viewer
                                  ? 'You have view-only access to this note'
                                  : 'You don\'t have permission to edit this note',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Folder breadcrumb
                  _buildFolderBreadcrumb(),

                  // Title field
                  TextFormField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    enabled: _canEdit,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      suffixIcon: !_canEdit ? const Icon(Icons.lock) : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Typing indicator
                  if (widget.note.isShared)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TypingIndicator(
                        noteId: widget.note.id,
                        collaborationService: _collaborationService,
                      ),
                    ),

                  // Description field with link help
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_canEdit)
                        Row(
                          children: [
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message:
                                  'Tip: Type [[ to create links to other notes. This helps build your knowledge network!',
                              child: Icon(
                                Icons.help_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      if (_canEdit) const SizedBox(height: 4),
                      TextFormField(
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        enabled: _canEdit,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: _canEdit ? null : 'Description',
                          alignLabelWithHint: true,
                          hintText:
                              _canEdit
                                  ? 'Type [[ to link to another note'
                                  : 'Read-only mode',
                          suffixIcon: !_canEdit ? const Icon(Icons.lock) : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Category selection label
                  if (_canEdit) ...[
                    const Text(
                      'Select Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category grid
                    _buildCategoryGrid(),
                  ],
                  const SizedBox(height: 24),

                  // OCR Images section
                  if (_imageUrls.isNotEmpty ||
                      _newOcrImagePaths.isNotEmpty) ...[
                    // Display existing images from note
                    if (_imageUrls.isNotEmpty)
                      ImageThumbnailGrid(
                        imageUrls: _imageUrls,
                        isLocalPath: false,
                      ),
                    if (_imageUrls.isNotEmpty && _newOcrImagePaths.isNotEmpty)
                      const SizedBox(height: 12),
                    // Display newly captured images
                    if (_newOcrImagePaths.isNotEmpty)
                      ImageThumbnailGrid(
                        imageUrls: _newOcrImagePaths,
                        isLocalPath: true,
                      ),
                    const SizedBox(height: 24),
                  ],

                  // Drawings section
                  if (userId != null && _canEdit) ...[
                    DrawingThumbnailGrid(
                      drawingUrls: _drawingUrls,
                      userId: userId,
                      noteId: widget.note.id,
                      onDrawingAdded: _onDrawingAdded,
                      onDrawingRemoved: _onDrawingRemoved,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Audio attachments section
                  const Text(
                    'Audio Attachments',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Display existing audio attachments
                  if (_audioUrls.isNotEmpty)
                    ..._audioUrls.map((url) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AudioPlayerWidget(
                          audioUrl: url,
                          onDelete:
                              _canEdit ? () => _removeAudioUrl(url) : null,
                        ),
                      );
                    }),

                  // Audio recording button (only if can edit)
                  if (_canEdit &&
                      !_isRecordingAudio &&
                      _currentRecordingPath == null)
                    OutlinedButton.icon(
                      onPressed: _startAudioRecording,
                      icon: const Icon(Icons.mic),
                      label: const Text('Record Audio'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                    ),

                  // Recording indicator
                  if (_isRecordingAudio)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color: Colors.red[700],
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Recording audio...',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _stopAudioRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                            ),
                            child: const Text('Stop'),
                          ),
                        ],
                      ),
                    ),

                  // Show recorded audio indicator
                  if (_currentRecordingPath != null && !_isRecordingAudio)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700]),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Audio recorded (will be uploaded with note)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _currentRecordingPath = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Update button (only if can edit)
                  if (_canEdit)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateNote,
                        child:
                            _isLoading
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
                                : const Text('Update Note'),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Source URL section (for web clipped notes)
                  if (widget.note.sourceUrl != null &&
                      widget.note.sourceUrl!.isNotEmpty) ...[
                    const Text(
                      'Source',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        // Show source URL in snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Source: ${widget.note.sourceUrl}'),
                            action: SnackBarAction(
                              label: 'Copy',
                              onPressed: () {
                                // Copy to clipboard
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.link, size: 20, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.note.sourceUrl!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Source URL section (for web clipped notes)
                  if (widget.note.sourceUrl != null &&
                      widget.note.sourceUrl!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.link,
                                size: 18,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Source',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final url = widget.note.sourceUrl!;
                              final scaffoldMessenger = ScaffoldMessenger.of(
                                context,
                              );
                              try {
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Could not open URL'),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(content: Text('Invalid URL: $e')),
                                  );
                                }
                              }
                            },
                            child: Text(
                              widget.note.sourceUrl!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[700],
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Backlinks section
                  if (userId != null)
                    BacklinksSection(
                      userId: userId,
                      noteTitle: widget.note.title,
                      linkService: _linkService,
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Link autocomplete overlay
          if (userId != null)
            LinkAutocompleteDropdown(
              textController: _descriptionController,
              focusNode: _descriptionFocusNode,
              userId: userId,
              linkService: _linkService,
            ),
        ],
      ),
    );
  }
}

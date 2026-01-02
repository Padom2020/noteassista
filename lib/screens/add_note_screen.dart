import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/image_upload_service.dart';
import '../services/ai_tagging_service.dart';
import '../services/voice_service.dart';
import '../services/link_management_service.dart';
import '../services/ocr_service.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../models/template_model.dart';
import '../utils/timestamp_utils.dart';
import '../widgets/tag_suggestion_chip.dart';
import '../widgets/voice_capture_button.dart';
import '../widgets/link_autocomplete_dropdown.dart';
import '../widgets/image_thumbnail_grid.dart';
import '../widgets/drawing_thumbnail_grid.dart';
import '../screens/ocr_processing_screen.dart';
import '../screens/template_library_screen.dart';
import '../screens/drawing_screen.dart';
import '../widgets/save_as_template_dialog.dart';
import '../widgets/template_variable_input_dialog.dart';
import '../widgets/reminder_dialog.dart';
import '../widgets/feature_tooltip.dart';

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;
  final ImageUploadService _imageUploadService = ImageUploadService();
  final AITaggingService _aiTaggingService = AITaggingService();
  final VoiceService _voiceService = VoiceService();
  final LinkManagementService _linkService = LinkManagementService();
  final OCRService _ocrService = OCRService();

  int _selectedCategoryIndex = 0;
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;
  bool _isRecordingAudio = false;
  File? _selectedImage;
  final List<String> _tags = [];
  List<TagSuggestion> _tagSuggestions = [];
  final List<String> _audioUrls = [];
  String? _currentRecordingPath;
  final List<String> _ocrImagePaths = [];
  final List<String> _drawingUrls = [];

  // Folder selection
  String? _selectedFolderId;
  List<FolderModel> _folders = [];

  // Reminder
  ReminderModel? _reminder;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _tagsFocusNode = FocusNode();

  // Keys for feature tooltips
  final GlobalKey _ocrButtonKey = GlobalKey();
  final GlobalKey _templateButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Listen to text changes to generate tag suggestions
    _titleController.addListener(_onContentChanged);
    _descriptionController.addListener(_onContentChanged);
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      try {
        final result = await _supabaseService.getFolders();
        if (mounted && result.success && result.data != null) {
          setState(() {
            _folders = result.data!;
          });
        }
      } catch (e) {
        // Handle error silently for now
      }
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onContentChanged);
    _descriptionController.removeListener(_onContentChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _tagsFocusNode.dispose();
    _voiceService.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    // Debounce: wait 2 seconds after last keystroke before generating suggestions
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _generateTagSuggestions();
      }
    });
  }

  Future<void> _generateTagSuggestions() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    // Only generate suggestions if there's content
    if (title.isEmpty && description.isEmpty) {
      setState(() {
        _tagSuggestions = [];
      });
      return;
    }

    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final suggestions = await _aiTaggingService.generateTagSuggestions(
        '$title $description',
      );

      // Filter out tags that are already added
      final filteredSuggestions =
          suggestions
              .where((s) => !_tags.contains(s.tag.toLowerCase()))
              .toList();

      if (mounted) {
        setState(() {
          _tagSuggestions = filteredSuggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _addTag(String tag) {
    final normalizedTag = tag.trim().toLowerCase();
    if (normalizedTag.isEmpty || _tags.contains(normalizedTag)) {
      return;
    }

    setState(() {
      _tags.add(normalizedTag);
      // Remove accepted tag from suggestions
      _tagSuggestions.removeWhere((s) => s.tag == normalizedTag);
    });

    // Record tag acceptance for learning
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      _aiTaggingService.recordTagAcceptance(
        normalizedTag,
        '${_titleController.text} ${_descriptionController.text}',
      );
    }

    _tagsController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _selectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _selectedImage = null; // Clear custom image when selecting preset
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      File? image;
      if (source == ImageSource.gallery) {
        image = await _imageUploadService.pickImageFromGallery();
      } else {
        image = await _imageUploadService.pickImageFromCamera();
      }

      if (image != null) {
        setState(() {
          _selectedImage = image;
          _selectedCategoryIndex = -1; // Indicate custom image selected
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
    );
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

  Future<void> _createNote() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Get current user
    final userId = _authService.currentUser?.uid;
    debugPrint('AddNoteScreen: AuthService user ID: $userId');
    debugPrint(
      'AddNoteScreen: SupabaseService authenticated: ${_supabaseService.isAuthenticated}',
    );
    debugPrint(
      'AddNoteScreen: SupabaseService user ID: ${_supabaseService.currentUserId}',
    );

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
      // Save custom image locally if selected
      String? imagePath;
      if (_selectedImage != null) {
        imagePath = await _imageUploadService.saveImageLocally(
          _selectedImage!,
          userId,
        );
      }

      // Upload audio recording if exists
      if (_currentRecordingPath != null) {
        // Create a temporary note ID for storage organization
        final tempNoteId = DateTime.now().millisecondsSinceEpoch.toString();
        final audioUrl = await _voiceService.saveAudio(
          _currentRecordingPath!,
          userId,
          tempNoteId,
        );
        _audioUrls.add(audioUrl);
      }

      // Upload OCR images if exist
      final List<String> imageUrls = [];
      if (_ocrImagePaths.isNotEmpty) {
        final tempNoteId = DateTime.now().millisecondsSinceEpoch.toString();
        for (final imagePath in _ocrImagePaths) {
          final imageUrl = await _ocrService.uploadImage(
            imagePath,
            userId,
            tempNoteId,
          );
          imageUrls.add(imageUrl);
        }
      }

      // Generate timestamp
      final timestamp = generateTimestamp();

      // Calculate word count
      final wordCount =
          _descriptionController.text.trim().split(RegExp(r'\s+')).length;

      // Extract outgoing links from description
      final links = _linkService.parseLinks(_descriptionController.text.trim());
      final outgoingLinks =
          links.map((link) => link.targetTitle).toSet().toList();

      // Create note model
      final note = NoteModel(
        id: '', // ID will be generated by Firestore
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        timestamp: timestamp,
        categoryImageIndex:
            _selectedCategoryIndex >= 0 ? _selectedCategoryIndex : 0,
        isDone: false,
        customImageUrl: imagePath,
        tags: _tags,
        audioUrls: _audioUrls,
        imageUrls: imageUrls,
        drawingUrls: _drawingUrls,
        wordCount: wordCount,
        outgoingLinks: outgoingLinks,
        folderId: _selectedFolderId, // Set the selected folder
        reminder: _reminder, // Set the reminder
        ownerId: userId, // Set the owner
      );

      // Save to Supabase
      final result = await _supabaseService.createNote(note);
      if (!result.success) {
        throw Exception(result.error ?? 'Failed to create note');
      }

      // Navigate back to HomeScreen
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note created successfully'),
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
            content: Text('Error creating note: $e'),
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

    return Column(
      children: [
        GridView.builder(
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
        ),
        const SizedBox(height: 16),
        // Upload custom image button
        OutlinedButton.icon(
          onPressed: _showImageSourceDialog,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Upload Custom Image'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        // Show selected custom image preview
        if (_selectedImage != null) ...[
          const SizedBox(height: 12),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _selectedCategoryIndex = 0;
                        });
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _onVoiceTranscription(String transcription) {
    // Append transcription to description
    final currentText = _descriptionController.text;
    final newText =
        currentText.isEmpty ? transcription : '$currentText\n\n$transcription';
    _descriptionController.text = newText;

    // Generate title if empty
    if (_titleController.text.isEmpty) {
      String title;
      final firstSentenceEnd = transcription.indexOf('.');
      if (firstSentenceEnd != -1 && firstSentenceEnd < 50) {
        title = transcription.substring(0, firstSentenceEnd).trim();
      } else {
        title =
            transcription.length > 50
                ? '${transcription.substring(0, 50)}...'
                : transcription;
      }
      _titleController.text = title;
    }

    // Trigger tag suggestions
    _generateTagSuggestions();
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
      _ocrImagePaths.addAll(imagePaths);
    });

    // Trigger tag suggestions
    _generateTagSuggestions();
  }

  Future<void> _openDrawingScreen() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    // Create a temporary note ID for storage organization
    final tempNoteId = DateTime.now().millisecondsSinceEpoch.toString();

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => DrawingScreen(userId: userId, noteId: tempNoteId),
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

  Future<void> _openTemplateLibrary() async {
    final selectedTemplate = await Navigator.push<TemplateModel>(
      context,
      MaterialPageRoute(builder: (context) => const TemplateLibraryScreen()),
    );

    if (selectedTemplate != null) {
      await _applyTemplate(selectedTemplate);
    }
  }

  Future<void> _applyTemplate(TemplateModel template) async {
    // Check if template has variables
    if (template.variables.isNotEmpty) {
      // Show variable input dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => TemplateVariableInputDialog(
              variables: template.variables,
              onComplete: (values) {
                _applyTemplateWithValues(template, values);
              },
            ),
      );
    } else {
      // Apply template directly without variables
      _applyTemplateWithValues(template, {});
    }
  }

  void _applyTemplateWithValues(
    TemplateModel template,
    Map<String, String> values,
  ) {
    String content = template.content;

    // Replace all variables with user input
    for (final entry in values.entries) {
      final placeholder = '{{${entry.key}}}';
      content = content.replaceAll(placeholder, entry.value);
    }

    // Pre-populate the note with processed template content
    setState(() {
      if (_titleController.text.isEmpty) {
        _titleController.text = template.name;
      }
      _descriptionController.text = content;
    });

    // Increment template usage count
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      _supabaseService.incrementTemplateUsage(template.id).catchError((e) {
        // Handle error silently - usage count update is not critical
        return SupabaseOperationResult.failure('Template usage update failed');
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template "${template.name}" applied'),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Trigger tag suggestions after applying template
    _generateTagSuggestions();
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
                await _supabaseService.createTemplate(template);

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

  void _onDrawingAdded(String drawingUrl) {
    setState(() {
      _drawingUrls.add(drawingUrl);
    });
  }

  void _showReminderDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ReminderDialog(
            existingReminder: _reminder,
            onReminderSet: (reminder) {
              setState(() {
                _reminder = reminder;
              });
              if (reminder != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminder set successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
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

  void _onDrawingRemoved(int index) {
    setState(() {
      _drawingUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Note'),
        actions: [
          // Create from template button
          FeatureTooltip(
            tooltipId: 'template_library_feature',
            message: 'Use pre-built templates for common note types',
            direction: TooltipDirection.bottom,
            child: IconButton(
              key: _templateButtonKey,
              icon: const Icon(Icons.description_outlined),
              onPressed: _openTemplateLibrary,
              tooltip: 'Create from template',
            ),
          ),
          // Save as template button
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _saveAsTemplate,
            tooltip: 'Save as template',
          ),
          // Camera button for OCR
          FeatureTooltip(
            tooltipId: 'ocr_capture_feature',
            message: 'Capture photos to extract text automatically',
            direction: TooltipDirection.bottom,
            child: IconButton(
              key: _ocrButtonKey,
              icon: const Icon(Icons.camera_alt),
              onPressed: _captureImagesForOCR,
              tooltip: 'Capture image for text extraction',
            ),
          ),
          // Drawing button
          IconButton(
            icon: const Icon(Icons.brush),
            onPressed: _openDrawingScreen,
            tooltip: 'Create drawing',
          ),
          // Reminder button
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
          // Voice capture button in app bar
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
                  // Title field
                  TextFormField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Create from Template button
                  OutlinedButton.icon(
                    onPressed: _openTemplateLibrary,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Create from Template'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description field with link help
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Type [[ to link to another note',
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
                  const SizedBox(height: 16),

                  // Tags input field
                  TextFormField(
                    controller: _tagsController,
                    focusNode: _tagsFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Tags',
                      hintText: 'Add a tag and press Enter',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (_tagsController.text.isNotEmpty) {
                            _addTag(_tagsController.text);
                          }
                        },
                      ),
                    ),
                    onFieldSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _addTag(value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Display added tags
                  if (_tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _tags.map((tag) {
                            return Chip(
                              label: Text(tag),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _removeTag(tag),
                            );
                          }).toList(),
                    ),
                  if (_tags.isNotEmpty) const SizedBox(height: 8),

                  // Tag suggestions
                  TagSuggestionList(
                    suggestions: _tagSuggestions,
                    onTagAccepted: _addTag,
                    isLoading: _isLoadingSuggestions,
                  ),
                  const SizedBox(height: 24),

                  // Folder selection
                  const Text(
                    'Select Folder',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedFolderId,
                        isExpanded: true,
                        hint: const Row(
                          children: [
                            Icon(Icons.home, size: 18),
                            SizedBox(width: 8),
                            Text('Root Folder (No folder)'),
                          ],
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.home, size: 18),
                                SizedBox(width: 8),
                                Text('Root Folder (No folder)'),
                              ],
                            ),
                          ),
                          ..._folders.map((folder) {
                            return DropdownMenuItem<String?>(
                              value: folder.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        int.parse(
                                          folder.color.replaceFirst(
                                            '#',
                                            '0xFF',
                                          ),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      folder.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedFolderId = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category selection label
                  const Text(
                    'Select Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Category grid
                  _buildCategoryGrid(),
                  const SizedBox(height: 24),

                  // OCR Images section
                  if (_ocrImagePaths.isNotEmpty) ...[
                    ImageThumbnailGrid(
                      imageUrls: _ocrImagePaths,
                      isLocalPath: true,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Drawings section
                  if (userId != null) ...[
                    DrawingThumbnailGrid(
                      drawingUrls: _drawingUrls,
                      userId: userId,
                      noteId: DateTime.now().millisecondsSinceEpoch.toString(),
                      onDrawingAdded: _onDrawingAdded,
                      onDrawingRemoved: _onDrawingRemoved,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Audio recording section
                  const Text(
                    'Audio Attachment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Audio recording button
                  if (!_isRecordingAudio && _currentRecordingPath == null)
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

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createNote,
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
                              : const Text('Create Note'),
                    ),
                  ),
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

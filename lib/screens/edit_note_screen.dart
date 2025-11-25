import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/voice_service.dart';
import '../services/link_management_service.dart';
import '../models/note_model.dart';
import '../utils/timestamp_utils.dart';
import '../widgets/voice_capture_button.dart';
import '../widgets/audio_player_widget.dart';

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
  final FirestoreService _firestoreService = FirestoreService();
  final VoiceService _voiceService = VoiceService();
  final LinkManagementService _linkService = LinkManagementService();

  late int _selectedCategoryIndex;
  bool _isLoading = false;
  bool _isRecordingAudio = false;
  late List<String> _audioUrls;
  String? _currentRecordingPath;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _voiceService.dispose();
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
      // Delete from Firebase Storage
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
        final audioUrl = await _voiceService.uploadAudio(
          _currentRecordingPath!,
          userId,
          widget.note.id,
        );
        _audioUrls.add(audioUrl);
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
        wordCount: wordCount,
        outgoingLinks: outgoingLinks,
        // Preserve other fields
        tags: widget.note.tags,
        isPinned: widget.note.isPinned,
        customImageUrl: widget.note.customImageUrl,
        imageUrls: widget.note.imageUrls,
        drawingUrls: widget.note.drawingUrls,
        folderId: widget.note.folderId,
        isShared: widget.note.isShared,
        collaboratorIds: widget.note.collaboratorIds,
        sourceUrl: widget.note.sourceUrl,
        reminder: widget.note.reminder,
        viewCount: widget.note.viewCount,
        createdAt: widget.note.createdAt,
      );

      // Update in Firestore
      await _firestoreService.updateNote(userId, widget.note.id, updatedNote);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Note'),
        actions: [
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
      body: SingleChildScrollView(
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

              // Description field
              TextFormField(
                controller: _descriptionController,
                focusNode: _descriptionFocusNode,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
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
                      onDelete: () => _removeAudioUrl(url),
                    ),
                  );
                }),

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
                      Icon(Icons.fiber_manual_record, color: Colors.red[700]),
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

              // Update button
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
            ],
          ),
        ),
      ),
    );
  }
}

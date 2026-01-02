import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../models/note_model.dart';
import '../utils/timestamp_utils.dart';

/// Full-screen voice capture interface for creating notes via speech
class VoiceCaptureScreen extends StatefulWidget {
  const VoiceCaptureScreen({super.key});

  @override
  State<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends State<VoiceCaptureScreen>
    with SingleTickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isRecording = false;
  String _transcription = '';
  String? _errorMessage;
  int _recordingDuration = 0;
  Timer? _durationTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Setup pulsing animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Auto-start recording when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _animationController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _errorMessage = null;
      _transcription = '';
      _recordingDuration = 0;
    });

    try {
      // Check if speech recognition is available
      final available = await _voiceService.isAvailable();
      if (!available) {
        setState(() {
          _errorMessage = 'Speech recognition not available on this device';
        });
        return;
      }

      // Start listening
      await _voiceService.startListening((transcription) {
        if (mounted) {
          setState(() {
            _transcription = transcription;
          });
        }
      });

      setState(() {
        _isRecording = true;
      });

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });

          // Auto-stop at 5 minutes (300 seconds)
          if (_recordingDuration >= 300) {
            _stopRecording();
          }
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();

    try {
      final finalTranscription = await _voiceService.stopListening();

      setState(() {
        _isRecording = false;
        _transcription = finalTranscription;
      });

      if (finalTranscription.isEmpty) {
        setState(() {
          _errorMessage = 'No speech detected. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isRecording = false;
      });
    }
  }

  Future<void> _saveNote() async {
    if (_transcription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transcription to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Generate title from first sentence or first 50 characters
      String title;
      final firstSentenceEnd = _transcription.indexOf('.');
      if (firstSentenceEnd != -1 && firstSentenceEnd < 50) {
        title = _transcription.substring(0, firstSentenceEnd).trim();
      } else {
        title =
            _transcription.length > 50
                ? '${_transcription.substring(0, 50)}...'
                : _transcription;
      }

      // Create note
      final note = NoteModel(
        id: '',
        title: title,
        description: _transcription,
        timestamp: generateTimestamp(),
        categoryImageIndex: 0,
        isDone: false,
        ownerId: userId, // Set the owner
      );

      await _supabaseService.createNote(note);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice note created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString();
    if (errorString.contains('permission denied')) {
      return 'Microphone permission denied. Please enable it in settings.';
    } else if (errorString.contains('not available')) {
      return 'Speech recognition not available on this device.';
    } else {
      return 'Failed to recognize speech. Please try again.';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Voice Capture',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),

              // Pulsing microphone icon
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _isRecording ? _opacityAnimation.value : 1.0,
                    child: Transform.scale(
                      scale: _isRecording ? _scaleAnimation.value : 1.0,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _isRecording ? Colors.red[400] : Colors.grey[700],
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _isRecording
                                      ? Colors.red.withValues(alpha: 0.5)
                                      : Colors.grey.withValues(alpha: 0.3),
                              blurRadius: _isRecording ? 40 : 20,
                              spreadRadius: _isRecording ? 10 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.mic : Icons.mic_off,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Recording timer
              if (_isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_recordingDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Tap to start recording',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),

              const SizedBox(height: 24),

              // Status text
              Text(
                _isRecording ? 'Listening...' : 'Ready',
                style: TextStyle(
                  color: _isRecording ? Colors.red[400] : Colors.grey[400],
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              // Transcription display
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[700]!, width: 1),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _transcription.isEmpty
                        ? 'Your transcription will appear here...'
                        : _transcription,
                    style: TextStyle(
                      color:
                          _transcription.isEmpty
                              ? Colors.grey[600]
                              : Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),

              // Error message display
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[900]?.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[700]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[400],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[200],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Stop/Start button
                  if (_isRecording)
                    ElevatedButton.icon(
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.mic),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),

                  // Save button
                  if (!_isRecording && _transcription.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveNote,
                      icon:
                          _isSaving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

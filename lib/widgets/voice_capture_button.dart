import 'package:flutter/material.dart';
import '../services/voice_service.dart';

/// A button widget for voice capture with pulsing animation and real-time transcription
class VoiceCaptureButton extends StatefulWidget {
  final Function(String) onTranscriptionComplete;
  final VoiceService? voiceService;

  const VoiceCaptureButton({
    super.key,
    required this.onTranscriptionComplete,
    this.voiceService,
  });

  @override
  State<VoiceCaptureButton> createState() => _VoiceCaptureButtonState();
}

class _VoiceCaptureButtonState extends State<VoiceCaptureButton>
    with SingleTickerProviderStateMixin {
  late VoiceService _voiceService;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isRecording = false;
  String _transcription = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _voiceService = widget.voiceService ?? VoiceService();

    // Setup pulsing animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (widget.voiceService == null) {
      _voiceService.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _errorMessage = null;
      _transcription = '';
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
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final finalTranscription = await _voiceService.stopListening();

      setState(() {
        _isRecording = false;
        _transcription = finalTranscription;
      });

      // Call the callback with the final transcription
      if (finalTranscription.isNotEmpty) {
        widget.onTranscriptionComplete(finalTranscription);
      } else {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Voice capture button with pulsing animation
        GestureDetector(
          onTap: _toggleRecording,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isRecording ? _scaleAnimation.value : 1.0,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _isRecording
                            ? Colors.red[400]
                            : Theme.of(context).colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color:
                            _isRecording
                                ? Colors.red.withValues(alpha: 0.4)
                                : Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: _isRecording ? 20 : 8,
                        spreadRadius: _isRecording ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Recording status text
        if (_isRecording)
          Text(
            'Listening...',
            style: TextStyle(
              color: Colors.red[400],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),

        // Real-time transcription display
        if (_transcription.isNotEmpty && _isRecording)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              _transcription,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),

        // Error message display
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: 13, color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service for handling voice-to-text conversion and audio recording
class VoiceService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  late final Record _audioRecorder;

  final StreamController<String> _transcriptionController =
      StreamController<String>.broadcast();

  String _currentTranscription = '';
  bool _isListening = false;
  bool _isRecording = false;
  String? _currentRecordingPath;

  VoiceService() {
    _audioRecorder = Record();
  }

  /// Check if speech recognition is available on the device
  Future<bool> isAvailable() async {
    try {
      return await _speechToText.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
      );
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
      return false;
    }
  }

  /// Start listening for speech input
  /// [onResult] callback is called with transcription updates
  Future<void> startListening(Function(String) onResult) async {
    if (_isListening) {
      debugPrint('Already listening');
      return;
    }

    // Request microphone permission
    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      throw Exception('Microphone permission denied');
    }

    // Initialize speech recognition if not already done
    final available = await isAvailable();
    if (!available) {
      throw Exception('Speech recognition not available on this device');
    }

    _currentTranscription = '';
    _isListening = true;

    try {
      await _speechToText.listen(
        onResult: (result) {
          _currentTranscription = result.recognizedWords;
          _transcriptionController.add(_currentTranscription);
          onResult(_currentTranscription);
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
        onSoundLevelChange: (level) {
          // Can be used for visual feedback
          debugPrint('Sound level: $level');
        },
      );
    } catch (e) {
      _isListening = false;
      debugPrint('Error starting speech recognition: $e');
      throw Exception('Failed to start speech recognition: $e');
    }
  }

  /// Stop listening and finalize transcription
  /// Returns the final transcribed text
  Future<String> stopListening() async {
    if (!_isListening) {
      return _currentTranscription;
    }

    try {
      await _speechToText.stop();
      _isListening = false;
      return _currentTranscription;
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
      _isListening = false;
      return _currentTranscription;
    }
  }

  /// Get real-time transcription updates as a stream
  Stream<String> getTranscriptionStream() {
    return _transcriptionController.stream;
  }

  /// Record audio for attachment
  /// [maxDuration] maximum recording duration (default: 10 minutes)
  /// Returns the local file path of the recorded audio
  Future<String> recordAudio({
    Duration maxDuration = const Duration(minutes: 10),
  }) async {
    if (_isRecording) {
      throw Exception('Already recording');
    }

    // Request microphone permission
    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      throw Exception('Microphone permission denied');
    }

    try {
      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/audio_$timestamp.m4a';

      _isRecording = true;

      // Start recording with path
      await _audioRecorder.start(path: _currentRecordingPath!);

      // Auto-stop after max duration
      Future.delayed(maxDuration, () async {
        if (_isRecording) {
          await stopRecording();
        }
      });

      return _currentRecordingPath!;
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      _isRecording = false;
      throw Exception('Failed to start audio recording: $e');
    }
  }

  /// Stop audio recording
  /// Returns the local file path of the recorded audio
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      final result = await _audioRecorder.stop();
      _isRecording = false;
      return result ?? _currentRecordingPath;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _isRecording = false;
      throw Exception('Failed to stop audio recording: $e');
    }
  }

  /// Save audio file locally (audio upload to cloud storage not implemented)
  /// [localPath] path to the local audio file
  /// [userId] user ID for organizing storage
  /// [noteId] note ID for organizing storage
  /// Returns the local file path (audio files are kept locally)
  Future<String> saveAudio(
    String localPath,
    String userId,
    String noteId,
  ) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found at $localPath');
      }

      // Create permanent local directory for audio files
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/audio/$userId/$noteId');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'audio_$timestamp.m4a';
      final permanentPath = '${audioDir.path}/$fileName';

      // Copy to permanent location
      await file.copy(permanentPath);

      // Clean up temp file
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Warning: Could not delete temp audio file: $e');
      }

      debugPrint('Audio saved locally: $permanentPath');
      return 'file://$permanentPath';
    } catch (e) {
      debugPrint('Error saving audio: $e');
      throw Exception('Failed to save audio: $e');
    }
  }

  /// Delete audio file from local storage
  /// [audioUrl] the local file URL of the audio to delete
  Future<void> deleteAudio(String audioUrl) async {
    try {
      if (audioUrl.startsWith('file://')) {
        final filePath = audioUrl.substring(7);
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Audio file deleted: $filePath');
        }
      }
    } catch (e) {
      debugPrint('Error deleting audio: $e');
      throw Exception('Failed to delete audio: $e');
    }
  }

  /// Check if currently listening for speech
  bool get isListening => _isListening;

  /// Check if currently recording audio
  bool get isRecording => _isRecording;

  /// Get current transcription text
  String get currentTranscription => _currentTranscription;

  /// Dispose resources
  Future<void> dispose() async {
    await _speechToText.stop();
    await _audioRecorder.dispose();
    await _transcriptionController.close();
  }
}

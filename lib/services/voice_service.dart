import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service for handling voice-to-text conversion and audio recording
class VoiceService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final StreamController<String> _transcriptionController =
      StreamController<String>.broadcast();

  String _currentTranscription = '';
  bool _isListening = false;
  bool _isRecording = false;
  String? _currentRecordingPath;

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
      // Initialize recorder
      await _audioRecorder.openRecorder();

      // Configure noise suppression and echo cancellation
      await _audioRecorder.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/audio_$timestamp.aac';

      // Start recording with AAC codec for better compression
      await _audioRecorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
        bitRate: 128000, // 128 kbps for good quality with compression
        sampleRate: 44100,
      );

      _isRecording = true;

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
      await _audioRecorder.stopRecorder();
      await _audioRecorder.closeRecorder();
      _isRecording = false;
      return _currentRecordingPath;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _isRecording = false;
      throw Exception('Failed to stop audio recording: $e');
    }
  }

  /// Upload audio file to Firebase Storage
  /// [localPath] path to the local audio file
  /// [userId] user ID for organizing storage
  /// [noteId] note ID for organizing storage
  /// Returns the download URL of the uploaded audio
  Future<String> uploadAudio(
    String localPath,
    String userId,
    String noteId,
  ) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found at $localPath');
      }

      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'audio_$timestamp.aac';
      final storagePath = 'users/$userId/notes/$noteId/audio/$fileName';

      // Upload to Firebase Storage
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'audio/aac',
          customMetadata: {
            'userId': userId,
            'noteId': noteId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Clean up local file
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Warning: Could not delete local audio file: $e');
      }

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading audio: $e');
      throw Exception('Failed to upload audio: $e');
    }
  }

  /// Delete audio file from Firebase Storage
  /// [audioUrl] the download URL of the audio to delete
  Future<void> deleteAudio(String audioUrl) async {
    try {
      final ref = _storage.refFromURL(audioUrl);
      await ref.delete();
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
  void dispose() {
    _speechToText.stop();
    if (_isRecording) {
      _audioRecorder.stopRecorder();
    }
    _audioRecorder.closeRecorder();
    _transcriptionController.close();
  }
}

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/cloudinary_config.dart';

/// Service for handling image uploads to Cloudinary using direct HTTP calls
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  /// Upload image file to Cloudinary
  ///
  /// Returns the secure URL of the uploaded image
  Future<CloudinaryUploadResult> uploadImage({
    required File imageFile,
    required String userId,
    required String noteId,
    String? fileName,
  }) async {
    try {
      if (!CloudinaryConfig.isConfigured) {
        return CloudinaryUploadResult(
          success: false,
          errorMessage: 'Cloudinary not configured',
        );
      }

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      return await uploadImageFromBytes(
        imageBytes: bytes,
        userId: userId,
        noteId: noteId,
        fileName: fileName,
      );
    } catch (e) {
      debugPrint('Cloudinary file upload error: $e');
      return CloudinaryUploadResult(success: false, errorMessage: e.toString());
    }
  }

  /// Upload image from bytes to Cloudinary
  Future<CloudinaryUploadResult> uploadImageFromBytes({
    required Uint8List imageBytes,
    required String userId,
    required String noteId,
    String? fileName,
  }) async {
    try {
      if (!CloudinaryConfig.isConfigured) {
        return CloudinaryUploadResult(
          success: false,
          errorMessage: 'Cloudinary not configured',
        );
      }

      // Create a unique public ID for the image
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = fileName ?? 'drawing_${noteId}_$timestamp';

      // Create folder structure: users/userId/drawings/
      final folder = 'users/$userId/drawings';
      final fullPublicId = '$folder/$publicId';

      debugPrint('Uploading to Cloudinary: $fullPublicId');

      // Prepare multipart request
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
      );
      final request = http.MultipartRequest('POST', uri);

      // Add form fields
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.fields['public_id'] = fullPublicId;
      request.fields['folder'] = folder;

      // Add file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: '$publicId.png',
        ),
      );

      debugPrint('Sending request to Cloudinary...');

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Cloudinary response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        debugPrint(
          'Cloudinary upload successful: ${responseData['secure_url']}',
        );

        return CloudinaryUploadResult(
          success: true,
          secureUrl: responseData['secure_url'],
          publicId: responseData['public_id'],
          width: responseData['width'],
          height: responseData['height'],
          format: responseData['format'],
          bytes: responseData['bytes'],
        );
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Upload failed';

        debugPrint('Cloudinary upload failed: $errorMessage');

        return CloudinaryUploadResult(
          success: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return CloudinaryUploadResult(success: false, errorMessage: e.toString());
    }
  }

  /// Delete image from Cloudinary
  Future<bool> deleteImage(String publicId) async {
    try {
      if (!CloudinaryConfig.isConfigured) {
        return false;
      }

      // Note: Deletion requires signed requests with API secret
      // For unsigned uploads, deletion is typically handled server-side
      debugPrint('Cloudinary deletion not implemented for unsigned uploads');
      return false;
    } catch (e) {
      debugPrint('Cloudinary delete error: $e');
      return false;
    }
  }

  /// Generate optimized URL for an image
  ///
  /// This allows you to get different sizes/formats of the same image
  String getOptimizedUrl({
    required String publicId,
    int? width,
    int? height,
    String? format,
    int? quality,
  }) {
    if (!CloudinaryConfig.isConfigured) {
      return '';
    }

    final baseUrl =
        'https://res.cloudinary.com/${CloudinaryConfig.cloudName}/image/upload';
    final transformations = <String>[];

    if (width != null || height != null) {
      final w = width != null ? 'w_$width' : '';
      final h = height != null ? 'h_$height' : '';
      final crop = 'c_fill';
      transformations.add([w, h, crop].where((s) => s.isNotEmpty).join(','));
    }

    if (quality != null) {
      transformations.add('q_$quality');
    }

    if (format != null) {
      transformations.add('f_$format');
    }

    final transformationString =
        transformations.isNotEmpty ? '/${transformations.join('/')}' : '';

    return '$baseUrl$transformationString/$publicId';
  }

  /// Get thumbnail URL for an image
  String getThumbnailUrl(String publicId, {int size = 150}) {
    return getOptimizedUrl(
      publicId: publicId,
      width: size,
      height: size,
      quality: 80,
    );
  }

  /// Check if Cloudinary is properly configured
  bool isConfigured() {
    return CloudinaryConfig.isConfigured;
  }
}

/// Result class for Cloudinary upload operations
class CloudinaryUploadResult {
  final bool success;
  final String? secureUrl;
  final String? publicId;
  final int? width;
  final int? height;
  final String? format;
  final int? bytes;
  final String? errorMessage;

  CloudinaryUploadResult({
    required this.success,
    this.secureUrl,
    this.publicId,
    this.width,
    this.height,
    this.format,
    this.bytes,
    this.errorMessage,
  });

  @override
  String toString() {
    if (success) {
      return 'CloudinaryUploadResult(success: true, url: $secureUrl, size: ${width}x$height)';
    } else {
      return 'CloudinaryUploadResult(success: false, error: $errorMessage)';
    }
  }
}

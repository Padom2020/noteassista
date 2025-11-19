import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ImageUploadService {
  final ImagePicker _picker = ImagePicker();

  // Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      throw Exception('Failed to pick image');
    }
  }

  // Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      throw Exception('Failed to take photo');
    }
  }

  // Save image locally and return the local path
  Future<String> saveImageLocally(File imageFile, String userId) async {
    try {
      // Get app's document directory
      final Directory appDir = await getApplicationDocumentsDirectory();

      // Create note_images directory if it doesn't exist
      final Directory noteImagesDir = Directory(
        '${appDir.path}/note_images/$userId',
      );
      if (!await noteImagesDir.exists()) {
        await noteImagesDir.create(recursive: true);
      }

      // Create unique filename
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String localPath = '${noteImagesDir.path}/$fileName';

      // Copy image to app directory
      final File savedImage = await imageFile.copy(localPath);

      return savedImage.path;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      throw Exception('Failed to save image');
    }
  }

  // Convert image to base64 string for Firestore storage
  Future<String> imageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error converting image to base64: $e');
      throw Exception('Failed to convert image');
    }
  }

  // Delete local image file
  Future<void> deleteLocalImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (e) {
      debugPrint('Error deleting local image: $e');
      // Don't throw error, just log it
    }
  }

  // Get File from local path
  File? getImageFile(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    final file = File(imagePath);
    return file.existsSync() ? file : null;
  }
}

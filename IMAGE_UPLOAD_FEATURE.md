# Image Upload Feature

## What Was Added

Users can now upload custom images to their notes instead of just selecting from the 5 preset category images.

## Features

1. **Upload from Gallery or Camera**
   - Users can choose to pick an image from their gallery or take a new photo with the camera
   - Images are automatically resized to 1024x1024 max and compressed to 85% quality

2. **Image Storage (Local)**
   - Custom images are saved locally on the device
   - Each image is stored with a unique filename: `{app_directory}/note_images/{userId}/{timestamp}.jpg`
   - Local file paths are saved in the note document
   - **No Firebase Storage required** - works without any Firebase upgrade!

3. **Image Display**
   - Custom images are displayed in note cards on the home screen
   - If a custom image exists, it's shown instead of the preset category image
   - Fast loading from local storage
   - Fallback to icon if image file is missing

## How to Use

### Creating a Note with Custom Image

1. Open "Add Note" screen
2. Click "Upload Custom Image" button
3. Choose "Gallery" or "Camera"
4. Select/take your image
5. Preview appears below the button
6. Fill in title and description
7. Click "Create Note"

### Removing Custom Image

- Click the X button on the image preview to remove it
- This will revert to using the selected preset category image

## Technical Details

### New Dependencies
- `image_picker: ^1.0.7` - For picking images from gallery/camera
- `path_provider: ^2.1.1` - For accessing device storage directories

### New Files
- `lib/services/image_upload_service.dart` - Handles image picking and uploading

### Modified Files
- `lib/models/note_model.dart` - Added `customImageUrl` field
- `lib/screens/add_note_screen.dart` - Added image upload UI and logic
- `lib/screens/home_screen.dart` - Added custom image display support
- `pubspec.yaml` - Added new dependencies

### Data Model Changes
```dart
class NoteModel {
  // ... existing fields
  final String? customImageUrl; // NEW: URL for user-uploaded image
}
```

## Firebase Setup Required

Make sure Firebase Storage is enabled in your Firebase Console:
1. Go to Firebase Console
2. Select your project
3. Navigate to Storage
4. Click "Get Started"
5. Set up security rules (default rules are fine for testing)

## Next Steps

To also add image upload to the Edit Note screen, similar changes would need to be made to `lib/screens/edit_note_screen.dart`.

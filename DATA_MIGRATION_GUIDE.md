# Data Migration Guide

## Overview

The NoteAssista app includes an automatic data migration system that updates existing user data to support new advanced features. This migration runs automatically when users open the app after an update.

## What Gets Migrated

### 1. Existing Notes
The migration adds new fields to all existing notes with default values:

- **Array Fields** (default: empty arrays `[]`):
  - `outgoingLinks` - Links to other notes
  - `audioUrls` - Audio attachment URLs
  - `imageUrls` - Image attachment URLs
  - `drawingUrls` - Drawing attachment URLs
  - `collaboratorIds` - List of collaborator user IDs (deprecated)
  - `collaborators` - List of collaborator objects with roles

- **Nullable Fields** (default: `null`):
  - `folderId` - Parent folder ID
  - `sourceUrl` - Source URL for web-clipped content
  - `reminder` - Reminder configuration object
  - `ownerId` - Owner user ID (set to current user)

- **Boolean Fields** (default: `false`):
  - `isShared` - Whether note is shared with collaborators

- **Numeric Fields** (default: `0`):
  - `viewCount` - Number of times note has been viewed
  - `wordCount` - Calculated from note description

### 2. Default Folders
If a user has no folders, the migration creates three default folders:

- **Personal** (Blue) - For personal notes
- **Work** (Green) - For work-related notes
- **Ideas** (Amber) - For ideas and brainstorming

### 3. Default Templates
If a user has no templates, the migration creates five predefined templates:

- **Meeting Notes** - For capturing meeting discussions and action items
- **Project Plan** - For planning and tracking project progress
- **Daily Journal** - For daily reflection and planning
- **Book Notes** - For capturing insights from books
- **Recipe** - For documenting cooking recipes

## How Migration Works

### Automatic Execution

1. When a user logs in and opens the home screen, the app checks if migration is needed
2. If needed, migration runs automatically in the background
3. Users see a success message showing what was migrated
4. The app continues to function normally during migration

### Migration Process

```dart
// Check if migration is needed
final migrationService = MigrationService();
final needsMigration = await migrationService.needsMigration(userId);

if (needsMigration) {
  // Run all migrations
  final result = await migrationService.runMigrations(userId);
  
  // Check results
  print('Notes updated: ${result.notesUpdated}');
  print('Folders created: ${result.foldersCreated}');
  print('Templates created: ${result.templatesCreated}');
}
```

### Batch Processing

- Notes are processed in batches of 500 to respect Firestore limits
- Large datasets are handled efficiently without timeouts
- Progress is logged for debugging

## Migration Safety

### Non-Destructive
- Migration only **adds** new fields, never removes or modifies existing data
- If a field already exists, it's left unchanged
- Users can continue using the app during migration

### Error Handling
- Errors are logged but don't block app usage
- Partial migrations are supported (some notes can succeed while others fail)
- Failed migrations can be retried on next app launch

### Idempotent
- Migration can be run multiple times safely
- Already-migrated data is skipped
- No duplicate folders or templates are created

## Testing Migration

### Manual Testing

To test migration with sample data:

```dart
// Create test user with old data structure
final testUserId = 'test-user-123';

// Run migration
final migrationService = MigrationService();
final result = await migrationService.runMigrations(testUserId);

// Verify results
assert(result.success);
assert(result.notesUpdated > 0);
```

### Unit Tests

Run the migration service tests:

```bash
flutter test test/migration_service_test.dart
```

## Monitoring Migration

### Debug Logs

Migration progress is logged to the console:

```
Starting migration for user: abc123
Found 150 notes to migrate
Committed batch: 150 notes updated
Total notes migrated: 150
Created 3 default folders
Created 5 default templates
Migration completed for user: abc123
```

### User Feedback

Users see a snackbar message after successful migration:

```
App updated! 150 notes migrated, 3 folders created, 5 templates added.
```

## Troubleshooting

### Migration Not Running

If migration doesn't run automatically:

1. Check that user is logged in
2. Verify Firebase connection
3. Check console logs for errors
4. Ensure Firestore security rules allow updates

### Partial Migration

If some notes fail to migrate:

1. Check Firestore security rules
2. Verify note data structure
3. Review error logs
4. Migration will retry on next app launch

### Performance Issues

For users with thousands of notes:

1. Migration runs in batches of 500
2. Background processing doesn't block UI
3. Large datasets may take a few seconds
4. Progress is logged for monitoring

## Future Migrations

To add new migrations in the future:

1. Add new migration method to `MigrationService`
2. Call it from `runMigrations()` method
3. Update `needsMigration()` to check for new fields
4. Test thoroughly before deployment
5. Update this documentation

## Code Location

- **Migration Service**: `lib/services/migration_service.dart`
- **Migration Tests**: `test/migration_service_test.dart`
- **Integration**: `lib/screens/home_screen.dart` (initState)

## Related Documentation

- [Firestore Data Structure](lib/services/firestore_service.dart)
- [Note Model](lib/models/note_model.dart)
- [Folder Model](lib/models/folder_model.dart)
- [Template Model](lib/models/template_model.dart)

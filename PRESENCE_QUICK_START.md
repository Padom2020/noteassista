# Presence Feature Quick Start Guide

## What Was Built

Task 16 is complete! The Firebase Realtime Database presence system is now ready for collaborative editing features.

## Quick Setup (3 Steps)

### Step 1: Enable Realtime Database
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **noteassist-9dd81**
3. Navigate to **Build** → **Realtime Database**
4. Click **Create Database**
5. Choose your region (same as Firestore)
6. Start in **locked mode**

### Step 2: Deploy Security Rules
```bash
firebase deploy --only database
```

### Step 3: Verify
Check Firebase Console → Realtime Database → Rules tab to confirm deployment.

## How to Use in Code

```dart
import 'package:noteassista/services/presence_service.dart';

final presenceService = PresenceService();

// When user opens a note
await presenceService.initializePresence(noteId);

// When user starts editing
await presenceService.markAsEditing(noteId);

// Update cursor position
await presenceService.updateCursorPosition(noteId, 42);

// Watch active users (real-time)
presenceService.watchPresence(noteId).listen((users) {
  print('Active users: ${users.length}');
  users.forEach((userId, data) {
    print('${data['displayName']} is ${data['status']}');
  });
});

// When user leaves
await presenceService.removePresence(noteId);
```

## What's Next

This presence system will be used in:
- **Task 17**: Collaboration Service (operational transform)
- **Task 19**: Collaboration UI (showing active users, cursors)

## Files to Review

- `lib/services/presence_service.dart` - Main service implementation
- `database.rules.json` - Security rules
- `REALTIME_DATABASE_SETUP.md` - Detailed documentation
- `TASK_16_COMPLETION_SUMMARY.md` - Complete implementation details

## Key Features

✓ Real-time presence tracking
✓ Automatic cleanup on disconnect
✓ Cursor position tracking
✓ Status updates (viewing/editing/away)
✓ Secure (users can only write their own data)
✓ Stale data cleanup (>5 minutes)

## Need Help?

See `REALTIME_DATABASE_SETUP.md` for:
- Detailed setup instructions
- Troubleshooting guide
- Performance considerations
- Integration examples

# Firebase Realtime Database Setup for Presence

This document explains how to set up Firebase Realtime Database for the presence feature in NoteAssista.

## Overview

The presence feature uses Firebase Realtime Database to track which users are currently viewing or editing notes in real-time. This enables collaborative features like showing active collaborators, cursor positions, and edit status.

## Prerequisites

- Firebase project already set up for NoteAssista
- Firebase CLI installed (`npm install -g firebase-tools`)
- Authenticated with Firebase CLI (`firebase login`)

## Setup Steps

### 1. Enable Firebase Realtime Database in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your NoteAssista project
3. Navigate to **Build** → **Realtime Database**
4. Click **Create Database**
5. Choose a database location (select the same region as your Firestore for best performance)
6. Start in **locked mode** (we'll deploy custom rules next)

### 2. Initialize Firebase in Your Project (if not already done)

```bash
firebase init database
```

- Select your Firebase project
- Accept the default database rules file name (`database.rules.json`)

### 3. Deploy Security Rules

The security rules are already defined in `database.rules.json`. Deploy them:

```bash
firebase deploy --only database
```

### 4. Verify Setup

After deployment, verify the rules in Firebase Console:
1. Go to **Realtime Database** → **Rules** tab
2. Confirm the rules match the content in `database.rules.json`

## Data Structure

The presence data is organized as follows:

```
presence/
  {noteId}/
    {userId}/
      status: "viewing" | "editing" | "away"
      cursorPosition: number
      lastSeen: timestamp (milliseconds since epoch)
      displayName: string
      email: string
```

### Example Data

```json
{
  "presence": {
    "note123": {
      "user456": {
        "status": "editing",
        "cursorPosition": 42,
        "lastSeen": 1700000000000,
        "displayName": "John Doe",
        "email": "john@example.com"
      },
      "user789": {
        "status": "viewing",
        "cursorPosition": 0,
        "lastSeen": 1700000001000,
        "displayName": "Jane Smith",
        "email": "jane@example.com"
      }
    }
  }
}
```

## Security Rules Explanation

The security rules in `database.rules.json` enforce:

1. **Authentication Required**: Only authenticated users can read/write presence data
2. **User Isolation**: Users can only write their own presence data (enforced by `auth.uid == $userId`)
3. **Data Validation**: 
   - Required fields: `status`, `lastSeen`, `displayName`, `email`
   - `status` must be one of: "viewing", "editing", "away"
   - `cursorPosition` must be a number
   - `lastSeen` must be a number (timestamp)
   - `displayName` and `email` must be strings

## Usage in Code

The `PresenceService` class (`lib/services/presence_service.dart`) provides methods to:

- **Initialize presence**: Set up presence when user opens a note
- **Update status**: Change between viewing/editing/away
- **Update cursor position**: Track where user is editing
- **Watch presence**: Listen to real-time updates of all active users
- **Cleanup**: Remove presence when user leaves or disconnects

### Example Usage

```dart
final presenceService = PresenceService();

// When user opens a note
await presenceService.initializePresence(noteId);

// When user starts editing
await presenceService.markAsEditing(noteId);

// Update cursor position
await presenceService.updateCursorPosition(noteId, 42);

// Listen to active users
presenceService.watchPresence(noteId).listen((users) {
  print('Active users: ${users.length}');
  users.forEach((userId, data) {
    print('${data['displayName']} is ${data['status']}');
  });
});

// When user leaves the note
await presenceService.removePresence(noteId);
```

## Automatic Cleanup

The presence service includes automatic cleanup mechanisms:

1. **On Disconnect**: Firebase automatically removes presence data when a user's connection is lost
2. **Stale Data Cleanup**: The `cleanupStalePresence()` method removes presence data for users inactive for more than 5 minutes
3. **Manual Removal**: Presence is explicitly removed when users navigate away from a note

## Performance Considerations

- Presence updates are lightweight and use minimal bandwidth
- Real-time listeners only subscribe to specific note presence data
- Cursor position updates are throttled in the UI to avoid excessive writes
- Stale presence cleanup runs periodically to keep the database clean

## Monitoring

Monitor your Realtime Database usage in Firebase Console:
1. Go to **Realtime Database** → **Usage** tab
2. Check concurrent connections, bandwidth, and storage
3. Set up billing alerts if needed

## Troubleshooting

### Issue: "Permission denied" errors

**Solution**: Ensure security rules are deployed correctly:
```bash
firebase deploy --only database
```

### Issue: Presence data not updating

**Solution**: 
1. Check that user is authenticated
2. Verify Firebase Realtime Database is enabled in console
3. Check browser console for connection errors

### Issue: Stale presence data

**Solution**: Call `cleanupStalePresence()` periodically or implement a Cloud Function to clean up automatically.

## Next Steps

After setting up the Realtime Database:
1. Implement the Collaboration Service (Task 17)
2. Build collaboration UI components (Task 19)
3. Test real-time presence updates with multiple users

## References

- [Firebase Realtime Database Documentation](https://firebase.google.com/docs/database)
- [Security Rules Documentation](https://firebase.google.com/docs/database/security)
- [Presence System Guide](https://firebase.google.com/docs/database/web/offline-capabilities#section-presence)

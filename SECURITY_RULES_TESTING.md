# Security Rules Testing Guide

This document explains how to test the Firestore and Realtime Database security rules for NoteAssista.

## Overview

The security rules have been updated to support:
1. **Folders subcollection** - User-specific folder management
2. **Templates subcollection** - User-specific template management
3. **Collaboration access** - Shared notes with role-based permissions
4. **Presence data** - Real-time user presence in Realtime Database

## Security Rules Structure

### Firestore Rules

#### Notes Collection
- **Owner**: Full read/write access to their own notes
- **Collaborators**: 
  - Can read shared notes if they're in the collaborators list
  - Can write if they have 'editor' or 'owner' role
  - Cannot delete notes (only owner can delete)

#### Folders Collection
- **Owner**: Full read/write/delete access to their own folders
- **Other users**: No access

#### Templates Collection
- **Owner**: Full read/write/delete access to their own templates
- **Other users**: No access

### Realtime Database Rules (Presence)

- **Read**: Any authenticated user can read presence data for a note
- **Write**: Users can only write their own presence data
- **Validation**: Ensures required fields (status, lastSeen, displayName, email) are present

## Testing with Firebase Emulator

### Prerequisites

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

2. Login to Firebase:
```bash
firebase login
```

3. Initialize Firebase in your project (if not already done):
```bash
firebase init
```

### Running the Emulator

1. Start the Firebase emulators:
```bash
firebase emulators:start
```

This will start:
- Firestore Emulator on port 8080
- Realtime Database Emulator on port 9000
- Emulator UI on port 4000

2. Access the Emulator UI:
Open your browser to `http://localhost:4000`

### Testing Security Rules in Emulator UI

#### Test Firestore Rules

1. Navigate to the Firestore tab in the Emulator UI
2. Click on "Rules" to view the current rules
3. Use the "Rules Playground" to test specific scenarios:

**Example: Test Owner Access**
```javascript
// Service: Firestore
// Location: /users/user123/notes/note456
// Method: get
// Auth: { uid: "user123" }
// Expected: Allow
```

**Example: Test Collaborator Read Access**
```javascript
// Service: Firestore
// Location: /users/user123/notes/note456
// Method: get
// Auth: { uid: "user789" }
// Data: { isShared: true, collaborators: [{ userId: "user789", role: "viewer" }] }
// Expected: Allow
```

**Example: Test Collaborator Write Access (Editor)**
```javascript
// Service: Firestore
// Location: /users/user123/notes/note456
// Method: update
// Auth: { uid: "user789" }
// Data: { isShared: true, collaborators: [{ userId: "user789", role: "editor" }] }
// Expected: Allow
```

**Example: Test Collaborator Write Access (Viewer)**
```javascript
// Service: Firestore
// Location: /users/user123/notes/note456
// Method: update
// Auth: { uid: "user789" }
// Data: { isShared: true, collaborators: [{ userId: "user789", role: "viewer" }] }
// Expected: Deny
```

#### Test Realtime Database Rules

1. Navigate to the Realtime Database tab in the Emulator UI
2. Click on "Rules" to view the current rules
3. Test presence data operations:

**Example: Test Presence Write**
```javascript
// Location: /presence/note123/user456
// Method: set
// Auth: { uid: "user456" }
// Data: {
//   status: "editing",
//   cursorPosition: 42,
//   lastSeen: 1234567890,
//   displayName: "John Doe",
//   email: "john@example.com"
// }
// Expected: Allow
```

### Running Unit Tests

The project includes simulated security rule tests that can be run without the emulator:

```bash
flutter test test/firestore_security_rules_test.dart
```

**Note**: These tests use `fake_cloud_firestore` and simulate the security logic. For comprehensive testing, use the Firebase Emulator.

## Deploying Security Rules

### Deploy to Firebase

Once you've tested the rules and are satisfied:

1. Deploy Firestore rules:
```bash
firebase deploy --only firestore:rules
```

2. Deploy Realtime Database rules:
```bash
firebase deploy --only database
```

3. Deploy both:
```bash
firebase deploy --only firestore:rules,database
```

### Verify Deployment

1. Go to Firebase Console
2. Navigate to Firestore → Rules
3. Verify the rules are updated
4. Check the deployment timestamp

## Common Test Scenarios

### Scenario 1: Private Note Access
- **Setup**: Create a note with `isShared: false`
- **Test**: Try to access as different user
- **Expected**: Deny

### Scenario 2: Shared Note with Viewer
- **Setup**: Create a note with `isShared: true` and collaborator with role "viewer"
- **Test**: Try to read as collaborator
- **Expected**: Allow
- **Test**: Try to write as collaborator
- **Expected**: Deny

### Scenario 3: Shared Note with Editor
- **Setup**: Create a note with `isShared: true` and collaborator with role "editor"
- **Test**: Try to read as collaborator
- **Expected**: Allow
- **Test**: Try to write as collaborator
- **Expected**: Allow
- **Test**: Try to delete as collaborator
- **Expected**: Deny

### Scenario 4: Folder Operations
- **Setup**: Create a folder under user's collection
- **Test**: Try to access as owner
- **Expected**: Allow
- **Test**: Try to access as different user
- **Expected**: Deny

### Scenario 5: Template Operations
- **Setup**: Create a template under user's collection
- **Test**: Try to access as owner
- **Expected**: Allow
- **Test**: Try to access as different user
- **Expected**: Deny

### Scenario 6: Presence Data
- **Setup**: Write presence data for a note
- **Test**: Try to write own presence data
- **Expected**: Allow
- **Test**: Try to write another user's presence data
- **Expected**: Deny
- **Test**: Try to read presence data as authenticated user
- **Expected**: Allow

## Troubleshooting

### Rules Not Updating
- Clear emulator data: `firebase emulators:start --clear-data`
- Restart the emulator

### Permission Denied Errors
- Check authentication state
- Verify user ID matches document path
- Check collaborator array structure
- Verify role field is correct

### Validation Errors
- Check required fields are present
- Verify data types match validation rules
- Check enum values (e.g., status must be 'viewing', 'editing', or 'away')

## Security Best Practices

1. **Always authenticate**: Never allow unauthenticated access
2. **Validate data**: Use validation rules to ensure data integrity
3. **Principle of least privilege**: Grant minimum necessary permissions
4. **Test thoroughly**: Test all access patterns before deploying
5. **Monitor usage**: Use Firebase Console to monitor rule evaluations
6. **Regular audits**: Periodically review and update rules

## Additional Resources

- [Firebase Security Rules Documentation](https://firebase.google.com/docs/rules)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Realtime Database Security Rules](https://firebase.google.com/docs/database/security)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)

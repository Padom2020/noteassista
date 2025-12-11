# Security Rules Quick Reference

## Quick Commands

### Testing
```bash
# Run unit tests
flutter test test/firestore_security_rules_test.dart

# Start emulator (Windows)
scripts\test_security_rules.bat

# Start emulator (Linux/Mac)
./scripts/test_security_rules.sh

# Start emulator manually
firebase emulators:start

# Start with fresh data
firebase emulators:start --clear-data
```

### Deployment
```bash
# Deploy all rules
firebase deploy --only firestore:rules,database

# Deploy Firestore only
firebase deploy --only firestore:rules

# Deploy Realtime Database only
firebase deploy --only database
```

## Access Control Matrix

### Notes Collection

| User Type | Read | Write | Delete |
|-----------|------|-------|--------|
| Owner | ✅ | ✅ | ✅ |
| Collaborator (Owner) | ✅ | ✅ | ❌ |
| Collaborator (Editor) | ✅ | ✅ | ❌ |
| Collaborator (Viewer) | ✅ | ❌ | ❌ |
| Non-collaborator | ❌ | ❌ | ❌ |
| Unauthenticated | ❌ | ❌ | ❌ |

### Folders Collection

| User Type | Read | Write | Delete |
|-----------|------|-------|--------|
| Owner | ✅ | ✅ | ✅ |
| Other users | ❌ | ❌ | ❌ |
| Unauthenticated | ❌ | ❌ | ❌ |

### Templates Collection

| User Type | Read | Write | Delete |
|-----------|------|-------|--------|
| Owner | ✅ | ✅ | ✅ |
| Other users | ❌ | ❌ | ❌ |
| Unauthenticated | ❌ | ❌ | ❌ |

### Presence Data (Realtime Database)

| User Type | Read | Write Own | Write Others |
|-----------|------|-----------|--------------|
| Authenticated | ✅ | ✅ | ❌ |
| Unauthenticated | ❌ | ❌ | ❌ |

## Code Examples

### Creating a Shared Note
```dart
await firestore
  .collection('users')
  .doc(userId)
  .collection('notes')
  .doc(noteId)
  .set({
    'title': 'Shared Note',
    'description': 'Content',
    'isShared': true,
    'collaborators': [
      {
        'userId': 'collaborator-id',
        'email': 'collaborator@example.com',
        'role': 'editor', // or 'viewer' or 'owner'
      }
    ],
  });
```

### Adding a Collaborator
```dart
await firestore
  .collection('users')
  .doc(userId)
  .collection('notes')
  .doc(noteId)
  .update({
    'collaborators': FieldValue.arrayUnion([
      {
        'userId': 'new-collaborator-id',
        'email': 'new@example.com',
        'role': 'viewer',
      }
    ]),
  });
```

### Creating a Folder
```dart
await firestore
  .collection('users')
  .doc(userId)
  .collection('folders')
  .doc(folderId)
  .set({
    'name': 'My Folder',
    'parentId': null,
    'color': '#FF0000',
    'noteCount': 0,
    'createdAt': FieldValue.serverTimestamp(),
    'isFavorite': false,
  });
```

### Creating a Template
```dart
await firestore
  .collection('users')
  .doc(userId)
  .collection('templates')
  .doc(templateId)
  .set({
    'name': 'Meeting Notes',
    'description': 'Template for meetings',
    'content': '# Meeting Notes\n\n## Agenda',
    'variables': [],
    'usageCount': 0,
    'createdAt': FieldValue.serverTimestamp(),
    'isCustom': true,
  });
```

### Setting Presence Data
```dart
await database
  .ref('presence/$noteId/$userId')
  .set({
    'status': 'editing', // or 'viewing' or 'away'
    'cursorPosition': 42,
    'lastSeen': DateTime.now().millisecondsSinceEpoch,
    'displayName': 'John Doe',
    'email': 'john@example.com',
  });
```

## Common Issues

### ❌ Permission Denied
**Cause:** User not authenticated or not authorized
**Fix:** Check authentication and collaborator list

### ❌ Invalid Data
**Cause:** Missing required fields or wrong data types
**Fix:** Ensure all required fields are present and correct type

### ❌ Rules Not Updating
**Cause:** Emulator cache
**Fix:** Restart emulator with `--clear-data` flag

## Emulator Ports

- **Firestore:** http://localhost:8080
- **Realtime Database:** http://localhost:9000
- **Emulator UI:** http://localhost:4000

## Required Fields

### Note (for collaboration)
- `isShared`: boolean
- `collaborators`: array of objects with `userId`, `email`, `role`

### Folder
- `name`: string
- `parentId`: string or null
- `color`: string
- `noteCount`: number
- `createdAt`: timestamp
- `isFavorite`: boolean

### Template
- `name`: string
- `description`: string
- `content`: string
- `variables`: array
- `usageCount`: number
- `createdAt`: timestamp
- `isCustom`: boolean

### Presence
- `status`: 'viewing' | 'editing' | 'away'
- `lastSeen`: number (timestamp)
- `displayName`: string
- `email`: string
- `cursorPosition`: number (optional)

## Roles

- **owner**: Full access (read, write, but cannot delete note if not document owner)
- **editor**: Can read and write
- **viewer**: Can only read

## Testing Checklist

- [ ] Owner can access their own notes
- [ ] Owner can access their own folders
- [ ] Owner can access their own templates
- [ ] Collaborator (viewer) can read shared notes
- [ ] Collaborator (viewer) cannot write shared notes
- [ ] Collaborator (editor) can read and write shared notes
- [ ] Collaborator (editor) cannot delete notes
- [ ] Non-collaborator cannot access shared notes
- [ ] Unauthenticated users cannot access any data
- [ ] Presence data can be read by authenticated users
- [ ] Users can only write their own presence data

## Documentation

- **Full Guide:** [FIRESTORE_SECURITY_RULES.md](./FIRESTORE_SECURITY_RULES.md)
- **Testing Guide:** [SECURITY_RULES_TESTING.md](./SECURITY_RULES_TESTING.md)
- **Firebase Docs:** https://firebase.google.com/docs/rules

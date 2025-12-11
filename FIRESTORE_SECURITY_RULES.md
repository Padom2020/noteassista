# Firestore Security Rules Implementation

## Overview

This document describes the comprehensive security rules implemented for NoteAssista, covering:
- User notes with collaboration support
- Folder management
- Template library
- Real-time presence data

## Security Rules Summary

### Firestore Rules

#### 1. Notes Collection (`/users/{userId}/notes/{noteId}`)

**Owner Access:**
- ✅ Full read/write/delete access to their own notes
- ✅ Can create new notes
- ✅ Can update existing notes
- ✅ Can delete notes

**Collaborator Access:**
- ✅ Can read shared notes if listed in collaborators array
- ✅ Can write to shared notes if role is 'editor' or 'owner'
- ❌ Cannot write if role is 'viewer'
- ❌ Cannot delete notes (only owner can delete)

**Non-collaborator Access:**
- ❌ Cannot access notes they don't own or aren't collaborating on

#### 2. Folders Collection (`/users/{userId}/folders/{folderId}`)

**Owner Access:**
- ✅ Full read/write/delete access to their own folders
- ✅ Can create new folders
- ✅ Can update folder properties
- ✅ Can delete folders

**Other Users:**
- ❌ No access to other users' folders

#### 3. Templates Collection (`/users/{userId}/templates/{templateId}`)

**Owner Access:**
- ✅ Full read/write/delete access to their own templates
- ✅ Can create new templates
- ✅ Can update template content and metadata
- ✅ Can delete templates

**Other Users:**
- ❌ No access to other users' templates

### Realtime Database Rules (Presence)

#### Presence Data (`/presence/{noteId}/{userId}`)

**Read Access:**
- ✅ Any authenticated user can read presence data for a note
- This allows collaborators to see who else is viewing/editing

**Write Access:**
- ✅ Users can only write their own presence data
- ❌ Cannot modify other users' presence data

**Data Validation:**
- Required fields: `status`, `lastSeen`, `displayName`, `email`
- `status` must be one of: 'viewing', 'editing', 'away'
- `cursorPosition` must be a number (optional)
- `lastSeen` must be a timestamp number
- `displayName` and `email` must be strings

## Helper Functions

### `isAuthenticated()`
Checks if the request has a valid authentication token.

### `isOwner(userId)`
Checks if the authenticated user is the owner of the resource.

### `isCollaborator(noteData)`
Checks if the authenticated user is listed in the note's collaborators array.

### `getCollaboratorRole(noteData)`
Returns the role of the authenticated user from the collaborators array.

### `canEdit(noteData)`
Checks if the user has 'editor' or 'owner' role, allowing write access.

## Data Structure Requirements

### Note Document
```javascript
{
  title: string,
  description: string,
  isShared: boolean,
  collaborators: [
    {
      userId: string,
      email: string,
      role: 'viewer' | 'editor' | 'owner'
    }
  ],
  // ... other fields
}
```

### Folder Document
```javascript
{
  name: string,
  parentId: string | null,
  color: string,
  noteCount: number,
  createdAt: timestamp,
  isFavorite: boolean
}
```

### Template Document
```javascript
{
  name: string,
  description: string,
  content: string,
  variables: array,
  usageCount: number,
  createdAt: timestamp,
  isCustom: boolean
}
```

### Presence Data
```javascript
{
  status: 'viewing' | 'editing' | 'away',
  cursorPosition: number (optional),
  lastSeen: number (timestamp),
  displayName: string,
  email: string
}
```

## Testing

### Unit Tests
Run the simulated security rules tests:
```bash
flutter test test/firestore_security_rules_test.dart
```

### Emulator Testing
Use the Firebase Emulator Suite for comprehensive testing:

**Windows:**
```bash
scripts\test_security_rules.bat
```

**Linux/Mac:**
```bash
chmod +x scripts/test_security_rules.sh
./scripts/test_security_rules.sh
```

Or manually:
```bash
firebase emulators:start
```

Then access the Emulator UI at `http://localhost:4000`

### Testing Scenarios

#### Scenario 1: Owner Access
```javascript
// User: user123
// Path: /users/user123/notes/note456
// Action: read/write
// Expected: ✅ Allow
```

#### Scenario 2: Collaborator Read (Viewer)
```javascript
// User: user789
// Path: /users/user123/notes/note456
// Note data: { isShared: true, collaborators: [{ userId: "user789", role: "viewer" }] }
// Action: read
// Expected: ✅ Allow
```

#### Scenario 3: Collaborator Write (Viewer)
```javascript
// User: user789
// Path: /users/user123/notes/note456
// Note data: { isShared: true, collaborators: [{ userId: "user789", role: "viewer" }] }
// Action: write
// Expected: ❌ Deny
```

#### Scenario 4: Collaborator Write (Editor)
```javascript
// User: user789
// Path: /users/user123/notes/note456
// Note data: { isShared: true, collaborators: [{ userId: "user789", role: "editor" }] }
// Action: write
// Expected: ✅ Allow
```

#### Scenario 5: Non-collaborator Access
```javascript
// User: user999
// Path: /users/user123/notes/note456
// Note data: { isShared: true, collaborators: [{ userId: "user789", role: "editor" }] }
// Action: read/write
// Expected: ❌ Deny
```

## Deployment

### Deploy to Firebase
```bash
# Deploy Firestore rules only
firebase deploy --only firestore:rules

# Deploy Realtime Database rules only
firebase deploy --only database

# Deploy both
firebase deploy --only firestore:rules,database
```

### Verify Deployment
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to Firestore → Rules
4. Verify the rules are updated
5. Check the deployment timestamp

## Security Best Practices

### ✅ Do's
- Always authenticate users before granting access
- Use role-based access control for collaboration
- Validate data structure and types
- Test rules thoroughly before deploying
- Monitor rule evaluations in Firebase Console
- Keep rules simple and maintainable
- Document complex rule logic

### ❌ Don'ts
- Never allow unauthenticated access to user data
- Don't grant write access to viewers
- Don't allow users to modify other users' data
- Don't skip validation rules
- Don't deploy untested rules to production
- Don't use overly complex rule logic

## Troubleshooting

### Permission Denied Errors

**Problem:** User cannot access their own notes
**Solution:** 
- Verify user is authenticated
- Check that `request.auth.uid` matches `userId` in path
- Ensure user document exists

**Problem:** Collaborator cannot access shared note
**Solution:**
- Verify `isShared` is set to `true`
- Check collaborator is in `collaborators` array
- Verify `userId` field matches in collaborator object
- Check role is correctly set

**Problem:** Editor cannot write to shared note
**Solution:**
- Verify role is 'editor' or 'owner', not 'viewer'
- Check collaborators array structure is correct
- Ensure note document has required fields

### Validation Errors

**Problem:** Presence data write fails
**Solution:**
- Ensure all required fields are present: `status`, `lastSeen`, `displayName`, `email`
- Verify `status` is one of: 'viewing', 'editing', 'away'
- Check `lastSeen` is a number (timestamp)
- Verify user is writing to their own presence path

### Emulator Issues

**Problem:** Rules not updating in emulator
**Solution:**
- Stop and restart emulator
- Clear emulator data: `firebase emulators:start --clear-data`
- Check `firebase.json` configuration

**Problem:** Cannot connect to emulator
**Solution:**
- Verify emulator is running
- Check ports are not in use (8080, 9000, 4000)
- Ensure firewall allows local connections

## Monitoring and Maintenance

### Monitor Rule Evaluations
1. Go to Firebase Console
2. Navigate to Firestore → Usage
3. Check "Rules evaluations" metric
4. Look for denied requests

### Regular Audits
- Review rules quarterly
- Check for unused rules
- Update based on new features
- Test with real-world scenarios
- Document changes

### Performance Considerations
- Keep rules simple for faster evaluation
- Avoid complex nested conditions
- Use helper functions for reusability
- Cache frequently accessed data
- Monitor rule evaluation time

## Related Documentation

- [SECURITY_RULES_TESTING.md](./SECURITY_RULES_TESTING.md) - Detailed testing guide
- [Firebase Security Rules Documentation](https://firebase.google.com/docs/rules)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Realtime Database Security Rules](https://firebase.google.com/docs/database/security)

## Support

For issues or questions:
1. Check this documentation
2. Review Firebase Console logs
3. Test with Firebase Emulator
4. Consult Firebase documentation
5. Contact development team

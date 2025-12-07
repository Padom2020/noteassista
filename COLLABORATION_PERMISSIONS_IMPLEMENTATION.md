# Collaboration Permissions Implementation

## Overview
This document describes the implementation of role-based access control (RBAC) for collaborative note editing in NoteAssista.

## Features Implemented

### 1. Role-Based Access Control
Three roles are supported:
- **Owner**: Full control over the note (edit, delete, manage collaborators)
- **Editor**: Can view and edit the note
- **Viewer**: Can only view the note (read-only access)

### 2. Data Model Updates

#### NoteModel Changes
- Added `ownerId` field to track the note owner
- Added `collaborators` field (List<Map<String, dynamic>>) to store collaborator information with roles
- Maintained backward compatibility with `collaboratorIds` field

#### CollaboratorModel
- Already includes `role` field with CollaboratorRole enum (viewer, editor, owner)
- Stores userId, email, displayName, role, and addedAt timestamp

### 3. CollaborationService Enhancements

#### New Permission Methods
- `canEdit(userId, noteId, noteOwnerId)`: Checks if user can edit the note
- `canView(userId, noteId, noteOwnerId)`: Checks if user can view the note
- `getUserRole(userId, noteId, noteOwnerId)`: Returns the user's role for a note

#### Updated Methods
- `shareNote()`: Now accepts a `role` parameter (defaults to editor)
- `updateCollaboratorRole()`: New method to change a collaborator's role
- `removeCollaborator()`: Updated to handle both collaborators and collaboratorIds lists
- `getCollaboratorDetails()`: Updated to read from the new collaborators structure

### 4. UI Components

#### ShareNoteDialog Enhancements
- Added role selector (Viewer/Editor) when adding collaborators
- Made role badges clickable to change roles (except for owners)
- Shows dropdown menu to change collaborator roles
- Displays appropriate icons for each role
- Prevents removal of note owners

#### EditNoteScreen Updates
- Added permission checking on screen initialization
- Shows loading indicator while checking permissions
- Displays permission banner for read-only users
- Disables all editing controls when user lacks edit permission:
  - Title and description fields become read-only
  - Category selection hidden
  - Audio recording disabled
  - Voice input disabled
  - Update button hidden
- Shows lock icons on disabled fields
- Prevents update attempts with permission check

### 5. Security Rules

Created `firestore_collaboration_rules.txt` with:
- Firestore security rules for role-based access
- Helper functions to check ownership and roles
- Read/write rules based on user roles
- Firebase Realtime Database rules for presence data

## Implementation Details

### Permission Flow
1. When a note is created, the creator's userId is set as `ownerId`
2. When sharing a note, collaborators are added with their role
3. When opening a note for editing:
   - System checks if user is owner or has editor role
   - UI adapts based on permissions
   - Edit operations are blocked for viewers

### Role Management
- Owners can change collaborator roles
- Owners cannot be removed or have their role changed
- Role changes are immediate and reflected in the UI
- Only editors and owners can modify note content

### Read-Only Mode
When a user has viewer role or no edit permission:
- All form fields are disabled
- Lock icons appear on fields
- Orange banner explains the limitation
- Audio delete buttons are hidden
- Voice input and recording are disabled
- Update button is hidden

## Files Modified

1. `lib/models/note_model.dart` - Added ownerId and collaborators fields
2. `lib/services/collaboration_service.dart` - Added permission methods and role management
3. `lib/widgets/share_note_dialog.dart` - Added role selection and management UI
4. `lib/screens/edit_note_screen.dart` - Added permission checks and read-only mode
5. `lib/screens/add_note_screen.dart` - Set ownerId on note creation
6. `lib/screens/voice_capture_screen.dart` - Set ownerId on note creation

## Files Created

1. `firestore_collaboration_rules.txt` - Security rules for Firestore and Realtime Database
2. `COLLABORATION_PERMISSIONS_IMPLEMENTATION.md` - This documentation

## Testing

The implementation includes:
- Permission checking before edit operations
- UI adaptation based on user role
- Role management through the share dialog
- Proper error messages for permission denied scenarios

## Deployment Steps

1. Update Firestore security rules using the rules in `firestore_collaboration_rules.txt`
2. Update Firebase Realtime Database rules for presence data
3. Deploy the updated application
4. Existing notes will need migration to add ownerId field (can be done via cloud function or manual script)

## Future Enhancements

Potential improvements:
- Add "Owner" role option in share dialog (for transferring ownership)
- Implement permission inheritance for nested folders
- Add audit log for permission changes
- Support for public sharing with view-only links
- Granular permissions (e.g., can comment but not edit)

## Notes

- Backward compatibility maintained with `collaboratorIds` field
- Owner role is automatically assigned to note creator
- Permission checks are performed both client-side (UI) and should be enforced server-side (security rules)
- The implementation follows the design document specifications for Requirement 26

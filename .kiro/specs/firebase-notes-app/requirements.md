# Requirements Document

## Introduction

This document specifies the requirements for NoteAssista, a Flutter-based note-taking application with Firebase backend integration. The application enables users to create, manage, and organize personal notes with real-time synchronization across devices. Users must authenticate to access their notes, ensuring data privacy and security. The system provides a streamlined interface for adding, editing, completing, and deleting notes with visual categorization.

## Glossary

- **NoteAssista**: The Flutter mobile application system being developed
- **Firebase Authentication**: The authentication service that manages user registration and login
- **Cloud Firestore**: The NoSQL cloud database that stores and synchronizes note data in real-time
- **Note**: A user-created item containing a title, description, timestamp, category image, and completion status
- **User**: An authenticated individual who creates and manages notes within the application
- **Auth State**: The current authentication status indicating whether a user is logged in or logged out
- **Real-time Sync**: Automatic data synchronization across devices when changes occur in the database
- **Completion Status**: A boolean flag indicating whether a note is marked as done or not done

## Requirements

### Requirement 1: User Registration

**User Story:** As a new user, I want to register for an account with my email and password, so that I can securely access the note-taking application.

#### Acceptance Criteria

1. WHEN a user provides a valid email address and matching password fields, THE NoteAssista SHALL create a new user account in Firebase Authentication
2. WHEN a user account is successfully created in Firebase Authentication, THE NoteAssista SHALL create a corresponding user document in Cloud Firestore with the user ID and email
3. IF the password and password confirmation fields do not match, THEN THE NoteAssista SHALL prevent account creation
4. WHEN account creation succeeds, THE NoteAssista SHALL automatically authenticate the user and navigate to the home screen
5. THE NoteAssista SHALL display a sign-up form with email, password, and password confirmation input fields

### Requirement 2: User Login

**User Story:** As a registered user, I want to log in with my email and password, so that I can access my personal notes.

#### Acceptance Criteria

1. WHEN a user provides valid credentials, THE NoteAssista SHALL authenticate the user through Firebase Authentication
2. WHEN authentication succeeds, THE NoteAssista SHALL navigate the user to the home screen displaying their notes
3. IF authentication fails due to invalid credentials, THEN THE NoteAssista SHALL display an error message
4. THE NoteAssista SHALL display a login form with email and password input fields
5. THE NoteAssista SHALL provide a navigation option to switch from login to sign-up screen

### Requirement 3: Authentication State Management

**User Story:** As a user, I want the app to remember my login status, so that I don't have to log in every time I open the app.

#### Acceptance Criteria

1. WHEN the application launches, THE NoteAssista SHALL check the current authentication state from Firebase Authentication
2. IF a user is authenticated, THEN THE NoteAssista SHALL display the home screen with the user's notes
3. IF no user is authenticated, THEN THE NoteAssista SHALL display the authentication screen (login/sign-up)
4. WHEN a user's authentication state changes, THE NoteAssista SHALL automatically update the displayed screen accordingly
5. THE NoteAssista SHALL use Firebase Authentication state stream to monitor authentication changes in real-time

### Requirement 4: Create Note

**User Story:** As an authenticated user, I want to create a new note with a title, description, and category image, so that I can capture and organize my thoughts.

#### Acceptance Criteria

1. WHEN a user provides a title and description, THE NoteAssista SHALL create a new note document in Cloud Firestore with a unique identifier
2. WHEN a note is created, THE NoteAssista SHALL store the title, description, category image index, creation timestamp, and completion status set to false
3. WHEN a note is created, THE NoteAssista SHALL generate the timestamp in hour:minute format from the current device time
4. THE NoteAssista SHALL provide a selection interface with at least four category image options
5. WHEN note creation succeeds, THE NoteAssista SHALL navigate the user back to the home screen
6. THE NoteAssista SHALL store the note under the authenticated user's document path in Cloud Firestore

### Requirement 5: Display Notes

**User Story:** As an authenticated user, I want to see all my notes organized by completion status, so that I can easily distinguish between active and completed tasks.

#### Acceptance Criteria

1. THE NoteAssista SHALL display notes in two separate sections: not done and done
2. WHEN the home screen loads, THE NoteAssista SHALL retrieve notes from Cloud Firestore filtered by completion status
3. THE NoteAssista SHALL display each note showing its title, description, timestamp, and category image
4. WHEN note data changes in Cloud Firestore, THE NoteAssista SHALL automatically update the displayed notes in real-time
5. THE NoteAssista SHALL use Cloud Firestore snapshots to stream note updates to the user interface

### Requirement 6: Mark Note as Complete

**User Story:** As an authenticated user, I want to mark notes as complete or incomplete, so that I can track my progress on tasks.

#### Acceptance Criteria

1. WHEN a user toggles a note's completion status, THE NoteAssista SHALL update the isDone field in Cloud Firestore
2. WHEN the completion status changes, THE NoteAssista SHALL move the note to the appropriate section (done or not done)
3. THE NoteAssista SHALL provide a visual checkbox or toggle control for each note to change completion status
4. WHEN the status update succeeds, THE NoteAssista SHALL reflect the change immediately in the user interface
5. THE NoteAssista SHALL allow users to toggle completion status in both directions (done to not done, and not done to done)

### Requirement 7: Edit Note

**User Story:** As an authenticated user, I want to edit existing notes, so that I can update information or correct mistakes.

#### Acceptance Criteria

1. WHEN a user selects a note for editing, THE NoteAssista SHALL display an edit screen pre-populated with the note's current data
2. WHEN a user modifies the title, description, or category image, THE NoteAssista SHALL update the corresponding fields in Cloud Firestore
3. WHEN a note is updated, THE NoteAssista SHALL refresh the timestamp to the current time in hour:minute format
4. WHEN the update succeeds, THE NoteAssista SHALL navigate the user back to the home screen
5. THE NoteAssista SHALL preserve the note's unique identifier and completion status during editing

### Requirement 8: Delete Note

**User Story:** As an authenticated user, I want to delete notes I no longer need, so that I can keep my note list organized and relevant.

#### Acceptance Criteria

1. WHEN a user initiates note deletion, THE NoteAssista SHALL remove the note document from Cloud Firestore
2. WHEN deletion succeeds, THE NoteAssista SHALL remove the note from the user interface immediately
3. THE NoteAssista SHALL provide a delete action accessible from the note interface
4. THE NoteAssista SHALL use the note's unique identifier to target the correct document for deletion
5. THE NoteAssista SHALL delete only notes belonging to the authenticated user

### Requirement 9: User Interface Responsiveness

**User Story:** As a user, I want the app interface to respond smoothly to my interactions, so that I have a pleasant user experience.

#### Acceptance Criteria

1. WHEN a user scrolls down the note list, THE NoteAssista SHALL hide the floating action button
2. WHEN a user scrolls up the note list, THE NoteAssista SHALL show the floating action button
3. THE NoteAssista SHALL provide visual feedback when input fields receive focus by changing border colors
4. THE NoteAssista SHALL display the selected category image with a distinct border color during note creation
5. THE NoteAssista SHALL use a consistent color scheme throughout the application interface

### Requirement 10: Firebase Integration

**User Story:** As a user, I want my notes to be securely stored in the cloud, so that I can access them from any device and never lose my data.

#### Acceptance Criteria

1. WHEN the application launches, THE NoteAssista SHALL initialize Firebase with platform-specific configuration
2. THE NoteAssista SHALL store all user data in Cloud Firestore using the structure: users/{userId}/notes/{noteId}
3. THE NoteAssista SHALL use Firebase Authentication to manage user sessions and access control
4. THE NoteAssista SHALL ensure that users can only access their own notes through Firestore security rules
5. THE NoteAssista SHALL handle Firebase initialization before rendering any user interface components

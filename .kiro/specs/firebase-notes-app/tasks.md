# Implementation Plan

- [x] 1. Set up Firebase configuration and project structure
  - Initialize Firebase in main.dart before runApp()
  - Add firebase_core, firebase_auth, and cloud_firestore dependencies to pubspec.yaml
  - Create assets directory structure for category images
  - Configure Firebase for both Android and iOS platforms
  - _Requirements: 10.1, 10.5_

- [x] 2. Implement data models and utilities


  - [x] 2.1 Create NoteModel class with Firestore serialization
    - Write NoteModel class with all required fields (id, title, description, timestamp, categoryImageIndex, isDone)
    - Implement toMap() method for Firestore document creation
    - Implement fromFirestore() factory constructor for document deserialization
    - _Requirements: 4.2, 5.3_
  

  - [x] 2.2 Create UserModel class
    - Write UserModel class with uid and email fields
    - Implement toMap() method for Firestore user document
    - Implement fromFirebaseUser() factory constructor
    - _Requirements: 1.2_
  

  - [x] 2.3 Create timestamp utility function
    - Write function to generate timestamp in HH:mm format from current DateTime
    - _Requirements: 4.3, 7.3_

- [x] 3. Implement Firebase service layer

  - [x] 3.1 Create AuthService class
    - Implement authStateChanges stream getter
    - Implement signUp() method for user registration with Firebase Auth
    - Implement signIn() method for user authentication
    - Implement signOut() method
    - Implement currentUser getter
    - _Requirements: 1.1, 2.1, 3.1, 3.5_
  
  - [x] 3.2 Create FirestoreService class
    - Implement createUser() method to create user document in Firestore
    - Implement createNote() method to add note to user's subcollection
    - Implement updateNote() method to modify existing note
    - Implement deleteNote() method to remove note document
    - Implement streamNotes() method to return real-time query stream filtered by isDone
    - Implement toggleNoteStatus() method to update note completion status
    - _Requirements: 1.2, 4.1, 4.6, 5.2, 6.1, 7.2, 8.1, 10.2_

- [x] 4. Implement authentication screens




  - [x] 4.1 Create LoginScreen widget
    - Build login form with email and password TextFormFields
    - Implement _login() method that calls AuthService.signIn()
    - Add navigation button to switch to SignupScreen
    - Display error messages using SnackBar for auth failures
    - Add loading indicator during authentication
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [x] 4.2 Create SignupScreen widget
    - Build signup form with email, password, and confirm password fields
    - Implement password confirmation validation
    - Implement _signup() method that calls AuthService.signUp() and FirestoreService.createUser()
    - Navigate to HomeScreen automatically after successful registration
    - Display error messages for validation and auth failures
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_


  
  - [x] 4.3 Create AuthWrapper widget
    - Implement StreamBuilder listening to AuthService.authStateChanges
    - Route to LoginScreen when user is null
    - Route to HomeScreen when user is authenticated
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 5. Implement HomeScreen with note display




  - [x] 5.1 Create HomeScreen widget structure


    - Set up Scaffold with AppBar and FloatingActionButton
    - Implement ScrollController for FAB visibility management
    - Create two sections for "Not Done" and "Done" notes
    - Add FAB that navigates to AddNoteScreen
    - _Requirements: 5.1, 9.1, 9.2_
  
  - [x] 5.2 Implement note streaming and display


    - Create two StreamBuilders for not done and done notes using FirestoreService.streamNotes()
    - Build note cards displaying title, description, timestamp, and category image
    - Implement real-time UI updates when Firestore data changes
    - Handle loading and empty states for each section
    - _Requirements: 5.2, 5.3, 5.4, 5.5_
  
  - [x] 5.3 Implement note interaction handlers


    - Add onTap handler to navigate to EditNoteScreen with note data
    - Implement delete action that calls FirestoreService.deleteNote()
    - Implement completion toggle that calls FirestoreService.toggleNoteStatus()
    - Add visual checkbox or toggle control for completion status
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [x] 5.4 Implement scroll-based FAB visibility


    - Add scroll listener to ScrollController
    - Update FAB visibility state based on scroll direction
    - Animate FAB show/hide transitions
    - _Requirements: 9.1, 9.2_

- [x] 6. Implement AddNoteScreen

  - [x] 6.1 Create AddNoteScreen form
    - Build form with title and description TextFormFields
    - Create category image selection grid with 4 options
    - Implement visual selection indicator for chosen category
    - Add input focus styling with border color changes
    - _Requirements: 4.4, 9.3, 9.4_
  

  - [x] 6.2 Implement note creation logic
    - Implement _createNote() method that generates timestamp and calls FirestoreService.createNote()
    - Validate that title and description are not empty
    - Set isDone to false for new notes
    - Navigate back to HomeScreen on successful creation
    - Display error messages if creation fails
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 4.6_

- [-] 7. Implement EditNoteScreen




  - [ ] 7.1 Create EditNoteScreen form
    - Build form pre-populated with existing note data
    - Display title, description, and selected category from passed note
    - Reuse category selection grid from AddNoteScreen
    - _Requirements: 7.1_
  
  - [ ] 7.2 Implement note update logic
    - Implement _updateNote() method that generates new timestamp and calls FirestoreService.updateNote()
    - Preserve note ID and isDone status during update
    - Navigate back to HomeScreen on successful update
    - Display error messages if update fails
    - _Requirements: 7.2, 7.3, 7.4, 7.5_

- [ ] 8. Implement UI styling and theming
  - [ ] 8.1 Create consistent color scheme
    - Define primary colors in theme
    - Apply consistent styling to buttons, cards, and form fields
    - Implement focus state colors for input fields
    - Style category image selection borders
    - _Requirements: 9.3, 9.4, 9.5_
  
  - [ ] 8.2 Style note cards and sections
    - Create card design with elevation for notes
    - Style section headers for "Not Done" and "Done"
    - Implement visual distinction between completed and active notes
    - Add category image display in note cards
    - _Requirements: 5.1, 5.3_

- [ ] 9. Add error handling and loading states
  - [ ] 9.1 Implement authentication error handling
    - Add try-catch blocks in login and signup methods
    - Map Firebase auth error codes to user-friendly messages
    - Display errors using SnackBar or form field errors
    - _Requirements: 1.3, 2.3_
  
  - [ ] 9.2 Implement Firestore error handling
    - Add try-catch blocks around all Firestore operations
    - Display user-friendly error messages for common Firestore exceptions
    - Handle network errors gracefully
    - _Requirements: 4.1, 5.2, 6.1, 7.2, 8.1_
  
  - [ ] 9.3 Add loading indicators
    - Show CircularProgressIndicator during async operations
    - Disable submit buttons during processing
    - Display loading state in StreamBuilders
    - _Requirements: 2.1, 2.2, 4.1, 5.2, 7.2, 8.1_

- [ ] 10. Configure Firestore security rules
  - Write security rules to restrict access to user's own data
  - Ensure users can only read/write their own user document and notes subcollection
  - Require authentication for all operations
  - Deploy rules to Firebase console
  - _Requirements: 10.3, 10.4_

- [ ]* 11. Write integration tests for critical flows
  - [ ]* 11.1 Test authentication flow
    - Write test for signup → auto-login → HomeScreen navigation
    - Write test for login with valid credentials
    - Write test for login with invalid credentials shows error
    - _Requirements: 1.1, 1.4, 2.1, 2.2, 2.3_
  
  - [ ]* 11.2 Test note CRUD operations
    - Write test for create note → verify appears in list
    - Write test for edit note → verify changes persist
    - Write test for delete note → verify removal from list
    - Write test for toggle completion → verify section change
    - _Requirements: 4.1, 5.2, 6.1, 7.2, 8.1_
  
  - [ ]* 11.3 Test real-time synchronization
    - Write test to verify StreamBuilder updates on Firestore changes
    - Write test for auth state changes triggering navigation
    - _Requirements: 3.4, 5.4, 5.5_

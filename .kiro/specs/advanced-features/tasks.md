# Implementation Plan

## Phase 1: Foundation and Data Models

- [x] 1. Extend data models and update Firestore structure
  - Update NoteModel class to include new fields (outgoingLinks, audioUrls, imageUrls, drawingUrls, folderId, isShared, collaborators, sourceUrl, reminder, viewCount, wordCount)
  - Create FolderModel class with id, name, parentId, color, noteCount, createdAt, isFavorite fields
  - Create TemplateModel class with id, name, description, content, variables, usageCount, createdAt, isCustom fields
  - Create CollaboratorModel class with userId, email, displayName, role, addedAt fields
  - Create StatisticsModel class with all statistics fields
  - Update NoteModel.toMap() and fromFirestore() methods to handle new fields
  - _Requirements: 21, 22, 23, 24, 26, 27, 28, 29, 30, 32, 35_

- [x] 2. Update Firestore service for new data structure
  - Add methods to FirestoreService for folder operations (createFolder, updateFolder, deleteFolder, getFolders)
  - Add methods for template operations (createTemplate, updateTemplate, deleteTemplate, getTemplates)
  - Add method to update note with extended fields
  - Add method to query notes by folder
  - Add method to get note statistics
  - _Requirements: 32, 35_

- [x] 3. Set up new Flutter dependencies
  - Add speech_to_text, permission_handler packages to pubspec.yaml
  - Add flutter_sound, audioplayers packages
  - Add google_mlkit_text_recognition, image_picker, flutter_image_compress packages
  - Add graphview package for graph visualization
  - Add geolocator, flutter_local_notifications packages
  - Add http, html packages for web scraping
  - Add flutter_markdown package
  - Add ml_algo package for text analysis
  - Add flutter_colorpicker for drawing
  - Add firebase_storage, firebase_database packages
  - Run flutter pub get
  - _Requirements: All_

- [x] 3.1 Configure platform-specific permissions
  - Add microphone permission to AndroidManifest.xml and Info.plist
  - Add camera permission for image capture
  - Add location permission for location-based reminders
  - Add notification permission configuration
  - _Requirements: 23, 27, 28, 29_

## Phase 2: AI Auto-Tagging and Smart Search

- [x] 4. Implement AI Tagging Service
  - Create AITaggingService class in lib/services/ai_tagging_service.dart
  - Implement generateTagSuggestions() method using TF-IDF algorithm
  - Implement extractKeywords() method to identify significant terms
  - Implement stop words removal logic
  - Implement recordTagAcceptance() method to learn from user behavior
  - Implement getUserTagFrequency() method to retrieve tag usage history
  - Create TagSuggestion model class
  - _Requirements: 21_

- [x] 5. Implement Smart Search Service
  - Create SmartSearchService class in lib/services/smart_search_service.dart
  - Implement parseQuery() method to parse natural language queries
  - Implement extractDateRange() method to parse temporal expressions (today, yesterday, last week, etc.)
  - Implement extractOperators() method to parse search operators (tag:, date:, is:)
  - Implement search() method with relevance ranking algorithm
  - Create SearchQuery and SearchResult model classes
  - Implement keyword extraction and stop word removal
  - _Requirements: 22_

- [x] 6. Build tag suggestion UI components
  - Create TagSuggestionChip widget in lib/widgets/tag_suggestion_chip.dart
  - Create horizontal scrollable chip list for suggestions
  - Add tap handler to accept suggestions
  - Add visual confidence indicator (opacity based on score)
  - Integrate tag suggestions into AddNoteScreen and EditNoteScreen
  - Add loading indicator while generating suggestions
  - _Requirements: 21_

- [x] 7. Build smart search interface
  - Create SmartSearchBar widget in lib/widgets/smart_search_bar.dart
  - Implement expandable search bar in home screen app bar
  - Add real-time search results display
  - Implement search result highlighting
  - Add recent searches display
  - Add search operator autocomplete
  - Create SearchResultCard widget to display results
  - Implement search history storage using shared_preferences
  - _Requirements: 22_

- [x] 7.1 Write unit tests for AI and search services
  - Test keyword extraction with various text samples
  - Test TF-IDF calculation accuracy
  - Test natural language date parsing
  - Test search ranking algorithm
  - _Requirements: 21, 22_


## Phase 3: Voice-to-Text and Audio Features

- [x] 8. Implement Voice Service
  - Create VoiceService class in lib/services/voice_service.dart
  - Implement startListening() method using speech_to_text package
  - Implement stopListening() method to finalize transcription
  - Implement isAvailable() method to check device support
  - Implement getTranscriptionStream() for real-time updates
  - Implement recordAudio() method for audio attachments
  - Implement uploadAudio() method to Firebase Storage
  - Handle microphone permissions using permission_handler
  - Configure noise cancellation settings
  - _Requirements: 23, 27_

- [x] 9. Build voice capture UI

  - Create VoiceCaptureButton widget in lib/widgets/voice_capture_button.dart
  - Add pulsing animation while recording
  - Display real-time transcription text
  - Add recording timer display
  - Create VoiceCaptureScreen for full-screen voice input
  - Add voice capture FAB variant to home screen
  - Integrate voice button into AddNoteScreen
  - Handle permission request dialogs
  - Display error messages for recognition failures
  - _Requirements: 23_
-

- [x] 10. Implement audio attachment functionality



  - Add audio recording controls to AddNoteScreen and EditNoteScreen
  - Implement audio file compression using flutter_sound
  - Upload audio files to Firebase Storage
  - Store audio URLs in note document

  - Create AudioPlayerWidget in lib/widgets/audio_player_widget.dart
  - Implement playback controls (play, pause, seek)
  - Add playback speed adjustment (0.5x, 1x, 1.5x, 2x)
  - Display audio waveform visualization
  - Show audio duration and file size
  - Handle multiple audio attachments per note
  - _Requirements: 27_

- [x] 10.1 Write tests for voice service





  - Test speech recognition with sample audio
  - Test transcription accuracy
  - Test offline fallback
  - Mock speech_to_text package
  - _Requirements: 23, 27_

## Phase 4: Linked Notes and Graph Visualization

- [x] 11. Implement Link Management Service
  - Create LinkManagementService class in lib/services/link_management_service.dart
  - Implement parseLinks() method to extract [[Note Title]] syntax
  - Implement getBacklinks() method to query notes linking to current note
  - Implement updateLinksOnRename() method to update all references when note renamed
  - Implement createNoteFromLink() method for non-existent note links
  - Implement getNoteTitleSuggestions() for autocomplete
  - Implement buildNoteGraph() method to create graph data structure
  - Create NoteLink, GraphData, GraphNode, GraphEdge model classes
  - _Requirements: 24, 25_

- [x] 12. Build link parsing and rendering
  - Update note description rendering to detect [[Note Title]] syntax
  - Create ClickableNoteLink widget in lib/widgets/clickable_note_link.dart
  - Implement navigation on link tap
  - Highlight broken links (links to deleted notes) in distinct color
  - Support alias syntax [[Note Title|Display Text]]
  - Store outgoing links array in note document when saving
  - _Requirements: 24_

- [ ] 13. Implement link autocomplete
  - Create LinkAutocompleteDropdown widget in lib/widgets/link_autocomplete_dropdown.dart
  - Detect [[ input in text field
  - Display dropdown with filtered note titles
  - Implement arrow key navigation
  - Insert complete link syntax on selection
  - Show note preview on hover
  - _Requirements: 24_

- [ ] 14. Build backlinks display
  - Create BacklinksSection widget in lib/widgets/backlinks_section.dart
  - Display backlinks at bottom of note view
  - Show note title and preview for each backlink
  - Make backlinks clickable to navigate
  - Update backlinks in real-time when links change
  - _Requirements: 24_

- [ ] 15. Implement graph view visualization
  - Create GraphViewScreen in lib/screens/graph_view_screen.dart
  - Implement force-directed layout algorithm using graphview package
  - Render nodes for each note with size based on connection count
  - Render edges for links between notes
  - Color-code nodes by category or tag
  - Implement tap to highlight node and connections
  - Implement double-tap to navigate to note
  - Add pinch-to-zoom and pan gestures
  - Display node labels with note titles
  - Add search filter to highlight specific notes
  - Implement toggle between full graph and local graph (2 degrees)
  - Add smooth animations for node position updates
  - _Requirements: 25_

- [ ] 15.1 Write tests for link management

  - Test link parsing with various formats
  - Test backlink computation
  - Test link updates on rename
  - Test circular reference detection
  - _Requirements: 24, 25_


## Phase 5: Real-time Collaborative Editing

- [ ] 16. Set up Firebase Realtime Database for presence
  - Initialize Firebase Realtime Database in Firebase console
  - Add firebase_database dependency configuration
  - Create presence data structure in Realtime Database
  - Set up Realtime Database security rules for presence
  - _Requirements: 26_

- [ ] 17. Implement Collaboration Service
  - Create CollaborationService class in lib/services/collaboration_service.dart
  - Implement shareNote() method to add collaborators
  - Implement getActiveCollaborators() stream method
  - Implement updatePresence() method using Realtime Database
  - Implement broadcastCursorPosition() method
  - Implement listenForChanges() stream for remote edits
  - Implement applyOperationalTransform() for conflict resolution
  - Implement broadcastOperation() method
  - Create Collaborator, Operation, PresenceStatus models
  - Implement presence cleanup on disconnect
  - _Requirements: 26_

- [ ] 18. Implement operational transform algorithm
  - Create OperationalTransform class in lib/utils/operational_transform.dart
  - Implement transform() method for concurrent operations
  - Handle insert operations
  - Handle delete operations
  - Handle retain operations
  - Implement operation composition
  - Implement operation inversion for undo
  - _Requirements: 26_

- [ ] 19. Build collaboration UI components
  - Create CollaboratorAvatarList widget in lib/widgets/collaborator_avatar_list.dart
  - Display collaborator avatars in note header
  - Create CursorIndicator widget to show other users' cursors
  - Implement colored cursor position markers
  - Add "who is typing" indicator
  - Highlight text being edited by others with colored background
  - Create ShareNoteDialog for adding collaborators
  - Add share button to note edit screen
  - Display presence indicators (viewing, editing, away)
  - _Requirements: 26_

- [ ] 20. Implement collaboration permissions
  - Update Firestore security rules for shared notes
  - Implement role-based access control (viewer, editor, owner)
  - Add collaborator management UI (add, remove, change role)
  - Implement read-only mode for viewers
  - Add permission checks before edit operations
  - Display permission denied messages
  - _Requirements: 26_

- [ ]* 20.1 Write tests for collaboration
  - Test operational transform algorithm
  - Test concurrent edit scenarios
  - Test presence updates
  - Test conflict resolution
  - _Requirements: 26_

## Phase 6: Rich Content Capture (OCR, Web Clipper, Drawing)

- [ ] 21. Implement OCR Service
  - Create OCRService class in lib/services/ocr_service.dart
  - Implement extractTextFromImage() using google_mlkit_text_recognition
  - Implement uploadImage() to Firebase Storage
  - Implement optimizeImage() for preprocessing (resize, enhance contrast)
  - Implement extractTextWithLanguage() for multi-language support
  - Create OCRResult and TextBlock model classes
  - Handle offline OCR processing
  - _Requirements: 29_

- [ ] 22. Build image capture and OCR UI
  - Add camera button to AddNoteScreen and EditNoteScreen
  - Implement image picker integration
  - Create OCRProcessingScreen to show extraction progress
  - Display extracted text in editable text field
  - Allow user to review and correct OCR text
  - Append extracted text to note description
  - Display image thumbnails in note view
  - Create full-screen image viewer
  - Support batch processing of multiple images
  - _Requirements: 29_

- [ ] 23. Implement Web Clipper Service
  - Create WebClipperService class in lib/services/web_clipper_service.dart
  - Implement clipWebPage() method to fetch and parse web content
  - Implement extractMainContent() using readability algorithm
  - Implement htmlToMarkdown() conversion
  - Implement downloadFeaturedImage() method
  - Create WebClipResult model class
  - Handle authentication and paywalls gracefully
  - _Requirements: 30_

- [ ] 24. Build web clipper integration
  - Configure app as share target in AndroidManifest.xml and Info.plist
  - Create WebClipperScreen to handle shared URLs
  - Display web page preview while processing
  - Show extracted content with edit option
  - Auto-suggest tags based on article content
  - Display source URL as clickable link in note view
  - Save featured image if available
  - _Requirements: 30_

- [ ] 25. Implement drawing and handwriting support
  - Create DrawingCanvas widget in lib/widgets/drawing_canvas.dart
  - Implement drawing tools (pen, highlighter, eraser, shapes)
  - Add color picker using flutter_colorpicker
  - Add stroke width slider
  - Implement undo/redo functionality
  - Add grid/lined background toggle
  - Save drawing as image to Firebase Storage
  - Create DrawingScreen for full-screen drawing
  - Display drawing thumbnails inline with note text
  - Allow editing existing drawings
  - Support multiple drawings per note
  - _Requirements: 34_

- [ ]* 25.1 Implement handwriting recognition
  - Integrate handwriting recognition API
  - Convert handwritten text to typed text
  - Provide option to keep original drawing or replace with text
  - _Requirements: 34_

- [ ]* 25.2 Write tests for OCR and web clipper
  - Test OCR with sample images
  - Test web content extraction
  - Test HTML to markdown conversion
  - Mock external services
  - _Requirements: 29, 30_


## Phase 7: Folders and Organization

- [ ] 26. Implement folder data layer
  - Add folder CRUD methods to FirestoreService
  - Implement createFolder() method
  - Implement updateFolder() method
  - Implement deleteFolder() method with note reassignment
  - Implement getFolders() method with hierarchy support
  - Implement moveNoteToFolder() method
  - Update note queries to support folder filtering
  - _Requirements: 32_

- [ ] 27. Build folder tree UI
  - Create FolderTreeView widget in lib/widgets/folder_tree_view.dart
  - Implement expandable/collapsible tree structure
  - Display folder hierarchy with indentation
  - Show note count for each folder
  - Add folder color indicators
  - Create FolderListTile widget for individual folders
  - Implement folder navigation
  - _Requirements: 32_

- [ ] 28. Implement folder management
  - Create CreateFolderDialog widget
  - Create RenameFolderDialog widget
  - Implement folder deletion with confirmation
  - Add drag-and-drop to move notes between folders
  - Create MoveFolderDialog as alternative to drag-and-drop
  - Implement folder color picker
  - Add favorite folder toggle
  - Support nested folders up to 5 levels
  - _Requirements: 32_

- [ ] 29. Integrate folders into home screen
  - Add folder view tab or drawer to home screen
  - Display notes grouped by folder
  - Add folder filter dropdown
  - Show "All Notes" and individual folder views
  - Update note creation to select destination folder
  - Display folder breadcrumb in note view
  - _Requirements: 32_

## Phase 8: Templates Library

- [ ] 30. Implement template data layer
  - Add template CRUD methods to FirestoreService
  - Implement createTemplate() method
  - Implement updateTemplate() method
  - Implement deleteTemplate() method
  - Implement getTemplates() method
  - Implement incrementTemplateUsage() method
  - Create predefined templates (meeting notes, project plan, daily journal, book notes, recipe)
  - _Requirements: 35_

- [ ] 31. Build template library UI
  - Create TemplateLibraryScreen in lib/screens/template_library_screen.dart
  - Display templates in grid view with preview thumbnails
  - Show template name and description
  - Display usage count
  - Sort templates by usage frequency
  - Add search/filter for templates
  - _Requirements: 35_

- [ ] 32. Implement template creation and usage
  - Add "Create from Template" button to AddNoteScreen
  - Pre-populate note with template content when selected
  - Create SaveAsTemplateDialog to save custom templates
  - Implement template variable system ({{variable_name}})
  - Create TemplateVariableInputDialog for variable prompts
  - Replace variables with user input when creating note
  - Allow editing template content before saving note
  - _Requirements: 35_

- [ ] 33. Implement template sharing
  - Add export template functionality (JSON format)
  - Add import template functionality
  - Create share template dialog
  - Validate imported template structure
  - _Requirements: 35_


## Phase 9: Smart Reminders

- [ ] 34. Implement Reminder Service
  - Create ReminderService class in lib/services/reminder_service.dart
  - Implement scheduleTimeReminder() using flutter_local_notifications
  - Implement scheduleLocationReminder() using geolocator
  - Implement cancelReminder() method
  - Implement getActiveReminders() method
  - Implement parseNaturalLanguageTime() for expressions like "tomorrow", "next Monday"
  - Implement monitorLocation() stream for geofence triggers
  - Create Reminder, RecurrencePattern models
  - Handle notification permissions
  - Handle location permissions
  - _Requirements: 28_

- [ ] 35. Build reminder UI
  - Create ReminderDialog widget in lib/widgets/reminder_dialog.dart
  - Add reminder button to AddNoteScreen and EditNoteScreen
  - Implement time picker for time-based reminders
  - Implement location picker with map for location-based reminders
  - Add natural language time input field
  - Display active reminders with bell icon on note cards
  - Create RemindersScreen to view all upcoming reminders
  - Implement snooze functionality in notifications
  - Add recurring reminder options (daily, weekly, monthly)
  - _Requirements: 28_

- [ ] 36. Implement reminder notifications
  - Configure notification channels for Android
  - Configure notification categories for iOS
  - Implement notification tap handler to open note
  - Add snooze action to notifications
  - Add mark as done action to notifications
  - Display reminder icon in system tray
  - Handle notification permissions gracefully
  - _Requirements: 28_

- [ ]* 36.1 Write tests for reminder service
  - Test natural language time parsing
  - Test notification scheduling
  - Test geofence monitoring
  - Mock location and notification services
  - _Requirements: 28_

## Phase 10: Statistics and Insights

- [ ] 37. Implement statistics calculation
  - Create StatisticsService class in lib/services/statistics_service.dart
  - Implement calculateStatistics() method
  - Calculate total note count, notes this week, notes this month
  - Calculate current streak and longest streak
  - Calculate total word count across all notes
  - Calculate tag frequency distribution
  - Calculate category distribution
  - Generate creation heatmap data
  - Calculate completion rate
  - Calculate linked notes count and average connections
  - _Requirements: 31_

- [ ] 38. Build statistics dashboard
  - Create StatisticsScreen in lib/screens/statistics_screen.dart
  - Display total note count with icon
  - Create calendar heatmap widget for note creation frequency
  - Create bar chart for tag frequency using charts_flutter
  - Create line chart for creation trends over time
  - Display circular progress indicator for completion rate
  - Show streak counter with fire emoji animation
  - Display most frequently used tags
  - Show recently modified notes list
  - Display longest note by word count
  - _Requirements: 31_

- [ ] 39. Implement statistics export
  - Add export button to statistics screen
  - Generate statistics report as formatted text
  - Export as image using screenshot package
  - Export as PDF using pdf package
  - Share exported statistics via system share sheet
  - _Requirements: 31_


## Phase 11: Daily Notes and Journal Mode

- [ ] 40. Implement daily note functionality
  - Add daily note methods to FirestoreService
  - Implement getOrCreateDailyNote() method
  - Implement getDailyNoteForDate() method
  - Use standardized title format "Daily Note - YYYY-MM-DD"
  - Auto-tag daily notes with "daily" tag
  - _Requirements: 33_

- [ ] 41. Build daily note UI
  - Add "Today" button to home screen
  - Create DailyNoteCalendarScreen in lib/screens/daily_note_calendar_screen.dart
  - Display calendar view with indicators for dates with notes
  - Implement date selection to open specific daily note
  - Add previous/next navigation buttons in daily note view
  - Display streak counter for consecutive daily notes
  - _Requirements: 33_

- [ ] 42. Implement daily note templates
  - Create default daily note template with sections
  - Allow users to customize daily note template
  - Support automatic daily note creation at specified time
  - Add configuration for daily note preferences
  - Implement weekly and monthly note variants
  - _Requirements: 33_

## Phase 12: Integration and Polish

- [ ] 43. Implement data migration
  - Create migration script to add new fields to existing notes
  - Set default values for new fields (empty arrays, null, 0)
  - Calculate word count for existing notes
  - Create default folders collection for existing users
  - Create default templates for existing users
  - Test migration with sample data
  - _Requirements: All_

- [ ] 44. Update Firestore security rules
  - Deploy new security rules for folders subcollection
  - Deploy new security rules for templates subcollection
  - Add collaboration access rules for shared notes
  - Add rules for presence data in Realtime Database
  - Test security rules with Firebase emulator
  - _Requirements: 26, 32, 35_

- [ ] 45. Implement feature discovery and onboarding
  - Create feature tour for new advanced features
  - Add tooltips for first-time use
  - Create "What's New" screen for app updates
  - Implement progressive disclosure for advanced features
  - Add "Learn More" links to feature documentation
  - _Requirements: All_

- [ ] 46. Performance optimization
  - Implement lazy loading for graph view (render only visible nodes)
  - Add pagination for large note lists
  - Optimize search indexing with local SQLite database
  - Implement image caching for faster loading
  - Add debouncing for real-time search and collaboration
  - Optimize Firestore queries with composite indexes
  - _Requirements: All_

- [ ] 47. Error handling and edge cases
  - Add error handling for all service methods
  - Implement retry logic for network failures
  - Add offline queue for operations
  - Handle permission denied scenarios gracefully
  - Add validation for user inputs
  - Implement conflict resolution for edge cases
  - _Requirements: All_

- [ ]* 48. Comprehensive integration testing
  - Test end-to-end voice capture flow
  - Test end-to-end collaboration flow
  - Test end-to-end linking and graph view flow
  - Test end-to-end search flow
  - Test OCR and web clipper flows
  - Test reminder triggers
  - Test folder and template operations
  - _Requirements: All_

- [ ]* 49. Performance testing and optimization
  - Profile app performance with large datasets (1000+ notes)
  - Test graph view with 500+ nodes
  - Test collaboration with 10+ concurrent users
  - Optimize memory usage
  - Reduce app startup time
  - _Requirements: All_

- [ ]* 50. Accessibility testing
  - Test with screen readers (TalkBack, VoiceOver)
  - Verify keyboard navigation
  - Check color contrast ratios
  - Test with large text sizes
  - Verify touch target sizes
  - _Requirements: All_


# Requirements Document

## Introduction

This document specifies advanced features for NoteAssista that will significantly enhance user productivity, content discovery, and note-taking efficiency. These features include AI-powered auto-tagging and smart search, voice-to-text quick capture, linked notes with graph visualization, and real-time collaborative editing. The enhancements leverage modern AI capabilities, speech recognition, and real-time synchronization to create a best-in-class note-taking experience that helps users capture, organize, and discover their knowledge effortlessly.

## Glossary

- **NoteAssista**: The Flutter mobile application system being developed
- **AI Auto-Tagging**: Machine learning-based automatic tag suggestion and assignment based on note content analysis
- **Smart Search**: Natural language search capability that understands context and intent beyond keyword matching
- **Voice-to-Text**: Speech recognition technology that converts spoken words into written text
- **Quick Capture**: Rapid note creation interface optimized for minimal friction
- **Linked Notes**: Bidirectional connections between notes using wiki-style syntax
- **Backlinks**: Automatic references showing which notes link to the current note
- **Graph View**: Visual representation of note connections displayed as an interactive network graph
- **Real-time Collaboration**: Simultaneous multi-user editing with live synchronization
- **Operational Transform**: Algorithm that resolves concurrent edits in collaborative editing
- **Presence Indicators**: Visual markers showing which users are currently viewing or editing a note
- **Firebase ML Kit**: Google's machine learning SDK for mobile applications
- **Speech-to-Text API**: Cloud-based service that converts audio to text
- **Firestore Real-time Listeners**: Database subscriptions that push updates to clients instantly
- **TF-IDF**: Term Frequency-Inverse Document Frequency algorithm for content analysis
- **Semantic Search**: Search that understands meaning and context rather than just matching keywords

## Requirements

### Requirement 21: AI Auto-Tagging

**User Story:** As a user, I want the app to automatically suggest relevant tags for my notes based on their content, so that I can organize my notes effortlessly without manually thinking of tags.

#### Acceptance Criteria

1. WHEN a user creates or edits a note with content, THE NoteAssista SHALL analyze the note title and description to generate tag suggestions
2. THE NoteAssista SHALL display up to five suggested tags ranked by relevance score
3. WHEN tag suggestions are displayed, THE NoteAssista SHALL allow users to accept individual suggestions with a single tap
4. THE NoteAssista SHALL use TF-IDF analysis and keyword extraction to identify significant terms for tag suggestions
5. WHEN a user accepts a suggested tag, THE NoteAssista SHALL add it to the note's tags array and update Firestore
6. THE NoteAssista SHALL learn from user tag acceptance patterns to improve future suggestions
7. THE NoteAssista SHALL store tag usage frequency in the user's profile document for personalization
8. WHEN generating suggestions, THE NoteAssista SHALL prioritize tags the user has previously used
9. THE NoteAssista SHALL perform tag analysis locally on the device to ensure privacy
10. THE NoteAssista SHALL display tag suggestions in a horizontal scrollable chip list below the tags input field

### Requirement 22: Smart Search with Natural Language

**User Story:** As a user, I want to search my notes using natural language queries like "notes from last week about the project", so that I can find information quickly without remembering exact keywords.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a search interface that accepts natural language queries
2. WHEN a user enters a search query, THE NoteAssista SHALL parse temporal expressions (today, yesterday, last week, last month)
3. WHEN temporal expressions are detected, THE NoteAssista SHALL filter notes by the corresponding date range
4. THE NoteAssista SHALL extract keywords from natural language queries by removing stop words
5. WHEN searching, THE NoteAssista SHALL match keywords against note titles, descriptions, and tags
6. THE NoteAssista SHALL rank search results by relevance score combining keyword frequency and recency
7. THE NoteAssista SHALL highlight matching terms in search results
8. WHEN no results match the query, THE NoteAssista SHALL display suggestions for alternative searches
9. THE NoteAssista SHALL support search operators: tag:name, date:YYYY-MM-DD, is:pinned, is:done
10. THE NoteAssista SHALL display search results in real-time as the user types
11. THE NoteAssista SHALL store recent searches locally for quick access
12. THE NoteAssista SHALL provide search history with the ability to clear individual or all entries

### Requirement 23: Voice-to-Text Quick Capture

**User Story:** As a user, I want to create notes by speaking instead of typing, so that I can capture thoughts instantly while driving, walking, or when typing is inconvenient.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a voice capture button on the home screen and add note screen
2. WHEN a user taps the voice capture button, THE NoteAssista SHALL request microphone permission if not already granted
3. WHEN microphone permission is granted, THE NoteAssista SHALL start recording audio and display a visual indicator
4. WHILE recording, THE NoteAssista SHALL display real-time transcription of spoken words
5. WHEN a user stops recording, THE NoteAssista SHALL finalize the transcription and create a new note
6. THE NoteAssista SHALL use the transcribed text as the note description
7. THE NoteAssista SHALL generate a title from the first sentence or first 50 characters of the transcription
8. WHEN transcription completes, THE NoteAssista SHALL allow users to edit the text before saving
9. THE NoteAssista SHALL support continuous voice input for up to five minutes per recording
10. THE NoteAssista SHALL handle background noise by using noise cancellation in the speech recognition
11. IF speech recognition fails or produces no text, THEN THE NoteAssista SHALL display an error message and allow retry
12. THE NoteAssista SHALL work offline by using on-device speech recognition when no internet connection is available
13. THE NoteAssista SHALL provide a floating action button variant that directly opens voice capture mode

### Requirement 24: Linked Notes with Wiki-Style Syntax

**User Story:** As a user, I want to create connections between related notes using simple link syntax, so that I can build a knowledge network and navigate between connected ideas.

#### Acceptance Criteria

1. THE NoteAssista SHALL recognize wiki-style link syntax [[Note Title]] in note descriptions
2. WHEN a user types [[, THE NoteAssista SHALL display an autocomplete dropdown showing existing note titles
3. WHEN a user selects a note from the autocomplete, THE NoteAssista SHALL insert the complete link syntax
4. WHEN displaying a note, THE NoteAssista SHALL render [[Note Title]] as a clickable link
5. WHEN a user taps a linked note, THE NoteAssista SHALL navigate to that note
6. THE NoteAssista SHALL create a new note automatically if a link references a non-existent note title
7. THE NoteAssista SHALL store outgoing links as an array field in the note document
8. THE NoteAssista SHALL compute and display backlinks showing which notes link to the current note
9. THE NoteAssista SHALL display backlinks in a dedicated section at the bottom of the note view
10. WHEN a note is renamed, THE NoteAssista SHALL update all links referencing that note across all user notes
11. THE NoteAssista SHALL support alias syntax [[Note Title|Display Text]] for custom link text
12. THE NoteAssista SHALL highlight broken links (links to deleted notes) in a distinct color

### Requirement 25: Graph View Visualization

**User Story:** As a user, I want to see a visual map of how my notes are connected, so that I can discover relationships and navigate my knowledge network intuitively.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a graph view accessible from the home screen menu
2. WHEN the graph view opens, THE NoteAssista SHALL display all notes as nodes in an interactive graph
3. THE NoteAssista SHALL display links between notes as edges connecting the nodes
4. THE NoteAssista SHALL size nodes based on the number of connections (more connections = larger node)
5. THE NoteAssista SHALL color-code nodes by category or tag for visual distinction
6. WHEN a user taps a node, THE NoteAssista SHALL highlight that node and its direct connections
7. WHEN a user double-taps a node, THE NoteAssista SHALL navigate to that note
8. THE NoteAssista SHALL support pinch-to-zoom and pan gestures for graph navigation
9. THE NoteAssista SHALL use force-directed layout algorithm to position nodes automatically
10. THE NoteAssista SHALL display node labels showing note titles
11. THE NoteAssista SHALL provide a search filter to highlight specific notes in the graph
12. THE NoteAssista SHALL allow users to toggle between full graph and local graph (showing only connections within 2 degrees)
13. THE NoteAssista SHALL animate node positions smoothly when the graph updates

### Requirement 26: Real-time Collaborative Editing

**User Story:** As a user, I want to share notes with others and edit them together in real-time, so that my team can collaborate on meeting notes, project plans, and shared documents.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a share button on each note that generates a shareable link or invite
2. WHEN a note is shared, THE NoteAssista SHALL update the note document with a shared flag and collaborator list
3. THE NoteAssista SHALL allow the note owner to add collaborators by email address
4. WHEN a collaborator is added, THE NoteAssista SHALL send a notification to that user
5. THE NoteAssista SHALL display presence indicators showing which users are currently viewing the note
6. WHEN multiple users edit the same note simultaneously, THE NoteAssista SHALL synchronize changes in real-time
7. THE NoteAssista SHALL display each collaborator's cursor position with their name label
8. THE NoteAssista SHALL use operational transformation to merge concurrent edits without conflicts
9. WHEN a collaborator makes a change, THE NoteAssista SHALL update the note for all viewers within one second
10. THE NoteAssista SHALL highlight text being edited by other users with a colored background
11. THE NoteAssista SHALL allow the note owner to remove collaborators or revoke sharing
12. THE NoteAssista SHALL maintain edit history showing who made which changes and when
13. THE NoteAssista SHALL restrict editing permissions based on collaborator roles (viewer, editor, owner)
14. THE NoteAssista SHALL display a collaborator list with avatars in the note header
15. THE NoteAssista SHALL notify collaborators when someone comments on the shared note

### Requirement 27: Voice Note Attachments

**User Story:** As a user, I want to attach voice recordings to my notes, so that I can capture audio context like meeting discussions or voice reminders alongside written content.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide an attach audio button in the add and edit note screens
2. WHEN a user taps the attach audio button, THE NoteAssista SHALL start recording audio
3. WHILE recording, THE NoteAssista SHALL display a timer showing recording duration
4. WHEN recording stops, THE NoteAssista SHALL save the audio file to Firebase Storage
5. THE NoteAssista SHALL store the audio file URL in the note document
6. WHEN displaying a note with audio, THE NoteAssista SHALL show an audio player widget
7. THE NoteAssista SHALL provide playback controls: play, pause, seek, and playback speed adjustment
8. THE NoteAssista SHALL display audio waveform visualization during playback
9. THE NoteAssista SHALL limit audio recordings to ten minutes per attachment
10. THE NoteAssista SHALL allow multiple audio attachments per note
11. THE NoteAssista SHALL compress audio files to reduce storage and bandwidth usage
12. WHEN a note with audio is deleted, THE NoteAssista SHALL delete the associated audio files from Firebase Storage
13. THE NoteAssista SHALL display audio duration and file size in the note view

### Requirement 28: Smart Reminders with Context

**User Story:** As a user, I want to set intelligent reminders on my notes that trigger based on time or location, so that I'm reminded about tasks at the right moment.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a reminder button in the add and edit note screens
2. WHEN setting a reminder, THE NoteAssista SHALL offer time-based and location-based options
3. THE NoteAssista SHALL allow users to set specific date and time for reminders
4. THE NoteAssista SHALL support natural language time input (tomorrow, next Monday, in 2 hours)
5. WHEN a time-based reminder triggers, THE NoteAssista SHALL display a system notification
6. THE NoteAssista SHALL allow users to set location-based reminders by selecting a place on a map
7. WHEN a user enters the geofence radius of a location reminder, THE NoteAssista SHALL trigger a notification
8. THE NoteAssista SHALL support recurring reminders (daily, weekly, monthly)
9. THE NoteAssista SHALL display active reminders with a bell icon on note cards
10. WHEN a user taps a reminder notification, THE NoteAssista SHALL open the associated note
11. THE NoteAssista SHALL allow users to snooze reminders for a specified duration
12. THE NoteAssista SHALL store reminder data in the note document with trigger conditions
13. THE NoteAssista SHALL request location permission when setting location-based reminders
14. THE NoteAssista SHALL allow users to view all upcoming reminders in a dedicated reminders screen

### Requirement 29: Image OCR and Text Extraction

**User Story:** As a user, I want to capture photos of documents, whiteboards, or handwritten notes and have the text automatically extracted, so that I can make physical content searchable and editable.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a camera button in the add and edit note screens
2. WHEN a user taps the camera button, THE NoteAssista SHALL open the device camera
3. WHEN a photo is captured, THE NoteAssista SHALL process the image using OCR to extract text
4. THE NoteAssista SHALL display the extracted text in an editable text field
5. WHEN OCR completes, THE NoteAssista SHALL allow users to review and correct the extracted text
6. THE NoteAssista SHALL append the extracted text to the note description
7. THE NoteAssista SHALL store the original image in Firebase Storage and link it to the note
8. THE NoteAssista SHALL display the image thumbnail in the note view
9. WHEN a user taps the image thumbnail, THE NoteAssista SHALL open a full-screen image viewer
10. THE NoteAssista SHALL support batch processing of multiple images in a single note
11. THE NoteAssista SHALL work offline by using on-device OCR when no internet connection is available
12. THE NoteAssista SHALL support multiple languages for text extraction
13. THE NoteAssista SHALL optimize image quality before OCR processing to improve accuracy

### Requirement 30: Web Clipper Integration

**User Story:** As a user, I want to save web articles, blog posts, and online content directly to my notes with formatting preserved, so that I can build a personal knowledge base from web content.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a share target that accepts URLs from other apps
2. WHEN a URL is shared to NoteAssista, THE NoteAssista SHALL fetch the web page content
3. THE NoteAssista SHALL extract the main article content removing ads and navigation elements
4. THE NoteAssista SHALL preserve basic formatting (headings, bold, italic, lists, links)
5. THE NoteAssista SHALL create a new note with the extracted content as the description
6. THE NoteAssista SHALL use the article title as the note title
7. THE NoteAssista SHALL store the source URL as metadata in the note document
8. THE NoteAssista SHALL display the source URL as a clickable link in the note view
9. THE NoteAssista SHALL capture the article's featured image if available
10. THE NoteAssista SHALL allow users to edit the clipped content before saving
11. THE NoteAssista SHALL automatically suggest tags based on the article content
12. IF content extraction fails, THEN THE NoteAssista SHALL save the URL as a link with the page title

### Requirement 31: Note Statistics and Insights

**User Story:** As a user, I want to see statistics about my note-taking habits and patterns, so that I can understand my productivity and discover insights about my knowledge base.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a statistics screen accessible from the home screen menu
2. THE NoteAssista SHALL display total note count, notes created this week, and notes created this month
3. THE NoteAssista SHALL show a calendar heatmap visualizing note creation frequency over time
4. THE NoteAssista SHALL display the most frequently used tags with usage counts
5. THE NoteAssista SHALL show average notes per day and current streak of consecutive days with notes
6. THE NoteAssista SHALL calculate and display total word count across all notes
7. THE NoteAssista SHALL show a breakdown of notes by category
8. THE NoteAssista SHALL display the longest note by word count and character count
9. THE NoteAssista SHALL show recently modified notes and most viewed notes
10. THE NoteAssista SHALL provide a time-based chart showing note creation trends over weeks and months
11. THE NoteAssista SHALL display the number of linked notes and average connections per note
12. THE NoteAssista SHALL show completion rate (percentage of notes marked as done)
13. THE NoteAssista SHALL allow users to export statistics as an image or PDF

### Requirement 32: Nested Folders and Notebooks

**User Story:** As a user, I want to organize my notes into folders and sub-folders like a file system, so that I can create a hierarchical structure for different projects and topics.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a folders/notebooks view accessible from the home screen
2. THE NoteAssista SHALL allow users to create new folders with custom names
3. THE NoteAssista SHALL support nested folders up to five levels deep
4. WHEN creating a note, THE NoteAssista SHALL allow users to select a destination folder
5. THE NoteAssista SHALL display notes grouped by their folder in the home screen
6. THE NoteAssista SHALL allow users to move notes between folders using drag-and-drop or a move dialog
7. THE NoteAssista SHALL display folder hierarchy with expandable/collapsible tree view
8. THE NoteAssista SHALL show note count for each folder
9. THE NoteAssista SHALL allow users to rename and delete folders
10. WHEN a folder is deleted, THE NoteAssista SHALL move contained notes to the parent folder or root
11. THE NoteAssista SHALL support folder colors for visual distinction
12. THE NoteAssista SHALL store folder structure in Firestore as a separate collection
13. THE NoteAssista SHALL allow users to favorite folders for quick access

### Requirement 33: Daily Note and Journal Mode

**User Story:** As a user, I want a dedicated daily note that automatically opens for today's date, so that I can maintain a daily journal without manually creating notes each day.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a "Today" button on the home screen that opens the daily note
2. WHEN the daily note button is tapped, THE NoteAssista SHALL create a note for today's date if it doesn't exist
3. THE NoteAssista SHALL use a standardized title format for daily notes (e.g., "Daily Note - YYYY-MM-DD")
4. THE NoteAssista SHALL provide a calendar view showing which dates have daily notes
5. WHEN a user selects a date in the calendar, THE NoteAssista SHALL open that date's daily note
6. THE NoteAssista SHALL support daily note templates with customizable sections
7. THE NoteAssista SHALL allow users to configure automatic daily note creation at a specific time
8. THE NoteAssista SHALL display a streak counter showing consecutive days with daily notes
9. THE NoteAssista SHALL provide navigation buttons to move between previous and next daily notes
10. THE NoteAssista SHALL tag daily notes automatically with a "daily" tag
11. THE NoteAssista SHALL support weekly and monthly note variants with similar functionality

### Requirement 34: Handwriting and Drawing Support

**User Story:** As a user, I want to draw sketches, diagrams, and handwritten notes directly in my notes, so that I can capture visual ideas and concepts that are difficult to express with text.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a drawing button in the add and edit note screens
2. WHEN the drawing button is tapped, THE NoteAssista SHALL open a canvas interface
3. THE NoteAssista SHALL provide drawing tools: pen, highlighter, eraser, and shapes
4. THE NoteAssista SHALL allow users to select pen color and stroke width
5. THE NoteAssista SHALL support touch and stylus input for drawing
6. THE NoteAssista SHALL provide undo and redo functionality for drawing actions
7. WHEN drawing is complete, THE NoteAssista SHALL save the drawing as an image
8. THE NoteAssista SHALL store the drawing image in Firebase Storage and link it to the note
9. THE NoteAssista SHALL display drawing thumbnails inline with note text
10. THE NoteAssista SHALL allow users to edit existing drawings by tapping the thumbnail
11. THE NoteAssista SHALL support multiple drawings per note
12. THE NoteAssista SHALL provide a grid or lined background option for the drawing canvas
13. THE NoteAssista SHALL support handwriting recognition to convert handwritten text to typed text

### Requirement 35: Note Templates Library

**User Story:** As a user, I want to create and save custom note templates, so that I can quickly start notes with predefined structures for recurring note types.

#### Acceptance Criteria

1. THE NoteAssista SHALL provide a templates library accessible from the add note screen
2. THE NoteAssista SHALL include predefined templates: meeting notes, project plan, daily journal, book notes, recipe
3. WHEN creating a note from a template, THE NoteAssista SHALL pre-populate the note with template content
4. THE NoteAssista SHALL allow users to create custom templates from existing notes
5. WHEN saving a custom template, THE NoteAssista SHALL prompt for a template name and description
6. THE NoteAssista SHALL store templates in a separate Firestore collection under the user's document
7. THE NoteAssista SHALL display templates in a grid view with preview thumbnails
8. THE NoteAssista SHALL allow users to edit and delete custom templates
9. THE NoteAssista SHALL support template variables that prompt for user input (e.g., {{project_name}})
10. WHEN a template with variables is used, THE NoteAssista SHALL display input dialogs for each variable
11. THE NoteAssista SHALL allow users to share templates with other users via export/import
12. THE NoteAssista SHALL track template usage frequency and display most-used templates first

### Requirement 36: Drawing URL Loading and Editing

**User Story:** As a user, I want to load and edit existing drawings from URLs, so that I can modify previously saved drawings and continue working on them.

#### Acceptance Criteria

1. WHEN a drawing screen is opened with an existing drawing URL, THE NoteAssista SHALL download the image from Firebase Storage
2. WHEN an existing drawing image is loaded, THE NoteAssista SHALL display it as a background layer on the drawing canvas
3. THE NoteAssista SHALL allow users to draw over the existing image background
4. WHEN editing an existing drawing, THE NoteAssista SHALL preserve the original image while adding new drawing paths on top
5. THE NoteAssista SHALL provide a toggle to show or hide the background image while drawing
6. WHEN saving an edited drawing, THE NoteAssista SHALL composite the background image with new drawing paths into a single image
7. THE NoteAssista SHALL maintain the original image resolution and aspect ratio during editing
8. IF the drawing URL is invalid or the image cannot be loaded, THEN THE NoteAssista SHALL display an error message and open an empty canvas
9. THE NoteAssista SHALL cache downloaded drawing images locally to improve loading performance
10. THE NoteAssista SHALL support editing drawings that were created with different canvas sizes by scaling appropriately


# Supabase Database Setup for NoteAssista

This document provides instructions for setting up the Supabase database schema for the NoteAssista application migration from Firebase to Supabase.

## Prerequisites

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Get your project URL and anon key from the project settings

## Database Schema Setup

1. Open your Supabase project dashboard
2. Navigate to the SQL Editor
3. Copy and paste the contents of `supabase_schema.sql` into the SQL Editor
4. Execute the SQL commands to create the database schema

The schema includes:
- **notes** table: Stores all user notes with full feature support
- **folders** table: Manages folder hierarchy and organization
- **templates** table: Handles note templates and predefined templates
- **daily_note_preferences** table: Stores user preferences for daily notes

## Row Level Security (RLS)

The schema automatically sets up Row Level Security policies to ensure:
- Users can only access their own data
- Shared notes are accessible to collaborators
- Proper authentication is enforced

## Configuration

After setting up the database schema:

1. Update your Flutter app's Supabase configuration
2. Initialize Supabase in your `main.dart` file
3. The `SupabaseService` class will handle all database operations

## Features Supported

The SupabaseService provides equivalent functionality to FirestoreService:

### Notes Operations
- Create, read, update, delete notes
- Stream notes with real-time updates
- Toggle note completion status
- Support for all note features (tags, images, audio, etc.)

### Folder Operations
- Create and manage folder hierarchy
- Move notes between folders
- Update folder properties (color, favorite status)
- Stream folder changes

### Template Operations
- Create and manage custom templates
- Predefined templates for new users
- Template import/export functionality
- Usage tracking

### Daily Notes
- Automatic daily note creation
- Custom template support
- Date-based note organization

## Error Handling

The SupabaseService includes comprehensive error handling:
- User-friendly error messages
- Proper error categorization
- Debug logging for development
- Graceful fallbacks for network issues

## Migration Notes

When migrating from Firebase:
1. The database schema preserves all existing data fields
2. Data types are compatible between Firebase and Supabase
3. All existing functionality is maintained
4. Performance should be equivalent or better

## Testing

The service includes proper error handling and validation:
- Authentication checks for all operations
- Input validation and sanitization
- Proper error responses for all failure cases
- Comprehensive logging for debugging
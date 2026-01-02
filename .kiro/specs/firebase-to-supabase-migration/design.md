# Design Document

## Overview

This design implements a complete migration from Firebase/Firestore to Supabase for the NoteAssista application. The solution replaces all FirestoreService usage with a new SupabaseService, removes Firebase dependencies, and ensures data consistency throughout the migration process.

## Architecture

The migration follows a service replacement pattern with equivalent functionality mapping:

```
┌─────────────────────────────────────────┐
│           Application Layer             │
├─────────────────────────────────────────┤
│         SupabaseService (New)           │
│  ┌─────────────────────────────────────┐│
│  │     Notes Operations Layer          ││
│  ├─────────────────────────────────────┤│
│  │     Folders Operations Layer        ││
│  ├─────────────────────────────────────┤│
│  │     Templates Operations Layer      ││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│         Supabase Client                 │
├─────────────────────────────────────────┤
│         PostgreSQL Database             │
└─────────────────────────────────────────┘
```

## Components and Interfaces

### 1. SupabaseService
- **NotesRepository**: Handles all note CRUD operations
- **FoldersRepository**: Manages folder operations and hierarchy
- **TemplatesRepository**: Handles template creation and management
- **ErrorHandler**: Provides consistent error handling across operations

### 2. Database Schema Mapping
- **Notes Table**: Maps to existing NoteModel structure
- **Folders Table**: Maps to existing FolderModel structure  
- **Templates Table**: Maps to existing TemplateModel structure
- **User Profiles**: Integrates with existing Supabase auth

### 3. Migration Strategy
- **Service Replacement**: Replace FirestoreService instances with SupabaseService
- **Method Mapping**: Ensure 1:1 functionality mapping between services
- **Dependency Cleanup**: Remove all Firebase imports and configurations

## Data Models

### Supabase Table Structures

#### Notes Table
```sql
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  title TEXT NOT NULL,
  description TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  category_image_index INTEGER,
  is_done BOOLEAN DEFAULT FALSE,
  custom_image_url TEXT,
  is_pinned BOOLEAN DEFAULT FALSE,
  tags TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  outgoing_links TEXT[],
  audio_urls TEXT[],
  image_urls TEXT[],
  drawing_urls TEXT[],
  folder_id UUID REFERENCES folders(id),
  is_shared BOOLEAN DEFAULT FALSE,
  collaborator_ids UUID[],
  source_url TEXT,
  reminder JSONB,
  view_count INTEGER DEFAULT 0,
  word_count INTEGER DEFAULT 0,
  owner_id UUID REFERENCES auth.users(id)
);
```

#### Folders Table
```sql
CREATE TABLE folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  color TEXT DEFAULT '#2196F3',
  parent_id UUID REFERENCES folders(id),
  note_count INTEGER DEFAULT 0,
  is_favorite BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### Templates Table
```sql
CREATE TABLE templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  description TEXT,
  content TEXT NOT NULL,
  variables JSONB,
  usage_count INTEGER DEFAULT 0,
  is_custom BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*
Prop
erty 1: Service method equivalence
*For any* FirestoreService method, there should exist an equivalent SupabaseService method with the same functionality and compatible signature
**Validates: Requirements 1.1**

Property 2: Functionality preservation during replacement
*For any* operation that worked with FirestoreService, the same operation should work identically with SupabaseService
**Validates: Requirements 1.2**

Property 3: CRUD operations completeness
*For any* note, folder, or template entity, all create, read, update, delete, and stream operations should work correctly with SupabaseService
**Validates: Requirements 1.3, 1.4, 1.5**

Property 4: Supabase-only database connections
*For any* database operation performed by the application, it should use only Supabase connections and never Firebase connections
**Validates: Requirements 2.2**

Property 5: Functionality preservation after Firebase removal
*For any* application feature that worked before Firebase removal, it should continue working identically after Firebase dependencies are removed
**Validates: Requirements 2.3**

Property 6: Descriptive error messages
*For any* Supabase operation that fails, the error message should be descriptive and provide actionable information
**Validates: Requirements 3.1**

Property 7: Graceful network error handling
*For any* network connectivity issue, the system should handle it gracefully and provide appropriate user feedback
**Validates: Requirements 3.2**

Property 8: Clear authentication error guidance
*For any* authentication error, the system should provide clear guidance for resolution
**Validates: Requirements 3.3**

Property 9: Specific validation error details
*For any* data validation failure, the error should include specific details about what validation failed
**Validates: Requirements 3.4**

Property 10: Verbose debug logging
*For any* Supabase operation when debugging is enabled, verbose logs should be generated
**Validates: Requirements 3.5**

Property 11: Data model field preservation
*For any* data model migrated from Firebase, all existing fields and relationships should be preserved in the Supabase equivalent
**Validates: Requirements 4.1**

Property 12: Schema backward compatibility
*For any* existing data structure, the new Supabase schema should maintain backward compatibility
**Validates: Requirements 4.2**

Property 13: Data integrity across operations
*For any* data operation, the system should maintain data integrity and consistency
**Validates: Requirements 4.3**

Property 14: Edge case fallback mechanisms
*For any* edge case or error condition, the system should provide appropriate fallback mechanisms
**Validates: Requirements 4.4**

Property 15: End-to-end feature validation
*For any* application feature, it should work correctly with the new SupabaseService implementation
**Validates: Requirements 4.5**

## Error Handling

### Supabase Error Categories
- **Authentication Errors**: Invalid credentials, expired sessions, permission denied
- **Network Errors**: Connection timeouts, offline scenarios, server unavailable
- **Data Validation Errors**: Invalid data formats, constraint violations, missing required fields
- **Database Errors**: Query failures, transaction conflicts, schema mismatches

### Error Response Format
```dart
class SupabaseOperationResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final SupabaseErrorType? errorType;
  final Map<String, dynamic>? errorDetails;
}
```

## Testing Strategy

### Unit Testing
- Test each SupabaseService method individually
- Verify error handling for various failure scenarios
- Test data model serialization/deserialization
- Validate SQL query generation and execution

### Property-Based Testing
The testing approach will use property-based testing to verify correctness properties across many inputs:

- **Property Testing Library**: Use `test` package with custom generators for Dart
- **Test Configuration**: Run minimum 100 iterations per property test
- **Property Test Tagging**: Each property-based test will be tagged with format: '**Feature: firebase-to-supabase-migration, Property {number}: {property_text}**'
- **Coverage Requirements**: Each correctness property must be implemented by exactly one property-based test

### Integration Testing
- Test complete user workflows (create note, organize in folders, use templates)
- Verify data consistency across service boundaries
- Test offline/online scenarios and data synchronization
- Validate migration from existing Firebase data (if applicable)

### Migration Validation Testing
- Compare FirestoreService and SupabaseService outputs for identical inputs
- Verify no data loss during service replacement
- Test rollback scenarios and error recovery
- Validate performance characteristics match or improve

## Implementation Phases

### Phase 1: SupabaseService Creation
- Create SupabaseService class with equivalent methods to FirestoreService
- Implement database schema in Supabase
- Set up proper Row Level Security (RLS) policies

### Phase 2: Service Replacement
- Replace FirestoreService usage throughout the application
- Update all import statements and dependencies
- Ensure proper error handling and logging

### Phase 3: Firebase Cleanup
- Remove Firebase initialization from main.dart
- Remove Firebase dependencies from pubspec.yaml
- Delete Firebase configuration files
- Clean up unused imports and code

### Phase 4: Testing and Validation
- Run comprehensive test suite
- Validate all features work correctly
- Performance testing and optimization
- User acceptance testing
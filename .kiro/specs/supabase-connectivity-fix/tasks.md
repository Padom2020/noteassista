# Implementation Plan: Supabase Connectivity Fix

- [x] 1. Create diagnostic utilities and schema validator


  - Create `lib/services/database_diagnostic_service.dart` with methods to validate Supabase initialization, test connectivity, and check authentication status
  - Implement schema validation methods to check if required tables exist
  - Add methods to retrieve table structure information from information_schema
  - _Requirements: 3.1, 3.2, 4.1_

- [ ]* 1.1 Write property test for schema validation completeness
  - **Property 1: Schema Validation Completeness**
  - **Validates: Requirements 3.1, 4.1**



- [ ] 2. Implement RLS policy validator
  - Create methods in `DatabaseDiagnosticService` to validate RLS is enabled on tables
  - Implement RLS policy verification logic
  - Add test method to verify actual data access with current user
  - _Requirements: 3.3, 4.2_

- [x]* 2.1 Write property test for RLS policy enforcement


  - **Property 3: RLS Policy Enforcement**
  - **Validates: Requirements 3.3, 4.2**

- [ ] 3. Create schema initializer and cache refresh manager
  - Implement `SchemaInitializer` class with methods to create tables, indexes, and RLS policies
  - Create `CacheRefreshManager` class to handle PostgREST schema cache refresh
  - Add retry logic with exponential backoff for cache refresh operations
  - _Requirements: 3.4, 5.3_

- [ ]* 3.1 Write property test for connectivity test idempotence
  - **Property 2: Connectivity Test Idempotence**
  - **Validates: Requirements 3.1, 5.2**



- [ ]* 3.2 Write property test for schema cache refresh round trip
  - **Property 6: Schema Cache Refresh Round Trip**
  - **Validates: Requirements 3.4, 5.3**

- [ ] 4. Enhance error handling in SupabaseService
  - Update `_getErrorMessage()` to provide specific guidance for PGRST205 errors
  - Add diagnostic suggestions to error messages


  - Implement error recovery suggestions based on error type
  - _Requirements: 5.1, 3.5_

- [ ]* 4.1 Write property test for error message clarity
  - **Property 4: Error Message Clarity**
  - **Validates: Requirements 5.1**

- [x] 5. Implement retry mechanism with exponential backoff


  - Update `_executeWithRetry()` to use exponential backoff strategy
  - Add configurable retry delays and maximum attempts
  - Implement network connectivity checks before retrying
  - _Requirements: 5.2_

- [ ]* 5.1 Write property test for retry mechanism correctness
  - **Property 5: Retry Mechanism Correctness**
  - **Validates: Requirements 5.2**



- [ ] 6. Create diagnostic report generator
  - Implement `generateDiagnosticReport()` method that checks all connectivity aspects
  - Create `DiagnosticResult` class to hold comprehensive diagnostic information
  - Add method to format diagnostic results for user display
  - _Requirements: 3.2, 3.4, 4.5_

- [ ]* 6.1 Write property test for diagnostic report accuracy
  - **Property 7: Diagnostic Report Accuracy**
  - **Validates: Requirements 3.2, 3.4**



- [ ] 7. Integrate diagnostics into SupabaseService initialization
  - Add automatic schema validation on first connection
  - Implement schema initialization if tables don't exist
  - Add cache refresh attempt on PGRST205 errors
  - _Requirements: 1.1, 2.1, 3.1_

- [ ]* 7.1 Write unit tests for diagnostic integration
  - Test that schema validation runs on initialization
  - Test that schema is created if missing
  - Test that cache refresh is attempted on errors
  - _Requirements: 1.1, 2.1, 3.1_

- [ ] 8. Implement note operations with error recovery
  - Update `createNote()` to handle PGRST205 errors with automatic recovery
  - Update `getNoteById()` to retry with cache refresh on failure
  - Update `streamNotesByFolder()` to handle schema errors gracefully
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x]* 8.1 Write property test for note creation success


  - **Property**: Note creation without PGRST205 errors
  - **Validates: Requirements 1.1**

- [ ]* 8.2 Write property test for note retrieval success
  - **Property**: Note retrieval returns created notes
  - **Validates: Requirements 1.2**

- [ ]* 8.3 Write property test for note update persistence
  - **Property**: Note updates are persisted to database
  - **Validates: Requirements 1.3**

- [ ]* 8.4 Write property test for note deletion
  - **Property**: Deleted notes are removed from database
  - **Validates: Requirements 1.4**

- [x] 9. Implement folder operations with error recovery


  - Update `createFolder()` to handle PGRST205 errors with automatic recovery
  - Update `getFolders()` to retry with cache refresh on failure
  - Update `moveNoteToFolder()` to maintain consistency on errors
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ]* 9.1 Write property test for folder creation success
  - **Property**: Folder creation without errors
  - **Validates: Requirements 2.1**

- [x]* 9.2 Write property test for folder note relationships


  - **Property**: Moving notes between folders updates relationships

  - **Validates: Requirements 2.2**

- [ ]* 9.3 Write property test for folder deletion hierarchy
  - **Property**: Folder deletion maintains hierarchy
  - **Validates: Requirements 2.3**

- [ ] 10. Create user-facing error messages and recovery UI
  - Create `ErrorRecoveryWidget` to display diagnostic information
  - Implement retry button for failed operations
  - Add "Run Diagnostics" button to app settings
  - _Requirements: 5.1, 3.5_

- [ ]* 10.1 Write unit tests for error recovery UI
  - Test that error messages are displayed correctly
  - Test that retry button triggers operation retry
  - Test that diagnostics button runs full diagnostic
  - _Requirements: 5.1, 3.5_

- [x] 11. Checkpoint - Ensure all tests pass


  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Integration testing with real Supabase
  - Test full workflow with actual Supabase instance
  - Verify schema initialization works correctly
  - Test RLS policies with multiple users
  - Verify error recovery mechanisms work end-to-end
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 4.2, 4.3_

- [ ]* 12.1 Write integration tests for note operations
  - Test note creation, retrieval, update, deletion with real database
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [ ]* 12.2 Write integration tests for folder operations
  - Test folder creation, retrieval, deletion with real database
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ]* 12.3 Write integration tests for RLS enforcement
  - Test that users can only access their own data
  - Test that shared notes are accessible to collaborators
  - _Requirements: 3.3, 4.2, 4.3_

- [ ] 13. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

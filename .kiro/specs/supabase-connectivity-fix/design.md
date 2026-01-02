# Design Document: Supabase Connectivity Fix

## Overview

The NoteAssista application is experiencing persistent database connectivity issues manifested as PostgrestException PGRST205 errors ("tables cannot be found in schema cache"). This design addresses the root cause diagnosis and resolution strategy, including database schema validation, connectivity testing, and recovery mechanisms.

## Architecture

The solution follows a layered approach:

1. **Diagnostic Layer** - Validates database connectivity and schema state
2. **Schema Validation Layer** - Verifies table existence and structure
3. **Recovery Layer** - Implements schema initialization and cache refresh
4. **Error Handling Layer** - Provides meaningful feedback and recovery suggestions

## Components and Interfaces

### 1. Database Connectivity Validator
- **Purpose**: Verify Supabase client initialization and basic connectivity
- **Methods**:
  - `validateSupabaseInitialization()` - Check if Supabase client is properly initialized
  - `testDatabaseConnection()` - Perform a lightweight connectivity test
  - `checkAuthenticationStatus()` - Verify user authentication state

### 2. Schema Validator
- **Purpose**: Verify database schema structure and table accessibility
- **Methods**:
  - `validateTableExists(tableName)` - Check if a specific table exists
  - `validateTableStructure(tableName)` - Verify table has expected columns
  - `validateAllRequiredTables()` - Check all tables (notes, folders, templates)
  - `getTableSchema(tableName)` - Retrieve table structure information

### 3. RLS Policy Validator
- **Purpose**: Verify Row Level Security policies are properly configured
- **Methods**:
  - `validateRLSEnabled(tableName)` - Check if RLS is enabled on table
  - `validateRLSPolicies(tableName)` - Verify policies exist and are correct
  - `testRLSAccess()` - Test actual data access with current user

### 4. Schema Initializer
- **Purpose**: Create or recreate database schema if needed
- **Methods**:
  - `initializeSchema()` - Run full schema creation
  - `createTable(tableName)` - Create a specific table
  - `createIndexes()` - Create performance indexes
  - `createRLSPolicies()` - Set up Row Level Security

### 5. Cache Refresh Manager
- **Purpose**: Handle PostgREST schema cache refresh
- **Methods**:
  - `refreshSchemaCache()` - Trigger cache refresh
  - `waitForCacheRefresh()` - Wait for cache to be ready
  - `retryWithCacheRefresh()` - Retry operation after cache refresh

## Data Models

### DiagnosticResult
```dart
class DiagnosticResult {
  final bool isHealthy;
  final List<String> issues;
  final List<String> suggestions;
  final Map<String, dynamic> details;
}
```

### SchemaValidationResult
```dart
class SchemaValidationResult {
  final bool allTablesExist;
  final Map<String, bool> tableStatus;
  final List<String> missingTables;
  final List<String> structureIssues;
}
```

### ConnectivityStatus
```dart
enum ConnectivityStatus {
  healthy,
  authenticationFailed,
  schemaNotFound,
  rlsBlocked,
  networkError,
  unknown,
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. 
Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Schema Validation Completeness
*For any* database connection, validating the schema should check all required tables (notes, folders, templates, daily_note_preferences) and report the status of each table.
**Validates: Requirements 3.1, 4.1**

### Property 2: Connectivity Test Idempotence
*For any* valid Supabase connection, running the connectivity test multiple times should produce the same result without side effects.
**Validates: Requirements 3.1, 5.2**

### Property 3: RLS Policy Enforcement
*For any* authenticated user, Row Level Security policies should prevent access to other users' data while allowing access to their own data.
**Validates: Requirements 3.3, 4.2**

### Property 4: Error Message Clarity
*For any* database error, the system should provide a user-friendly error message that includes the error type, affected operation, and suggested remediation steps.
**Validates: Requirements 5.1**

### Property 5: Retry Mechanism Correctness
*For any* transient network error, the retry mechanism should attempt the operation again with exponential backoff and eventually succeed or fail with a clear error message.
**Validates: Requirements 5.2**

### Property 6: Schema Cache Refresh Round Trip
*For any* schema modification, refreshing the cache and then attempting a database operation should succeed if the schema is valid.
**Validates: Requirements 3.4, 5.3**

### Property 7: Diagnostic Report Accuracy
*For any* database state, the diagnostic report should accurately reflect the actual connectivity status and provide actionable suggestions.
**Validates: Requirements 3.2, 3.4**

## Error Handling

### PGRST205 Error (Tables Not Found)
- **Root Causes**:
  - Schema not initialized in Supabase
  - PostgREST schema cache out of sync
  - Incorrect table names or schema
  - RLS policies preventing access
  
- **Recovery Strategy**:
  1. Verify Supabase initialization
  2. Check if tables exist via information_schema
  3. Attempt schema cache refresh
  4. If tables don't exist, initialize schema
  5. Retry operation

### Authentication Errors
- **Root Causes**:
  - User not authenticated
  - Session expired
  - Invalid credentials
  
- **Recovery Strategy**:
  1. Check authentication status
  2. Prompt user to re-authenticate if needed
  3. Verify JWT token validity
  4. Retry operation after authentication

### Network Errors
- **Root Causes**:
  - No internet connection
  - Supabase service unavailable
  - Network timeout
  
- **Recovery Strategy**:
  1. Check network connectivity
  2. Implement exponential backoff retry
  3. Provide offline fallback if available
  4. Queue operations for later retry

## Testing Strategy

### Unit Testing
- Test diagnostic validators with mocked Supabase responses
- Test error message generation for various error types
- Test retry logic with simulated failures
- Test schema validation logic with various table structures

### Property-Based Testing
- **Property 1**: Generate random table configurations and verify all are checked
- **Property 2**: Run connectivity tests multiple times and verify consistency
- **Property 3**: Generate random user IDs and verify RLS enforcement
- **Property 4**: Generate various error types and verify message quality
- **Property 5**: Simulate transient failures and verify retry behavior
- **Property 6**: Verify cache refresh followed by operations succeeds
- **Property 7**: Generate various database states and verify diagnostic accuracy

### Integration Testing
- Test actual Supabase connection with real credentials
- Test schema initialization in test database
- Test RLS policies with multiple users
- Test error recovery workflows end-to-end

### Testing Framework
- **Unit/Property Tests**: Use `test` package with `test_fixtures` for Dart
- **Integration Tests**: Use `integration_test` package with real Supabase instance
- **Minimum iterations**: 100 per property-based test

## Implementation Approach

1. **Phase 1**: Create diagnostic utilities to identify the root cause
2. **Phase 2**: Implement schema validation and initialization
3. **Phase 3**: Add cache refresh and retry mechanisms
4. **Phase 4**: Integrate diagnostics into SupabaseService
5. **Phase 5**: Add user-facing error messages and recovery UI
6. **Phase 6**: Comprehensive testing and validation

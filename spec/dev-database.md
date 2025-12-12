# Database Implementation Guide

**Version**: 2.0
**Audience**: Software Developers
**Last Updated**: 2025-11-24
**Status**: Draft

> **Scope**: Cloud SQL implementation, Dart server database access, development workflow
>
> **See**: prd-database.md for schema architecture and Event Sourcing pattern
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment model
> **See**: ops-database-setup.md for production deployment procedures
> **See**: ops-database-migration.md for migration strategies

---

## Executive Summary

This guide covers **how to implement and deploy** the database using Google Cloud SQL for PostgreSQL. Each sponsor has a dedicated GCP project with Cloud SQL instance + Identity Platform + Cloud Run backend.

**Technology Stack**:
- **Platform**: Google Cloud Platform (Cloud SQL + Identity Platform + Cloud Run)
- **Database**: PostgreSQL 15+ (Cloud SQL managed)
- **Backend**: Dart server on Cloud Run
- **CLI**: gcloud CLI for deployment, psql for database access

---

## Development Environment Setup

### Install Required Tools

```bash
# Install Google Cloud SDK (macOS)
brew install --cask google-cloud-sdk

# Initialize gcloud
gcloud init

# Install components
gcloud components install cloud-sql-proxy

# Install PostgreSQL client
brew install postgresql

# Verify installation
gcloud --version
psql --version
cloud-sql-proxy --version
```

### Authenticate with GCP

```bash
# Login to GCP (opens browser)
gcloud auth login

# Set default project
gcloud config set project your-project-id

# Verify
gcloud config list
```

### Cloud SQL Proxy for Local Development

Cloud SQL Proxy provides secure access to Cloud SQL from local development:

```bash
# Start Cloud SQL Proxy (keep running in background)
cloud-sql-proxy your-project:us-central1:your-instance \
  --port=5432

# Connect with psql
psql "host=127.0.0.1 port=5432 user=app_user dbname=clinical_diary"

# Or use connection string
export DATABASE_URL="postgresql://app_user:password@127.0.0.1:5432/clinical_diary"
```

---

## Repository Structure

```
clinical-diary/                      # Public core repository
  packages/
     database/
          schema.sql              # Core tables
          triggers.sql            # Event Sourcing triggers
          functions.sql           # Helper functions
          rls_policies.sql        # Row-level security
          indexes.sql             # Performance indexes

clinical-diary-{sponsor}/            # Private sponsor repository
  database/
      extensions.sql              # Sponsor-specific tables/functions
      seed_data.sql               # Initial data for sponsor
  server/
      bin/server.dart             # Cloud Run server entry point
      lib/
          database/               # Database connection layer
          services/               # Business logic
          middleware/             # Auth middleware
  Dockerfile                      # Cloud Run container
```

---

## Core Schema Deployment

# REQ-d00007: Database Schema Implementation and Deployment

**Level**: Dev | **Implements**: o00004 | **Status**: Draft

Database schema files SHALL be implemented as versioned SQL scripts organized by functional area (schema, triggers, functions, RLS policies, indexes), enabling repeatable deployment to sponsor-specific Cloud SQL instances while maintaining schema consistency across all sponsors.

Implementation SHALL include:
- SQL files organized by functional area (schema.sql, triggers.sql, functions.sql, rls_policies.sql, indexes.sql)
- Schema versioning following semantic versioning conventions
- Deployment scripts validating schema integrity after execution
- gcloud CLI integration for automated deployment
- Migration scripts for schema evolution with rollback capability
- Documentation of schema dependencies and deployment order

**Rationale**: Implements database schema deployment (o00004) at the development level. gcloud CLI and Cloud SQL provide tooling for SQL execution and schema management, enabling consistent schema deployment across multiple sponsor databases.

**Acceptance Criteria**:
- All schema files execute without errors on PostgreSQL 15+
- Deployment scripts validate table creation and trigger installation
- Schema deployed successfully to Cloud SQL test instance
- Migration scripts include both forward and rollback operations
- Deployment process documented with step-by-step instructions
- Schema version tracked in database metadata table

*End* *Database Schema Implementation and Deployment* | **Hash**: 18df4bc0
---

# REQ-d00011: Multi-Site Schema Implementation

**Level**: Dev | **Implements**: o00011 | **Status**: Draft

The database schema SHALL implement multi-site support through sites table, site assignment tables, and row-level security policies that enforce site-based data access control within each sponsor's database.

Implementation SHALL include:
- sites table with site metadata (site_id, site_name, site_number, location, contact)
- investigator_site_assignments table mapping investigators to sites
- analyst_site_assignments table mapping analysts to sites
- user_site_assignments table mapping patients to enrollment sites
- RLS policies filtering queries by user's assigned sites
- Site context captured in all audit trail records

**Rationale**: Implements multi-site configuration (o00011) at the database code level. Sites table and assignment tables enable flexible multi-site trial management, while RLS policies enforce site-level access control automatically at the database layer.

**Acceptance Criteria**:
- sites table supports unlimited sites per sponsor
- Assignment tables support many-to-many site relationships
- RLS policies correctly filter data by assigned sites
- Site context preserved in record_audit for compliance
- Site-based queries perform efficiently with proper indexes
- Site assignments modifiable by administrators only

*End* *Multi-Site Schema Implementation* | **Hash**: bf785d33
---

### Option 1: Direct SQL Execution (Recommended)

Execute schema files directly against Cloud SQL via Cloud SQL Proxy:

```bash
# Ensure Cloud SQL Proxy is running
cloud-sql-proxy your-project:us-central1:your-instance --port=5432 &

# Set connection string
export PGHOST=127.0.0.1
export PGPORT=5432
export PGUSER=app_user
export PGDATABASE=clinical_diary
export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-password)

# Deploy core schema in order
cd packages/database
for file in schema.sql triggers.sql functions.sql rls_policies.sql indexes.sql; do
  echo "Executing $file..."
  psql -f $file
done

# Verify deployment
psql -c "\dt" # List tables
psql -c "SELECT version FROM schema_metadata ORDER BY applied_at DESC LIMIT 1;"
```

### Option 2: Automated Deployment Script

```bash
#!/bin/bash
# deploy-schema.sh

set -e

PROJECT_ID=${1:-$(gcloud config get-value project)}
INSTANCE_NAME=${2:-clinical-diary}
DATABASE=${3:-clinical_diary}

echo "Deploying schema to $PROJECT_ID:$INSTANCE_NAME:$DATABASE"

# Start Cloud SQL Proxy in background
cloud-sql-proxy "$PROJECT_ID:us-central1:$INSTANCE_NAME" --port=5432 &
PROXY_PID=$!
sleep 3

# Get credentials from Secret Manager
DB_PASSWORD=$(gcloud secrets versions access latest --secret=db-app-password)

export PGHOST=127.0.0.1
export PGPORT=5432
export PGUSER=app_user
export PGDATABASE=$DATABASE
export PGPASSWORD=$DB_PASSWORD

# Execute schema files
for file in schema.sql triggers.sql functions.sql rls_policies.sql indexes.sql; do
  if [ -f "$file" ]; then
    echo "Applying $file..."
    psql -f "$file" || { echo "Failed on $file"; kill $PROXY_PID; exit 1; }
  fi
done

# Cleanup
kill $PROXY_PID

echo "Schema deployment complete"
```

---

## Sponsor Extensions Deployment

After core schema is deployed, add sponsor-specific extensions:

```bash
# In sponsor repository
cd database

# Deploy sponsor extensions
psql -f extensions.sql

# Verify deployment
psql -c "\dt custom_*"
```

**Example extensions.sql**:
```sql
-- Sponsor-specific custom fields table
CREATE TABLE IF NOT EXISTS custom_patient_fields (
  patient_id TEXT PRIMARY KEY,
  sponsor_custom_id TEXT,
  enrollment_cohort TEXT,
  custom_data JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS policies for custom table
ALTER TABLE custom_patient_fields ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_select_own ON custom_patient_fields
  FOR SELECT
  USING (patient_id = current_setting('app.user_id', true));

-- Sponsor-specific function
CREATE OR REPLACE FUNCTION calculate_sponsor_metric(p_patient_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Sponsor-specific calculation logic
  RETURN '{"metric": "value"}'::jsonb;
END;
$$;
```

---

## Cloud Run Dart Server

### Database Connection Layer

The Dart server on Cloud Run connects to Cloud SQL using Unix sockets (recommended) or Cloud SQL Connector.

**Database Configuration** (lib/database/config.dart):

```dart
import 'dart:io';

class DatabaseConfig {
  /// Cloud SQL instance connection name
  /// Format: project:region:instance
  final String instanceConnectionName;

  /// Database name
  final String database;

  /// Database user
  final String user;

  /// Database password (from Secret Manager)
  final String password;

  /// Unix socket path for Cloud Run
  /// /cloudsql/{instance-connection-name}
  String get socketPath => '/cloudsql/$instanceConnectionName';

  /// Connection string for Cloud Run (Unix socket)
  String get cloudRunConnectionString =>
      'postgres://$user:$password@/$database?host=$socketPath';

  /// Connection string for local dev (via Cloud SQL Proxy)
  String get localConnectionString =>
      'postgres://$user:$password@127.0.0.1:5432/$database';

  DatabaseConfig({
    required this.instanceConnectionName,
    required this.database,
    required this.user,
    required this.password,
  });

  factory DatabaseConfig.fromEnvironment() {
    return DatabaseConfig(
      instanceConnectionName: Platform.environment['DATABASE_INSTANCE']
          ?? 'project:region:instance',
      database: Platform.environment['DATABASE_NAME'] ?? 'clinical_diary',
      user: Platform.environment['DATABASE_USER'] ?? 'app_user',
      password: Platform.environment['DATABASE_PASSWORD'] ?? '',
    );
  }

  /// Get appropriate connection string based on environment
  String get connectionString {
    // In Cloud Run, use Unix socket
    if (Platform.environment.containsKey('K_SERVICE')) {
      return cloudRunConnectionString;
    }
    // Local development uses TCP via Cloud SQL Proxy
    return localConnectionString;
  }
}
```

**Database Connection Pool** (lib/database/pool.dart):

```dart
import 'package:postgres/postgres.dart';
import 'config.dart';

class DatabasePool {
  static Pool? _pool;
  static final DatabaseConfig _config = DatabaseConfig.fromEnvironment();

  /// Initialize connection pool
  static Future<void> initialize() async {
    final endpoint = Endpoint(
      host: _config.socketPath,
      database: _config.database,
      username: _config.user,
      password: _config.password,
      isUnixSocket: true,
    );

    _pool = Pool.withEndpoints(
      [endpoint],
      settings: PoolSettings(
        maxConnectionCount: 10,
        maxConnectionAge: Duration(minutes: 30),
        sslMode: SslMode.disable, // Unix socket doesn't need SSL
      ),
    );
  }

  /// Get a connection from the pool
  static Future<Connection> getConnection() async {
    if (_pool == null) {
      await initialize();
    }
    return _pool!.run((connection) async => connection);
  }

  /// Execute a query with the pool
  static Future<Result> query(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    if (_pool == null) {
      await initialize();
    }
    return _pool!.execute(Sql.named(sql), parameters: parameters);
  }

  /// Close the pool
  static Future<void> close() async {
    await _pool?.close();
    _pool = null;
  }
}
```

### Setting RLS Context

The Dart server must set session variables for RLS policies before queries:

```dart
import 'package:postgres/postgres.dart';

class RlsContext {
  final String userId;
  final String role;
  final String? siteId;
  final String sponsorId;

  RlsContext({
    required this.userId,
    required this.role,
    this.siteId,
    required this.sponsorId,
  });

  /// Set RLS context for current session
  Future<void> apply(Connection connection) async {
    await connection.execute(
      Sql.named('''
        SELECT set_config('app.user_id', @userId, true),
               set_config('app.role', @role, true),
               set_config('app.site_id', @siteId, true),
               set_config('app.sponsor_id', @sponsorId, true)
      '''),
      parameters: {
        'userId': userId,
        'role': role,
        'siteId': siteId ?? '',
        'sponsorId': sponsorId,
      },
    );
  }

  /// Create from verified Firebase token claims
  factory RlsContext.fromClaims(Map<String, dynamic> claims) {
    return RlsContext(
      userId: claims['sub'] as String,
      role: claims['role'] as String? ?? 'USER',
      siteId: claims['site_id'] as String?,
      sponsorId: claims['sponsor_id'] as String,
    );
  }
}
```

**Using RLS Context in Repository**:

```dart
class RecordRepository {
  final Connection _connection;
  final RlsContext _context;

  RecordRepository(this._connection, this._context);

  Future<List<Map<String, dynamic>>> getPatientRecords() async {
    // Set RLS context
    await _context.apply(_connection);

    // Query automatically filtered by RLS policies
    final result = await _connection.execute(
      Sql.named('''
        SELECT event_uuid, patient_id, current_data, version, updated_at
        FROM record_state
        WHERE is_deleted = false
        ORDER BY updated_at DESC
      '''),
    );

    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<void> insertAuditEvent({
    required String eventUuid,
    required String operation,
    required Map<String, dynamic> data,
    required String changeReason,
    String? parentAuditId,
  }) async {
    await _context.apply(_connection);

    await _connection.execute(
      Sql.named('''
        INSERT INTO record_audit (
          event_uuid, patient_id, site_id, operation, data,
          created_by, role, client_timestamp, change_reason, parent_audit_id
        ) VALUES (
          @eventUuid,
          current_setting('app.user_id', true),
          current_setting('app.site_id', true),
          @operation,
          @data::jsonb,
          current_setting('app.user_id', true),
          current_setting('app.role', true),
          @clientTimestamp,
          @changeReason,
          @parentAuditId
        )
      '''),
      parameters: {
        'eventUuid': eventUuid,
        'operation': operation,
        'data': data,
        'clientTimestamp': DateTime.now().toIso8601String(),
        'changeReason': changeReason,
        'parentAuditId': parentAuditId,
      },
    );
  }
}
```

---

## EDC Sync Worker

For sponsors using proxy mode (EDC sync), implement as a Cloud Run Job or scheduled Cloud Run service.

> **CRITICAL**: Events sync in strict sequential order. If event N fails, all subsequent events block until event N succeeds. Worker continuously processes events in `audit_id` order.

**EDC Sync Service** (lib/services/edc_sync_service.dart):

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/pool.dart';

class EdcSyncService {
  final String edcEndpoint;
  final String edcApiKey;

  EdcSyncService({
    required this.edcEndpoint,
    required this.edcApiKey,
  });

  /// Run continuous sync worker
  Future<void> runWorker() async {
    while (true) {
      try {
        await _processNextEvent();
      } catch (e) {
        print('Sync worker error: $e');
        await Future.delayed(Duration(seconds: 5));
      }
    }
  }

  Future<void> _processNextEvent() async {
    // Find highest successfully synced event
    final lastSuccess = await DatabasePool.query('''
      SELECT audit_id FROM edc_sync_log
      WHERE sync_status = 'SUCCESS'
      ORDER BY audit_id DESC
      LIMIT 1
    ''');

    final lastSyncedId = lastSuccess.isEmpty
        ? 0
        : lastSuccess.first[0] as int;

    // Get next event to sync
    final nextEvent = await DatabasePool.query(
      '''
        SELECT audit_id, event_uuid, patient_id, operation, data
        FROM record_audit
        WHERE audit_id > @lastId
        ORDER BY audit_id ASC
        LIMIT 1
      ''',
      parameters: {'lastId': lastSyncedId},
    );

    if (nextEvent.isEmpty) {
      await Future.delayed(Duration(seconds: 1));
      return;
    }

    final event = nextEvent.first.toColumnMap();
    final auditId = event['audit_id'] as int;
    final eventUuid = event['event_uuid'] as String;

    // Transform to EDC format
    final edcPayload = _transformToEdcFormat(event);

    // Attempt sync
    try {
      final response = await http.post(
        Uri.parse(edcEndpoint),
        headers: {
          'Authorization': 'Bearer $edcApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(edcPayload),
      );

      if (response.statusCode == 200) {
        // Success
        await DatabasePool.query(
          '''
            INSERT INTO edc_sync_log (audit_id, event_uuid, sync_status, edc_response)
            VALUES (@auditId, @eventUuid, 'SUCCESS', @response::jsonb)
          ''',
          parameters: {
            'auditId': auditId,
            'eventUuid': eventUuid,
            'response': response.body,
          },
        );
      } else {
        await _handleSyncFailure(auditId, eventUuid, response.body);
      }
    } catch (e) {
      await _handleSyncFailure(auditId, eventUuid, e.toString());
    }
  }

  Future<void> _handleSyncFailure(int auditId, String eventUuid, String error) async {
    // Get current attempt count
    final existing = await DatabasePool.query(
      'SELECT attempt_count FROM edc_sync_log WHERE audit_id = @auditId',
      parameters: {'auditId': auditId},
    );

    final attemptCount = existing.isEmpty
        ? 1
        : (existing.first[0] as int) + 1;

    await DatabasePool.query(
      '''
        INSERT INTO edc_sync_log (audit_id, event_uuid, sync_status, attempt_count, last_error)
        VALUES (@auditId, @eventUuid, 'FAILED', @attempts, @error)
        ON CONFLICT (audit_id) DO UPDATE SET
          sync_status = 'FAILED',
          attempt_count = @attempts,
          last_error = @error,
          synced_at = now()
      ''',
      parameters: {
        'auditId': auditId,
        'eventUuid': eventUuid,
        'attempts': attemptCount,
        'error': error,
      },
    );

    // Exponential backoff
    final backoff = Duration(
      milliseconds: (1 << attemptCount.clamp(0, 6)) * 1000,
    );
    await Future.delayed(backoff);
  }

  Map<String, dynamic> _transformToEdcFormat(Map<String, dynamic> event) {
    // Sponsor-specific transformation
    return {
      'subject_id': event['patient_id'],
      'visit_date': event['data']['date'],
      // ... other EDC fields
    };
  }
}
```

---

## Local Development Workflow

### Start Local Environment

```bash
# Start Cloud SQL Proxy
cloud-sql-proxy your-project:us-central1:your-instance --port=5432 &

# Set environment variables
export DATABASE_URL="postgresql://app_user:password@127.0.0.1:5432/clinical_diary"
export DATABASE_INSTANCE="your-project:us-central1:your-instance"
export DATABASE_NAME="clinical_diary"
export DATABASE_USER="app_user"
export DATABASE_PASSWORD=$(gcloud secrets versions access latest --secret=db-password)

# Or use Doppler
doppler run -- dart run bin/server.dart
```

### Apply Schema Locally

```bash
# Execute schema files
psql $DATABASE_URL -f packages/database/schema.sql
psql $DATABASE_URL -f packages/database/triggers.sql
psql $DATABASE_URL -f packages/database/functions.sql
psql $DATABASE_URL -f packages/database/rls_policies.sql
psql $DATABASE_URL -f packages/database/indexes.sql
```

### Run Dart Server Locally

```bash
cd server

# Get dependencies
dart pub get

# Run server (connects via Cloud SQL Proxy)
doppler run -- dart run bin/server.dart

# Or with environment variables
DATABASE_INSTANCE=project:region:instance \
DATABASE_NAME=clinical_diary \
DATABASE_USER=app_user \
DATABASE_PASSWORD=secret \
dart run bin/server.dart
```

### Test Database Connection

```dart
// test/database_test.dart
import 'package:test/test.dart';
import 'package:server/database/pool.dart';

void main() {
  setUpAll(() async {
    await DatabasePool.initialize();
  });

  tearDownAll(() async {
    await DatabasePool.close();
  });

  test('Database connection works', () async {
    final result = await DatabasePool.query('SELECT 1 as test');
    expect(result.first[0], equals(1));
  });

  test('Schema version exists', () async {
    final result = await DatabasePool.query(
      'SELECT version FROM schema_metadata ORDER BY applied_at DESC LIMIT 1'
    );
    expect(result, isNotEmpty);
  });
}
```

---

## Migration Workflow

### Creating Migrations

```bash
# Create timestamped migration file
TIMESTAMP=$(date +%Y%m%d%H%M%S)
touch database/migrations/${TIMESTAMP}_add_custom_fields.sql
```

**Migration File Example**:
```sql
-- database/migrations/20251124120000_add_custom_fields.sql

-- Migration metadata
-- Version: 1.2.0
-- Description: Add custom metadata column to record_audit

BEGIN;

-- Add new column to record_audit
ALTER TABLE record_audit
ADD COLUMN IF NOT EXISTS custom_metadata JSONB;

-- Create index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_record_audit_custom_metadata
ON record_audit USING GIN (custom_metadata);

-- Add comment
COMMENT ON COLUMN record_audit.custom_metadata IS
  'Sponsor-specific custom metadata fields';

-- Update schema version
INSERT INTO schema_metadata (version, description, applied_at)
VALUES ('1.2.0', 'Add custom metadata column', now());

COMMIT;
```

### Applying Migrations

```bash
# Apply single migration
psql $DATABASE_URL -f database/migrations/20251124120000_add_custom_fields.sql

# Apply all pending migrations
for migration in database/migrations/*.sql; do
  echo "Applying $migration..."
  psql $DATABASE_URL -f "$migration"
done

# Check migration status
psql $DATABASE_URL -c "SELECT version, description, applied_at FROM schema_metadata ORDER BY applied_at DESC;"
```

### Rollback Strategy

Each migration should have a corresponding rollback file:

```sql
-- database/migrations/20251124120000_add_custom_fields.rollback.sql

BEGIN;

-- Remove index
DROP INDEX IF EXISTS idx_record_audit_custom_metadata;

-- Remove column
ALTER TABLE record_audit
DROP COLUMN IF EXISTS custom_metadata;

-- Remove version entry
DELETE FROM schema_metadata WHERE version = '1.2.0';

COMMIT;
```

---

## Database Schema Composition

### Core Schema (from packages/database/)

**Tables**:
- `record_audit` - Immutable event log
- `record_state` - Current state (auto-updated by triggers)
- `sites` - Clinical trial sites
- `user_profiles` - User metadata
- `investigator_site_assignments` - Site access control
- `sync_conflicts` - Offline sync conflict tracking

**See**: prd-database.md for complete schema documentation

### Sponsor Extensions

**Common Extension Patterns**:

1. **Custom Patient Fields**:
```sql
CREATE TABLE custom_patient_fields (
  patient_id TEXT PRIMARY KEY,
  sponsor_custom_id TEXT UNIQUE,
  cohort TEXT,
  custom_data JSONB
);

-- RLS using session variables
ALTER TABLE custom_patient_fields ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_access ON custom_patient_fields
  FOR ALL
  USING (patient_id = current_setting('app.user_id', true));
```

2. **EDC Sync Tracking**:

> **CRITICAL**: Events MUST sync in strict sequential order. If event N fails, all subsequent events are blocked until event N succeeds. The `audit_id` establishes this immutable sequence.

```sql
CREATE TABLE edc_sync_log (
  sync_id BIGSERIAL PRIMARY KEY,
  audit_id BIGINT NOT NULL REFERENCES record_audit(audit_id),
  event_uuid UUID NOT NULL,
  sync_status TEXT CHECK (sync_status IN ('SUCCESS', 'FAILED')),
  attempt_count INTEGER DEFAULT 1,
  last_error TEXT,
  edc_response JSONB,
  synced_at TIMESTAMPTZ DEFAULT now()
);

-- Find highest successfully synced event (sync position)
CREATE INDEX idx_edc_last_success ON edc_sync_log(audit_id DESC)
  WHERE sync_status = 'SUCCESS';

-- Ensure one sync record per audit event
CREATE UNIQUE INDEX idx_edc_sync_audit_unique ON edc_sync_log(audit_id);
```

3. **Custom Validations**:
```sql
CREATE OR REPLACE FUNCTION validate_sponsor_data(data JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Sponsor-specific validation logic
  IF data->>'required_field' IS NULL THEN
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END;
$$;
```

---

## Identity Platform Integration

### Token Verification in Dart

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

class FirebaseAuthVerifier {
  final String projectId;
  JsonWebKeyStore? _keyStore;

  FirebaseAuthVerifier({required this.projectId});

  /// Verify Firebase ID token and extract claims
  Future<Map<String, dynamic>> verifyToken(String idToken) async {
    // Fetch Google public keys (cached)
    _keyStore ??= await _fetchPublicKeys();

    final jwt = JsonWebToken.unverified(idToken);

    // Verify signature
    final keyStore = JsonWebKeyStore()..addKeyStore(_keyStore!);
    final verified = await jwt.verify(keyStore);

    if (!verified) {
      throw Exception('Invalid token signature');
    }

    final claims = jwt.claims;

    // Verify claims
    if (claims.audience?.contains(projectId) != true) {
      throw Exception('Invalid audience');
    }

    if (claims.issuer != 'https://securetoken.google.com/$projectId') {
      throw Exception('Invalid issuer');
    }

    if (claims.expiry?.isBefore(DateTime.now()) == true) {
      throw Exception('Token expired');
    }

    return claims.toJson();
  }

  Future<JsonWebKeyStore> _fetchPublicKeys() async {
    final response = await http.get(Uri.parse(
      'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com'
    ));

    final keys = jsonDecode(response.body) as Map<String, dynamic>;
    final store = JsonWebKeyStore();

    // Convert X.509 certs to JWKs
    for (final entry in keys.entries) {
      // Parse certificate and add to store
      // Implementation depends on crypto library
    }

    return store;
  }
}
```

### Auth Middleware

```dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import '../database/rls_context.dart';
import 'firebase_auth.dart';

Middleware authMiddleware(FirebaseAuthVerifier verifier) {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden('Missing or invalid authorization header');
      }

      final token = authHeader.substring(7);

      try {
        final claims = await verifier.verifyToken(token);

        // Create RLS context from claims
        final rlsContext = RlsContext.fromClaims(claims);

        // Add to request context
        final updatedRequest = request.change(
          context: {
            ...request.context,
            'claims': claims,
            'rlsContext': rlsContext,
          },
        );

        return innerHandler(updatedRequest);
      } catch (e) {
        return Response.forbidden('Invalid token: $e');
      }
    };
  };
}
```

---

## Testing

### Unit Testing SQL Functions

```sql
-- Test helper function
DO $$
DECLARE
  result JSONB;
BEGIN
  -- Test validate_sponsor_data function
  result := validate_sponsor_data('{"required_field": "value"}'::JSONB);

  IF result != TRUE THEN
    RAISE EXCEPTION 'Validation test failed';
  END IF;

  RAISE NOTICE 'Test passed: validate_sponsor_data';
END $$;
```

### Integration Testing with Cloud SQL

```dart
// test/integration/database_integration_test.dart
import 'package:test/test.dart';
import 'package:server/database/pool.dart';
import 'package:server/database/rls_context.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() async {
    await DatabasePool.initialize();
  });

  tearDownAll(() async {
    await DatabasePool.close();
  });

  group('Event Sourcing', () {
    test('Insert audit creates state', () async {
      final eventUuid = Uuid().v4();
      final connection = await DatabasePool.getConnection();

      // Set RLS context
      final context = RlsContext(
        userId: 'test_patient',
        role: 'USER',
        siteId: 'test_site',
        sponsorId: 'test_sponsor',
      );
      await context.apply(connection);

      // Insert into audit
      await connection.execute(Sql.named('''
        INSERT INTO record_audit (
          event_uuid, patient_id, site_id, operation, data,
          created_by, role, client_timestamp, change_reason
        ) VALUES (
          @eventUuid, 'test_patient', 'test_site', 'USER_CREATE',
          '{"test": "data"}'::jsonb, 'test_patient', 'USER',
          now(), 'Test'
        )
      '''), parameters: {'eventUuid': eventUuid});

      // Verify state was created by trigger
      final state = await connection.execute(Sql.named('''
        SELECT * FROM record_state WHERE event_uuid = @eventUuid
      '''), parameters: {'eventUuid': eventUuid});

      expect(state.length, equals(1));
      expect(state.first.toColumnMap()['current_data'], containsPair('test', 'data'));
    });
  });

  group('RLS Policies', () {
    test('User can only access own data', () async {
      final connection = await DatabasePool.getConnection();

      // Set context as user1
      await RlsContext(
        userId: 'user1',
        role: 'USER',
        sponsorId: 'sponsor1',
      ).apply(connection);

      // Query should only return user1's data
      final result = await connection.execute(
        'SELECT * FROM record_state'
      );

      for (final row in result) {
        expect(row.toColumnMap()['patient_id'], equals('user1'));
      }
    });
  });
}
```

---

## Performance Optimization

### Analyzing Query Performance

```sql
-- Enable query timing
\timing on

-- Analyze query plan
EXPLAIN ANALYZE
SELECT * FROM record_state
WHERE patient_id = 'patient_001'
  AND is_deleted = false
ORDER BY updated_at DESC
LIMIT 20;

-- Check slow queries (Cloud SQL)
SELECT
  query,
  calls,
  mean_exec_time,
  total_exec_time
FROM pg_stat_statements
WHERE mean_exec_time > 1000
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Index Optimization

```sql
-- Check index usage
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;

-- Find missing indexes
SELECT
  schemaname,
  tablename,
  attname,
  n_distinct,
  correlation
FROM pg_stats
WHERE schemaname = 'public'
  AND n_distinct > 100
  AND correlation < 0.1;
```

### Connection Pooling

Cloud Run manages connections automatically. For high concurrency:

```dart
// Configure pool settings based on Cloud Run instance
final poolSettings = PoolSettings(
  maxConnectionCount: int.parse(
    Platform.environment['MAX_DB_CONNECTIONS'] ?? '10'
  ),
  maxConnectionAge: Duration(minutes: 30),
);
```

---

## Monitoring & Debugging

### Cloud SQL Logs

```bash
# View database logs
gcloud sql instances list
gcloud logging read "resource.type=cloudsql_database" --limit=50

# View slow queries
gcloud logging read \
  'resource.type="cloudsql_database" AND textPayload:"duration:"' \
  --limit=20
```

### Query Statistics

```sql
-- Top tables by size
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
  pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY size_bytes DESC
LIMIT 10;

-- Table bloat check
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS size,
  n_live_tup,
  n_dead_tup,
  ROUND(100 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_ratio
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC;
```

---

## Common Development Tasks

### Reset Development Database

```bash
# Drop and recreate database
psql -h 127.0.0.1 -U postgres -c "DROP DATABASE IF EXISTS clinical_diary;"
psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE clinical_diary;"

# Reapply schema
for file in packages/database/*.sql; do
  psql $DATABASE_URL -f "$file"
done
```

### Export Schema (for debugging)

```bash
# Dump schema only
pg_dump $DATABASE_URL --schema-only > schema_export.sql

# Dump specific table data (BE CAREFUL - may contain PHI)
pg_dump $DATABASE_URL --table=record_audit --data-only > audit_data.sql
```

### Generate Dart Types

Use build_runner with json_serializable for type-safe database models:

```dart
// lib/models/record_state.dart
import 'package:json_annotation/json_annotation.dart';

part 'record_state.g.dart';

@JsonSerializable()
class RecordState {
  final String eventUuid;
  final String patientId;
  final String siteId;
  final Map<String, dynamic> currentData;
  final int version;
  final int lastAuditId;
  final DateTime updatedAt;
  final bool isDeleted;

  RecordState({
    required this.eventUuid,
    required this.patientId,
    required this.siteId,
    required this.currentData,
    required this.version,
    required this.lastAuditId,
    required this.updatedAt,
    required this.isDeleted,
  });

  factory RecordState.fromJson(Map<String, dynamic> json) =>
      _$RecordStateFromJson(json);

  Map<String, dynamic> toJson() => _$RecordStateToJson(this);
}
```

---

## Troubleshooting

### Issue: Cloud SQL Proxy Connection Refused

**Symptoms**: `connection refused` when connecting via proxy

**Solutions**:
```bash
# Check proxy is running
ps aux | grep cloud-sql-proxy

# Restart proxy with verbose output
cloud-sql-proxy your-project:us-central1:instance \
  --port=5432 \
  --debug-logs

# Check IAM permissions
gcloud projects get-iam-policy your-project \
  --filter="bindings.members:serviceAccount:*"
```

### Issue: RLS Blocking Legitimate Access

**Debug**:
```sql
-- Check current session settings
SELECT
  current_setting('app.user_id', true) as user_id,
  current_setting('app.role', true) as role,
  current_setting('app.site_id', true) as site_id;

-- Test with specific context
SET app.user_id = 'user_123';
SET app.role = 'INVESTIGATOR';
SET app.site_id = 'site_001';

-- Try query
SELECT * FROM record_state WHERE site_id = 'site_001';

-- Check policy (as superuser)
SET row_security = off;
SELECT * FROM record_state WHERE site_id = 'site_001';
```

### Issue: Migration Fails

**Solutions**:
```bash
# Check current schema version
psql $DATABASE_URL -c "SELECT * FROM schema_metadata ORDER BY applied_at DESC LIMIT 5;"

# Check for locks
psql $DATABASE_URL -c "SELECT * FROM pg_locks WHERE NOT granted;"

# Check for pending transactions
psql $DATABASE_URL -c "SELECT * FROM pg_stat_activity WHERE state = 'idle in transaction';"
```

---

## Security Best Practices

### Never Commit Secrets

```bash
# Add to .gitignore
echo ".env.local" >> .gitignore
echo "*.key" >> .gitignore

# Use Doppler or Secret Manager
doppler run -- dart run bin/server.dart
```

### Service Account Usage

**ONLY use service accounts with minimal permissions**:
- Cloud Run service account: `roles/cloudsql.client`
- CI/CD service account: `roles/cloudsql.admin` (for migrations only)

**NEVER**:
- Store service account keys in git
- Use admin credentials in application code
- Share credentials between environments

### RLS Testing

Always test RLS policies thoroughly:
```sql
-- Test as different roles
SET app.user_id = 'test_user';
SET app.role = 'USER';
-- Verify user can only see own data

SET app.user_id = 'test_inv';
SET app.role = 'INVESTIGATOR';
SET app.site_id = 'site_001';
-- Verify investigator limited to assigned site
```

---

## References

- **Schema Architecture**: prd-database.md
- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Production Setup**: ops-database-setup.md
- **Migration Strategy**: ops-database-migration.md
- **Cloud SQL Documentation**: https://cloud.google.com/sql/docs/postgres
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-01-24 | Initial developer database guide | Development Team |
| 2.0 | 2025-11-24 | Migration to Cloud SQL and GCP | Development Team |

---

**Document Classification**: Internal Use - Developer Guide
**Review Frequency**: When database architecture changes
**Owner**: Database Team / Technical Lead

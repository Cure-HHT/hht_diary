# Portal Functions

Dart library containing business logic for the Clinical Trial Sponsor Portal.

## Purpose

This library provides the handler implementations for the portal server API. It contains:
- **Authentication**: Google Identity Platform token verification
- **User Management**: Portal user CRUD operations
- **Site Management**: Clinical trial site queries
- **Database Access**: PostgreSQL connection management

## Requirements Implemented

- REQ-p00024: Portal User Roles and Permissions
- REQ-d00031: Identity Platform Integration
- REQ-d00032: Role-Based Access Control Implementation
- REQ-d00035: Admin Dashboard Implementation
- REQ-d00039: Portal User Database Schema

## Architecture

### Package Structure

```
portal_functions/
├── lib/
│   ├── portal_functions.dart     # Library exports
│   └── src/
│       ├── database.dart         # Database connection management
│       ├── database_config.dart  # Database configuration
│       ├── handlers.dart         # Legacy handlers (deprecated)
│       ├── health_handler.dart   # Health check endpoint
│       ├── identity_platform.dart # Firebase Auth token verification
│       ├── portal_auth.dart      # Portal login handler (/me)
│       ├── portal_user.dart      # User CRUD handlers
│       └── sponsor_config.dart   # Sponsor configuration handler
├── test/                         # Unit tests
└── integration_test/             # Integration tests
```

### Handler Overview

| Handler                  | Endpoint                       | Description                    |
|--------------------------|--------------------------------|--------------------------------|
| `healthHandler`          | GET /health                    | Cloud Run health check         |
| `sponsorConfigHandler`   | GET /api/v1/sponsor/config     | Sponsor feature flags          |
| `portalMeHandler`        | GET /api/v1/portal/me          | Get current user info          |
| `getPortalUsersHandler`  | GET /api/v1/portal/users       | List all portal users (Admin)  |
| `createPortalUserHandler`| POST /api/v1/portal/users      | Create new user (Admin)        |
| `updatePortalUserHandler`| PATCH /api/v1/portal/users/:id | Update user status (Admin)     |
| `getPortalSitesHandler`  | GET /api/v1/portal/sites       | List clinical sites            |

## Authentication Flow

### First Admin Login

1. Admin opens portal and enters email/password
2. Firebase Auth validates credentials, returns ID token
3. Portal UI sends ID token to `GET /api/v1/portal/me`
4. Server verifies token with Google's public keys
5. Server looks up email in `portal_users` table:
   - If found: Links `firebase_uid` to user record, returns user info
   - If not found: Returns 403 Forbidden
6. Portal UI routes to appropriate dashboard based on role

### Token Verification

```dart
// identity_platform.dart
final result = await verifyIdToken(idToken);
if (result.isValid) {
  final uid = result.uid;    // Firebase UID
  final email = result.email; // User email
}
```

For local development, set `FIREBASE_AUTH_EMULATOR_HOST` to bypass signature verification.

## User Roles

The portal supports six user roles defined in `portal_user_role` enum:

| Role            | Description                              | Site Access    |
|-----------------|------------------------------------------|----------------|
| Investigator    | Clinical site staff                      | Assigned sites |
| Sponsor         | Pharmaceutical company staff             | All sites      |
| Auditor         | Compliance/audit personnel               | All sites      |
| Analyst         | Data analysis personnel                  | All sites      |
| Administrator   | Portal admin (user management)           | All sites      |
| Developer Admin | Development team (full access)           | All sites      |

## Database Schema

### Portal Tables

```sql
-- Portal staff users
CREATE TABLE portal_users (
    id UUID PRIMARY KEY,
    firebase_uid TEXT UNIQUE,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role portal_user_role NOT NULL,
    linking_code TEXT UNIQUE,
    status TEXT CHECK (status IN ('active', 'revoked')),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

-- Site assignments for Investigators
CREATE TABLE portal_user_site_access (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES portal_users(id),
    site_id TEXT REFERENCES sites(site_id),
    assigned_at TIMESTAMPTZ
);

-- Sponsor-specific role mapping
CREATE TABLE sponsor_role_mapping (
    sponsor_id TEXT,
    sponsor_role_name TEXT,
    mapped_role portal_user_role
);
```

## Security

### SQL Injection Protection

All database queries use parameterized queries:

```dart
await db.execute(
  Sql.named('SELECT * FROM portal_users WHERE email = @email'),
  parameters: {'email': email},
);
```

### Token Verification

- Production: Verifies JWT signature against Google's JWKS endpoint
- Development: Trusts emulator tokens (simpler verification)

### Role-Based Access Control

Handler-level authorization checks:

```dart
// Require admin role
if (!currentUser.role.isAdmin) {
  return Response.forbidden('Admin access required');
}
```

## Environment Variables

| Variable                      | Description                        | Default                 |
|-------------------------------|------------------------------------|-------------------------|
| `DB_HOST`                     | PostgreSQL host                    | `localhost`             |
| `DB_PORT`                     | PostgreSQL port                    | `5432`                  |
| `DB_NAME`                     | Database name                      | `sponsor_portal`        |
| `DB_USER`                     | Database user                      | `postgres`              |
| `DB_PASSWORD`                 | Database password                  | (required)              |
| `DB_SSL`                      | Enable SSL                         | `true`                  |
| `GCP_PROJECT_ID`              | GCP project ID                     | `demo-sponsor-portal`   |
| `PORTAL_IDENTITY_API_KEY`     | Identity Platform Web API Key      | (required)              |
| `PORTAL_IDENTITY_APP_ID`      | Identity Platform App ID           | (required)              |
| `PORTAL_IDENTITY_AUTH_DOMAIN` | Identity Platform Auth Domain      | (required)              |
| `PORTAL_IDENTITY_PROJECT_ID`  | Identity Platform Project ID       | (required)              |
| `PORTAL_BASE_URL`             | Portal base URL                    | `http://localhost:8080` |
| `EMAIL_SVC_ACCT`              | Gmail service account email        | (required for emails)   |
| `EMAIL_SENDER`                | From address for emails            | `support@anspar.org`    |
| `EMAIL_ENABLED`               | Enable email sending               | `true`                  |
| `FIREBASE_AUTH_EMULATOR_HOST` | Identity Platform emulator host    | (unset = production)    |

## Testing

### Running Tests

```bash
cd apps/sponsor-portal/portal_functions

# Run unit tests only (default)
doppler run -- ./tool/test.sh

# Run integration tests (requires database)
doppler run -- ./tool/test.sh -i

# Run all tests with coverage
doppler run -- ./tool/test.sh --coverage

# Run unit tests with coverage
doppler run -- ./tool/test.sh -u --coverage

# Run integration tests with coverage (requires database)
doppler run -- ./tool/test.sh -i --coverage
```

### Coverage Threshold

The project requires **85% code coverage**.

### Test Structure

| Directory           | Description                             | Database Required |
|---------------------|-----------------------------------------|-------------------|
| `test/`             | Unit tests (token verification, etc.)   | No                |
| `integration_test/` | Integration tests (database handlers)   | Yes               |

### Integration Test Setup

```bash
# Start database
cd tools/dev-env
docker-compose up -d postgres

# Apply schema
doppler run -- psql -f ../../database/init.sql

# Apply seed data
doppler run -- psql -f /path/to/hht_diary_curehht/database/seed_data.sql

# Run tests
cd ../../apps/sponsor-portal/portal_functions
doppler run -- dart test integration_test/
```

## Usage

### Import Library

```dart
import 'package:portal_functions/portal_functions.dart';

// Initialize database
final config = DatabaseConfig.fromEnvironment();
await Database.instance.initialize(config);

// Use handlers with shelf router
final router = Router();
router.get('/api/v1/portal/me', portalMeHandler);
router.get('/api/v1/portal/users', getPortalUsersHandler);
router.post('/api/v1/portal/users', createPortalUserHandler);
```

### Token Verification

```dart
import 'package:portal_functions/portal_functions.dart';

final authHeader = request.headers['authorization'];
final token = extractBearerToken(authHeader);

if (token == null) {
  return Response.unauthorized('Missing token');
}

final result = await verifyIdToken(token);
if (!result.isValid) {
  return Response.forbidden(result.error);
}

// Use result.uid and result.email
```

## Dependencies

- `shelf`: HTTP request/response handling
- `postgres`: PostgreSQL database driver
- `http`: HTTP client for JWKS fetching
- `jose`: JWT parsing and verification

## Related Documentation

- [Portal Server README](../portal_server/README.md) - HTTP server setup
- [Portal UI README](../portal-ui/README.md) - Frontend application
- [Database README](../../../database/README.md) - Schema details

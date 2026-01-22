# Sponsor Portal

Clinical Trial Sponsor Web Portal for managing users, sites, and trial data access.

## Components

| Directory           | Description                            | Coverage |
|---------------------|----------------------------------------|----------|
| `portal-ui/`        | Flutter web frontend                   | 75%+     |
| `portal_server/`    | Shelf HTTP server                      | 95%+     |
| `portal_functions/` | Business logic library                 | 85%+     |
| `portal-container/` | Combined container (nginx + Dart + UI) | -        |

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Dart SDK 3.5+
- Flutter SDK 3.5+
- Doppler CLI (for secrets management)
- Access to sponsor-specific seed data repo (e.g., `hht_diary_curehht`)

### Unified Local Runner (Recommended)

The easiest way to start local development:

```bash
cd apps/sponsor-portal

# Start everything (DB, emulator, server, UI)
./tool/run_local.sh

# Reset database and start fresh
./tool/run_local.sh --reset

# Use GCP Identity Platform instead of Firebase emulator
./tool/run_local.sh --dev

# Start without UI (backend only)
./tool/run_local.sh --no-ui

# Show all options
./tool/run_local.sh --help
```

**Options:**

| Flag | Description |
| ---- | ----------- |
| `--reset` | Reset database (drop tables, reapply schema + seed data) |
| `--dev` | Use GCP Identity Platform instead of Firebase emulator |
| `--no-ui` | Don't start Flutter web client |
| `--offline` | Run without Doppler (uses local fallback passwords) |

**GCP Identity Platform Mode (`--dev`):**

Uses real GCP Identity Platform for authentication instead of Firebase emulator.
This is GDPR/FDA compliant and recommended for testing real auth flows.

Required Doppler secrets:

- `PORTAL_IDENTITY_API_KEY` - GCP Identity Platform API key
- `PORTAL_IDENTITY_APP_ID` - Identity Platform web app ID
- `PORTAL_IDENTITY_PROJECT_ID` - GCP project ID
- `PORTAL_IDENTITY_AUTH_DOMAIN` - Auth domain (project.firebaseapp.com)

### Manual Setup (Alternative)

If you prefer manual control over each service:

### 1. Start Database and Firebase Emulator

```bash
# From repository root
cd tools/dev-env

# Create the network first (if it doesn't exist)
docker network create clinical-diary-net 2>/dev/null || true

# Start PostgreSQL
doppler run -- docker compose -f docker-compose.db.yml up -d

# Start Firebase Auth emulator (separate terminal or background)
docker compose -f docker-compose.firebase.yml up -d
```

Verify services are running:
```bash
# PostgreSQL health check
docker exec sponsor-portal-postgres pg_isready -U postgres

# Firebase emulator UI
open http://localhost:4000
```

### 2. Initialize Database

```bash
cd tools/dev-env

# Apply main schema
doppler run -- psql -h localhost -U postgres -d sponsor_portal -f ../../database/schema.sql

# Apply sponsor-specific seed data (example: curehht)
doppler run -- psql -h localhost -U postgres -d sponsor_portal -f /path/to/hht_diary_curehht/database/seed_data.sql
```

### 3. Create Test User in Firebase Emulator (Local Dev Only)

> **Note**: This step is for local development only. In UAT and production,
> users authenticate against the real Google Identity Platform - no emulator
> setup required. Users must be pre-provisioned in the `portal_users` table,
> then they sign in with their Identity Platform credentials.

1. Open http://localhost:4000 (Firebase Emulator UI)
2. Go to Authentication tab
3. Click "Add user"
4. Enter email that matches your seed_data.sql (e.g., `mike.bushe@anspar.org`)
5. Set any password (emulator only - not used in real environments)

### 4. Start the Server

```bash
cd apps/sponsor-portal/portal_server

# Install dependencies
dart pub get

# Run server
doppler run -- dart run bin/server.dart
```

Verify the server is running:
```bash
curl http://localhost:8080/health
# Expected: {"status":"ok"}
```

> **Note**: The server only exposes API endpoints (see [API Endpoints](#api-endpoints)).
> There is no `/` route - use `/health` to verify the server is up.

### 5. Start the UI

```bash
cd apps/sponsor-portal/portal-ui

# Install dependencies
flutter pub get

# Run in Chrome
flutter run -d chrome
```

Or with custom API URL:
```bash
flutter run -d chrome --dart-define=PORTAL_API_URL=http://localhost:8080
```

## Running Tests

### All Components

```bash
# Server tests (unit + integration)
cd apps/sponsor-portal/portal_server
doppler run -- ./tool/coverage.sh

# Functions tests (unit + integration with coverage)
cd apps/sponsor-portal/portal_functions
doppler run -- ./tool/test.sh --coverage

# UI tests (unit only, no database needed)
cd apps/sponsor-portal/portal-ui
./tool/coverage.sh
```

### Quick Test (Unit Only)

```bash
# Server - unit tests only
cd apps/sponsor-portal/portal_server
doppler run -- ./tool/coverage.sh -u

# Functions - unit tests only
cd apps/sponsor-portal/portal_functions
doppler run -- ./tool/test.sh

# UI
cd apps/sponsor-portal/portal-ui
flutter test
```

### Integration Tests (Require Database)

```bash
# Ensure database is running with seed data applied

# Server integration tests
cd apps/sponsor-portal/portal_server
doppler run -- dart test integration_test/

# Functions integration tests
cd apps/sponsor-portal/portal_functions
doppler run -- dart test integration_test/
```

## Environment Variables

### Server & Functions

| Variable                      | Description                        | Default                      |
|-------------------------------|------------------------------------|------------------------------|
| `PORT`                        | HTTP server port                   | `8080`                       |
| `DB_HOST`                     | PostgreSQL host                    | `localhost`                  |
| `DB_PORT`                     | PostgreSQL port                    | `5432`                       |
| `DB_NAME`                     | Database name                      | `sponsor_portal`             |
| `DB_USER`                     | Database user                      | `postgres`                   |
| `DB_PASSWORD`                 | Database password                  | (required)                   |
| `DB_SSL`                      | Enable SSL                         | `true` (set `false` locally) |
| `GCP_PROJECT_ID`              | GCP project for token verification | `demo-sponsor-portal`        |
| `FIREBASE_AUTH_EMULATOR_HOST` | Firebase emulator host             | (unset = production)         |

### UI

| Variable                | Description           | Default                       |
|-------------------------|-----------------------|-------------------------------|
| `PORTAL_API_URL`        | Backend API URL       | `http://localhost:8080` (dev) |
| `USE_FIREBASE_EMULATOR` | Use Firebase emulator | `false`                       |

Set via `--dart-define`:
```bash
flutter run -d chrome \
  --dart-define=PORTAL_API_URL=http://localhost:8080 \
  --dart-define=USE_FIREBASE_EMULATOR=true
```

## API Endpoints

| Endpoint                   | Method | Auth  | Description           |
|----------------------------|--------|-------|-----------------------|
| `/health`                  | GET    | No    | Health check          |
| `/api/v1/sponsor/config`   | GET    | No    | Sponsor configuration |
| `/api/v1/portal/me`        | GET    | Yes   | Current user info     |
| `/api/v1/portal/users`     | GET    | Admin | List all users        |
| `/api/v1/portal/users`     | POST   | Admin | Create new user       |
| `/api/v1/portal/users/:id` | PATCH  | Admin | Update user           |
| `/api/v1/portal/sites`     | GET    | Yes   | List clinical sites   |

## User Roles

| Role            | Description            | Site Access         |
|-----------------|------------------------|---------------------|
| Investigator    | Clinical site staff    | Assigned sites only |
| Sponsor         | Pharmaceutical company | All sites           |
| Auditor         | Compliance personnel   | All sites           |
| Analyst         | Data analysis          | All sites           |
| Administrator   | Portal admin           | All sites           |
| Developer Admin | Development team       | All sites           |

## Architecture

### Development
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   portal-ui     │────▶│  portal_server  │────▶│   PostgreSQL    │
│  (Flutter Web)  │     │    (Shelf)      │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│  Firebase Auth  │     │portal_functions │
│    Emulator     │     │  (Business Logic) │
└─────────────────┘     └─────────────────┘
```

### Production (Cloud Run)
```
┌─────────────────────────────────────────────────────┐
│              portal-container (Cloud Run)            │
│                                                      │
│  ┌─────────────────────────────────────────────┐    │
│  │           nginx (port 8080)                  │    │
│  │                                              │    │
│  │   /           → Flutter web static files     │    │
│  │   /api/*      → Dart server (port 8081)      │    │
│  │   /health     → Dart server (port 8081)      │    │
│  └─────────────────────────────────────────────┘    │
│                       │                              │
│                       ▼                              │
│  ┌─────────────────────────────────────────────┐    │
│  │        Dart Server (portal_functions)        │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
        │                       │
        ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│Identity Platform│     │   Cloud SQL     │
│  (Firebase Auth)│     │  (PostgreSQL)   │
└─────────────────┘     └─────────────────┘
```

## Security Architecture: RLS with GCP Cloud SQL

The portal uses **Row-Level Security (RLS)** to enforce data access control at the database level.
This provides defense-in-depth security that cannot be bypassed by application bugs.

### How It Works (Cloud SQL vs Supabase)

Unlike Supabase (which includes PostgREST to automatically pass JWT claims to PostgreSQL),
**GCP Cloud SQL is just PostgreSQL** - there's no automatic JWT handling. The portal server
must explicitly set session context for every database query.

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   portal-ui     │────▶│  portal_server  │────▶│   Cloud SQL     │
│  (Flutter Web)  │     │    (Dart)       │     │  (PostgreSQL)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        │ JWT Token             │ SET LOCAL ROLE
        │                       │ SET LOCAL app.user_id
        ▼                       │ SET LOCAL app.role
┌─────────────────┐             │
│ Identity Platform│            │
│   (Firebase Auth)│            ▼
└─────────────────┘     ┌─────────────────┐
                        │   RLS Policies   │
                        │ (current_user_*) │
                        └─────────────────┘
```

### Two-Level Role System

1. **PostgreSQL Roles** (`authenticated`, `service_role`):
   - Control which RLS policies apply
   - Set via `SET LOCAL ROLE <role>`

2. **Application Roles** (`Administrator`, `Investigator`, etc.):
   - Used by RLS policy conditions
   - Set via `SET LOCAL app.role = '<role>'`

### Session Context Variables

The server sets these PostgreSQL session variables before every query:

| Variable           | Purpose                                      | Example                        |
|--------------------|----------------------------------------------|--------------------------------|
| `ROLE`             | PostgreSQL role for RLS policy selection     | `authenticated`, `service_role`|
| `app.user_id`      | User's Identity Platform UID (firebase_uid)  | `abc123xyz`                    |
| `app.role`         | Active application role                      | `Administrator`                |
| `app.allowed_roles`| All roles user can assume (comma-separated)  | `Administrator,Auditor`        |

### RLS Policy Functions

RLS policies use these helper functions (defined in `database/roles.sql`):

```sql
-- Get current user ID from session
SELECT current_user_id();  -- Reads app.user_id

-- Get current active role
SELECT current_user_role();  -- Reads app.role

-- Get all allowed roles
SELECT current_user_allowed_roles();  -- Reads app.allowed_roles
```

### Code Example

```dart
// Service context (for login/bootstrap operations)
final result = await db.executeWithContext(
  'SELECT * FROM portal_users WHERE email = @email',
  parameters: {'email': email},
  context: UserContext.service,  // Uses service_role, bypasses RLS
);

// Authenticated context (for user data operations)
final context = UserContext.authenticated(
  userId: user.firebaseUid!,
  role: user.role,
);
final result = await db.executeWithContext(
  'SELECT * FROM patients WHERE site_id = @siteId',
  parameters: {'siteId': siteId},
  context: context,  // RLS enforces site access
);
```

### Why This Design?

1. **Same behavior everywhere**: Local dev and production use identical RLS enforcement
2. **Defense in depth**: Even if application code has bugs, database prevents unauthorized access
3. **FDA compliance**: Audit trail shows exactly who accessed what data, in what role
4. **No Supabase dependency**: Works with any PostgreSQL (Cloud SQL, RDS, on-prem)

### RLS Policy Examples

From `database/rls_policies.sql`:

```sql
-- Admins can see all portal users
CREATE POLICY portal_users_admin_auditor_select ON portal_users
    FOR SELECT TO authenticated
    USING (current_user_role() IN ('Administrator', 'Auditor', 'Developer Admin'));

-- Users can see their own record
CREATE POLICY portal_users_self_select ON portal_users
    FOR SELECT TO authenticated
    USING (firebase_uid = current_user_id());

-- Service role can update (for firebase_uid linking during login)
CREATE POLICY portal_users_service_update ON portal_users
    FOR UPDATE TO service_role
    USING (true) WITH CHECK (true);
```

## Local Development Ports

| Service                | Port | URL                                     |
|------------------------|------|-----------------------------------------|
| Portal Server          | 8080 | http://localhost:8080                   |
| Portal UI              | 3000 | http://localhost:3000 (Flutter default) |
| PostgreSQL             | 5432 | localhost:5432                          |
| Firebase Auth Emulator | 9099 | localhost:9099                          |
| Firebase Emulator UI   | 4000 | http://localhost:4000                   |
| pgAdmin (optional)     | 5050 | http://localhost:5050                   |

## Troubleshooting

### "Token verification failed"

- Ensure `FIREBASE_AUTH_EMULATOR_HOST=localhost:9099` is set
- Check user exists in Firebase Emulator UI
- Verify token hasn't expired (refresh page to get new token)

### "User not found" on login

- Check email in Firebase matches email in `portal_users` table
- Verify seed_data.sql was applied
- Email matching is case-sensitive

### Database connection errors

- Check Docker container is running: `docker ps`
- Verify Doppler secrets are set: `doppler secrets`
- Test connection: `doppler run -- psql -h localhost -U postgres -d sponsor_portal -c "SELECT 1"`

### Flutter build errors

```bash
# Clean and rebuild
cd apps/sponsor-portal/portal-ui
flutter clean
flutter pub get
flutter run -d chrome
```

### Firebase Emulator won't start

```bash
# Check if port 9099 is in use
lsof -i :9099

# Remove and restart container
docker compose -f docker-compose.firebase.yml down
docker compose -f docker-compose.firebase.yml up -d
```

### "Email already linked to another account"

This error occurs after resetting the Firebase emulator. When the emulator restarts, it creates
new UIDs for users, but PostgreSQL still has old `firebase_uid` values in the `portal_users` table.

**Solution 1: Clear Firebase UIDs (preserves data)**

```bash
cd tools/dev-env
doppler run -- psql -h localhost -p 5432 -U postgres -d sponsor_portal -c "UPDATE portal_users SET firebase_uid = NULL;"
```

Then recreate the user in the Firebase Emulator UI and log in again. The portal will re-link
the email to the new Firebase UID.

**Solution 2: Full reset (clears all data)**

If you want a completely fresh start:

```bash
cd tools/dev-env

# Stop everything and remove volumes
doppler run -- docker compose -f docker-compose.db.yml -f docker-compose.firebase.yml down -v

# Start fresh
doppler run -- docker compose -f docker-compose.db.yml up -d
docker compose -f docker-compose.firebase.yml up -d

# Re-apply schema and seed data
doppler run -- psql -h localhost -U postgres -d sponsor_portal -f ../../database/schema.sql

# Create user in Firebase Emulator UI (http://localhost:4000)
```

### Port 8080 in use (server won't start)

```bash
# Find what's using port 8080
lsof -i :8080

# Kill the process (replace PID with actual process ID)
kill -9 <PID>

# Or use a different port
PORT=8081 doppler run -- dart run bin/server.dart
```

## Stopping Services

```bash
cd tools/dev-env

# Stop PostgreSQL
doppler run -- docker compose -f docker-compose.db.yml down

# Stop Firebase emulator
docker compose -f docker-compose.firebase.yml down

# Stop both and remove volumes (fresh start)
doppler run -- docker compose -f docker-compose.db.yml down -v
docker compose -f docker-compose.firebase.yml down
```

## Related Documentation

- [Portal Server README](portal_server/README.md) - Detailed server docs
- [Portal Functions README](portal_functions/README.md) - Handler implementations
- [Database README](../../database/README.md) - Schema and migrations
- [Dev Environment README](../../tools/dev-env/README.md) - Docker setup details

## Requirements Implemented

- REQ-p00009: Sponsor-Specific Web Portals
- REQ-p00024: Portal User Roles and Permissions
- REQ-d00028: Portal Frontend Framework
- REQ-d00031: Identity Platform Integration
- REQ-d00032: Role-Based Access Control Implementation
- REQ-d00035: Admin Dashboard Implementation
- REQ-o00056: Container infrastructure for Cloud Run

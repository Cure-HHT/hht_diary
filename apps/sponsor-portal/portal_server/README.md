# Portal Server

HTTP server for the Clinical Trial Sponsor Portal API, built on shelf/shelf_router.

## Purpose

The portal server provides the backend API for the sponsor portal web application. It handles:
- **Authentication**: Google Identity Platform (Firebase Auth) token verification
- **User Management**: Portal user CRUD operations for administrators
- **Site Management**: Clinical trial site data access

## Requirements Implemented

- REQ-o00056: Container infrastructure for Cloud Run
- REQ-d00005: Sponsor Configuration Detection Implementation
- REQ-d00031: Identity Platform Integration
- REQ-d00035: Admin Dashboard Implementation
- REQ-p00024: Portal User Roles and Permissions

## Architecture

### Package Structure

```
portal_server/
├── bin/
│   └── server.dart           # Entry point
├── lib/
│   ├── portal_server.dart    # Library exports
│   └── src/
│       ├── server.dart       # HTTP server setup, CORS middleware
│       └── routes.dart       # Router configuration (API v1)
├── test/                     # Unit tests
├── integration_test/         # Integration tests (requires database)
└── tool/
    └── coverage.sh           # Coverage script
```

### Server Setup

The server uses `shelf` for HTTP handling with:
- Request logging via `logRequests()` middleware
- CORS middleware for browser requests
- Router from `shelf_router` for endpoint mapping

## API Routes

All portal routes use the `/api/v1/portal` prefix for versioning.

| Endpoint                              | Method | Auth Required | Description                |
|---------------------------------------|--------|---------------|----------------------------|
| `/health`                             | GET    | No            | Cloud Run health check     |
| `/api/v1/sponsor/config`              | GET    | No            | Get sponsor configuration  |
| `/api/v1/portal/me`                   | GET    | Yes           | Get current user info      |
| `/api/v1/portal/users`                | GET    | Yes (Admin)   | List all portal users      |
| `/api/v1/portal/users`                | POST   | Yes (Admin)   | Create new portal user     |
| `/api/v1/portal/users/<userId>`       | PATCH  | Yes (Admin)   | Update portal user         |
| `/api/v1/portal/sites`                | GET    | Yes           | List clinical sites        |

### Authentication

Portal routes require a valid Firebase Auth ID token in the `Authorization` header:
```
Authorization: Bearer <firebase-id-token>
```

The server verifies tokens using Google's public keys (JWKS).

## Running Locally

### Prerequisites

- Docker and Docker Compose
- Doppler CLI (for secrets management)
- Dart SDK 3.5+

### Option 1: Local Development with Containers

Start all services (database, Firebase emulator, server):

```bash
# From repository root
cd tools/dev-env

# Start PostgreSQL and Firebase emulator
docker-compose -f docker-compose.yml -f docker-compose.firebase.yml up -d

# Apply database schema
doppler run -- psql -f ../../database/init.sql

# Apply sponsor seed data (curehht example)
doppler run -- psql -f /path/to/hht_diary_curehht/database/seed_data.sql

# Run the server
cd ../../apps/sponsor-portal/portal_server
doppler run -- dart run bin/server.dart
```

The server will be available at `http://localhost:8080`.

### Option 2: Direct Dart Execution

For quick development without full container stack:

```bash
cd apps/sponsor-portal/portal_server

# With Doppler for database credentials
doppler run -- dart run bin/server.dart

# Or set environment variables manually
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=sponsor_portal
export DB_USER=postgres
export DB_PASSWORD=your-password
export DB_SSL=false
export FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
dart run bin/server.dart
```

### Environment Variables

| Variable                      | Description                  | Default                |
|-------------------------------|------------------------------|------------------------|
| `PORT`                        | HTTP server port             | `8080`                 |
| `DB_HOST`                     | PostgreSQL host              | `localhost`            |
| `DB_PORT`                     | PostgreSQL port              | `5432`                 |
| `DB_NAME`                     | Database name                | `sponsor_portal`       |
| `DB_USER`                     | Database user                | `postgres`             |
| `DB_PASSWORD`                 | Database password            | (required)             |
| `DB_SSL`                      | Enable SSL                   | `true`                 |
| `GCP_PROJECT_ID`              | GCP project for token verify | `demo-sponsor-portal`  |
| `FIREBASE_AUTH_EMULATOR_HOST` | Firebase emulator (dev only) | (unset = production)   |

### Firebase Emulator

For local development, use the Firebase Auth emulator:

```bash
# Start emulator
cd tools/dev-env
docker-compose -f docker-compose.firebase.yml up -d

# Access emulator UI
open http://localhost:4000

# Create test users in emulator UI
# Email: mike.bushe@anspar.org (must match seed_data.sql)
```

## Testing

### Running Tests Locally

```bash
cd apps/sponsor-portal/portal_server

# Run all tests with coverage
doppler run -- ./tool/coverage.sh

# Run only unit tests
doppler run -- ./tool/coverage.sh -u

# Run only integration tests (requires database)
doppler run -- ./tool/coverage.sh -i
```

### Coverage Threshold

The project requires **95% code coverage**. The coverage script will fail if coverage drops below this threshold.

### Test Structure

| Directory           | Description                             | Database Required |
|---------------------|-----------------------------------------|-------------------|
| `test/`             | Unit tests (routes, server, CORS)       | No                |
| `integration_test/` | Integration tests (API handlers)        | Yes               |

### Integration Test Setup

Integration tests require:
1. Running PostgreSQL with schema applied
2. Seed data loaded (from sponsor repo)
3. Firebase emulator running (or mock tokens)

```bash
# Full integration test setup
cd tools/dev-env
docker-compose up -d postgres
doppler run -- psql -f ../../database/init.sql

cd ../../apps/sponsor-portal/portal_server
doppler run -- dart test integration_test/
```

## GCP Cloud Run Deployment

### Build Container

```bash
cd apps/sponsor-portal/portal_server

# Build Docker image
docker build -t gcr.io/PROJECT_ID/portal-server:latest .

# Push to Container Registry
docker push gcr.io/PROJECT_ID/portal-server:latest
```

### Deploy to Cloud Run

```bash
gcloud run deploy portal-server \
  --image gcr.io/PROJECT_ID/portal-server:latest \
  --platform managed \
  --region europe-west1 \
  --set-env-vars "DB_HOST=/cloudsql/PROJECT:REGION:INSTANCE" \
  --set-secrets "DB_PASSWORD=db-password:latest" \
  --add-cloudsql-instances PROJECT:REGION:INSTANCE \
  --allow-unauthenticated
```

### Terraform Deployment

The recommended approach is using Terraform (see `infrastructure/terraform/sponsor-portal/`):

```bash
cd infrastructure/terraform/sponsor-portal

# Initialize
terraform init

# Plan changes
terraform plan -var-file="environments/dev.tfvars"

# Apply
terraform apply -var-file="environments/dev.tfvars"
```

### Health Checks

Cloud Run uses the `/health` endpoint for:
- **Startup probe**: Verify container started successfully
- **Liveness probe**: Detect hung processes
- **Readiness probe**: Control traffic routing

## Password Management

Portal users authenticate via Google Identity Platform (Firebase Auth). Password management is handled by Firebase:

### Password Change

Users can change their password via:
1. **Firebase Console**: Admin can reset passwords manually
2. **Client-side SDK**: `firebase.auth().currentUser.updatePassword(newPassword)`
3. **Password Reset Email**: Triggered via `firebase.auth().sendPasswordResetEmail(email)`

The portal server does NOT handle password changes directly - this is delegated to Firebase Auth.

### Email Verification

Email verification requires Firebase's email service:

1. **Enable Email Verification** in Firebase Console > Authentication > Templates
2. **Trigger verification** via client SDK: `firebase.auth().currentUser.sendEmailVerification()`
3. **Check status** via ID token claim: `email_verified: true/false`

For production, configure a custom SMTP server or use Firebase's default email service.

## CORS Configuration

The server includes CORS middleware that:
- Handles OPTIONS preflight requests
- Adds `Access-Control-Allow-Origin: *` to all responses (configure for production)
- Allows GET, POST, PUT, DELETE, PATCH, OPTIONS methods
- Allows Origin, Content-Type, Authorization headers

## Troubleshooting

### "Token verification failed"
- Check `GCP_PROJECT_ID` matches your Firebase project
- For local dev, ensure `FIREBASE_AUTH_EMULATOR_HOST` is set
- Verify token hasn't expired

### "User not found" on login
- Ensure email exists in `portal_users` table
- Check seed_data.sql was applied to database
- Verify email matches exactly (case-sensitive)

### Database connection errors
- Verify `DB_*` environment variables are set
- For Cloud SQL, check IAM permissions and VPC connector
- Test connection: `doppler run -- psql -c "SELECT 1"`

### CORS errors in browser
- Check browser console for specific CORS error
- Verify server is running and accessible
- For production, configure specific allowed origins

## Dependencies

- `shelf` / `shelf_router`: HTTP server framework
- `portal_functions`: Business logic and handlers

## Related Documentation

- [Portal Functions README](../portal_functions/README.md) - Handler implementations
- [Portal UI README](../portal-ui/README.md) - Frontend application
- [Database README](../../../database/README.md) - Schema and setup
- [Terraform README](../../../infrastructure/terraform/sponsor-portal/README.md) - Infrastructure

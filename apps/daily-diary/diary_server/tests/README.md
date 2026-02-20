# HHT Diary Server API Tests

This directory contains HTTP-based tests for the diary-server API.

## Files

- `openapi.yaml` - OpenAPI 3.0 specification (in parent directory)
- `api.http` - HTTP test suite for VS Code REST Client / IntelliJ HTTP Client
- `curl-tests.sh` - Shell script with curl commands for CLI testing

## Prerequisites

1. Start the diary server locally:
   ```bash
   cd /Users/citrusoft/anspar/git/hht_diary/apps/daily-diary/diary_server
   doppler run -- dart run bin/server.dart
   ```

2. Ensure the database is running and configured (via Doppler environment)

## Using api.http (Recommended)

### VS Code REST Client Extension

1. Install the "REST Client" extension by Huachao Mao
2. Open `api.http` in VS Code
3. Click "Send Request" above any request block
4. Variables like `{{authToken}}` are automatically populated from previous responses

### IntelliJ HTTP Client

1. Open `api.http` in IntelliJ IDEA or WebStorm
2. Click the green play button next to each request
3. Environment variables and response handlers work automatically

## Using curl-tests.sh

Run individual test groups or the full suite:

```bash
# Make executable
chmod +x tests/curl-tests.sh

# Run all tests
./tests/curl-tests.sh

# Run with custom base URL
BASE_URL=https://diary-server-abc123-ew.a.run.app ./tests/curl-tests.sh
```

## Test Coverage

### Health Check
- `GET /health` - Service status

### Authentication
- `POST /api/v1/auth/register` - User registration
  - Valid registration
  - Username too short
  - Invalid username characters
  - Username contains @
  - Invalid password hash format
  - Missing appUuid
  - Duplicate username

- `POST /api/v1/auth/login` - User login
  - Valid login
  - Missing fields
  - Invalid credentials

- `POST /api/v1/auth/change-password` - Password change
  - Valid change
  - Missing authorization
  - Invalid current password

### User/Patient
- `POST /api/v1/user/link` - Patient linking
  - Missing code
  - Invalid format
  - Unknown code

- `POST /api/v1/user/enroll` - Deprecated endpoint (410)

- `POST /api/v1/user/sync` - Event synchronization
  - Empty array
  - Single event
  - Multiple events
  - Duplicate handling (idempotency)
  - Missing authorization

- `POST /api/v1/user/records` - Get current state
  - Valid request
  - Missing authorization

- `POST /api/v1/user/fcm-token` - FCM registration
  - Missing token
  - Invalid platform
  - No linked patient

### Sponsor
- `GET /api/v1/sponsor/config` - Sponsor configuration
  - Known sponsors (callisto, curehht)
  - Unknown sponsor (defaults)
  - Missing sponsorId
  - Wrong HTTP method

### Security Tests
- SQL injection attempts
- XSS attempts
- Malformed JSON
- Empty body
- Large payload handling

## Viewing OpenAPI Documentation

The `openapi.yaml` file can be viewed in:

1. **Swagger Editor**: https://editor.swagger.io/ (paste content)
2. **Swagger UI**: Can be served locally
3. **VS Code**: Install "OpenAPI (Swagger) Editor" extension

## Notes

- Tests are designed to run sequentially (authentication tokens are reused)
- Some tests depend on database state (e.g., duplicate user tests)
- Patient linking tests require valid codes in the database
- FCM token tests require a linked patient

# Diary Server

HTTP server for the HHT Diary API, built on shelf/shelf_router.

## Requirements Implemented

- REQ-o00056: Container infrastructure for Cloud Run
- REQ-p00013: GDPR compliance - EU-only regions
- REQ-d00005: Sponsor Configuration Detection Implementation
- REQ-p00008: User Account Management

## Architecture

### Package Structure

```
lib/
├── diary_server.dart    # Library exports
└── src/
    ├── server.dart      # HTTP server setup, CORS middleware
    └── routes.dart      # Router configuration
```

### Server Setup

The server uses `shelf` for HTTP handling with:
- Request logging via `logRequests()` middleware
- CORS middleware for browser requests
- Router from `shelf_router` for endpoint mapping

```dart
import 'package:diary_server/diary_server.dart';

final server = await createServer(port: 8080);
print('Server running on port ${server.port}');
```

### Routes

All routes are defined in `routes.dart` and delegate to handlers from `diary_functions`:

| Endpoint                          | Method | Description                 |
|-----------------------------------|--------|-----------------------------|
| `/health`                         | GET    | Cloud Run health check      |
| `/api/v1/auth/register`           | POST   | Create new user account     |
| `/api/v1/auth/login`              | POST   | Authenticate user           |
| `/api/v1/auth/change-password`    | POST   | Update password             |
| `/api/v1/user/enroll`             | POST   | Enroll in clinical study    |
| `/api/v1/user/sync`               | POST   | Sync events to record_audit |
| `/api/v1/user/records`            | POST   | Get current record state    |
| `/api/v1/sponsor/config`          | GET    | Get sponsor feature flags   |

### CORS Configuration

The server includes CORS middleware that:
- Handles OPTIONS preflight requests
- Adds `Access-Control-Allow-Origin: *` to all responses
- Allows GET, POST, PUT, DELETE, OPTIONS methods
- Allows Origin, Content-Type, Authorization headers

## Dependencies

- `shelf` / `shelf_router`: HTTP server framework
- `diary_functions`: Business logic and handlers

## Testing

### Running Tests Locally

```bash
# Run all tests with coverage
./tool/coverage.sh

# Run only unit tests
./tool/coverage.sh -u
```

### Coverage Threshold

The project requires **95% code coverage**. The coverage script will fail if coverage drops below this threshold.

### Test Structure

| Directory | Description                       | Database Required |
|-----------|-----------------------------------|-------------------|
| `test/`   | Unit tests (routes, server, CORS) | No                |

### Test Files

| File                            | Description                                                  |
|---------------------------------|--------------------------------------------------------------|
| `test/routes_test.dart`         | Tests router configuration and endpoint routing              |
| `test/server_test.dart`         | Tests HTTP server creation, CORS headers, preflight handling |
| `test/jwt_test.dart`            | Tests JWT functions (via diary_functions)                    |
| `test/sponsor_config_test.dart` | Tests sponsor config handler (via diary_functions)           |

### CI/CD

Tests run automatically in GitHub Actions. See `.github/workflows/diary-server-ci.yml` for the full configuration.

## Usage

### Running the Server

```bash
# Development (with Doppler for secrets)
doppler run -- dart run bin/server.dart

# Production (Cloud Run)
# Server reads PORT from environment variable
```

### Environment Variables

| Variable | Description      | Default |
|----------|------------------|---------|
| `PORT`   | HTTP server port | `8080`  |

Database and JWT configuration is handled by `diary_functions`. See that package's README for database environment variables.

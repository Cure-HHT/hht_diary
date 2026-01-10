# Portal Functions

Dart library containing business logic for the HHT Sponsor Portal.

## Requirements Implemented
- REQ-p00045: Sponsor Portal Application
- REQ-p00024: Portal User Roles and Permissions
- REQ-p00030: Role-Based Visual Indicators
- REQ-p00028: Token Revocation and Access Control
- REQ-p00025: Patient Enrollment Workflow
- REQ-p00026: Patient Monitoring Dashboard
- REQ-p00027: Questionnaire Management
- REQ-p00029: Auditor Dashboard and Data Export
See spec/prd-portal.md for REQs and workflows


## Architecture

### Data Model

**portal_users** - Mobile app user accounts (any user can use the app)
- `user_id`: UUID primary key
- `username`: Optional, for registered users
- `password_hash`: SHA-256 hash of password
- `auth_code`: Random code used in JWT for user lookup
- `app_uuid`: Device/app instance identifier


### Handlers

| Endpoint                          | Handler                 | Description                 |
|-----------------------------------|-------------------------|-----------------------------|
| GET /health                       | `healthHandler`         | Cloud Run health check      |
| POST /api/v1/auth/register        | `registerHandler`       | Create new user account     |
| POST /api/v1/auth/login           | `loginHandler`          | Authenticate user           |
| POST /api/v1/auth/change-password | `changePasswordHandler` | Update password             |

## Security

### SQL Injection Protection

All database queries use **parameterized queries** via the `postgres` package's `Sql.named()` method. User input is never interpolated into SQL strings.

```dart
// Example: parameterized query (SAFE)
await db.execute(
  'SELECT user_id FROM app_users WHERE username = @username',
  parameters: {'username': normalizedUsername},
);
```

The `Sql.named()` function binds parameters at the driver level, ensuring that even malicious input like `'; DROP TABLE app_users; --` is treated as a literal string value, not executable SQL.

### Defense-in-Depth Validation

Additional input validation provides defense-in-depth:

| Input         | Validation                     | Pattern           |
|---------------|--------------------------------|-------------------|
| Username      | Alphanumeric + underscore only | `^[a-zA-Z0-9_]+$` |
| Password hash | 64-char hex string (SHA-256)   | `^[a-f0-9]{64}$`  |
| Role          | Fixed format                   | `^[a-zA-Z0-9_]+$` |

TODO - role should be fixed and an enum defined

### JWT Authentication

- HS256 signing algorithm
- Secret loaded from `JWT_SECRET` environment variable
- Tokens include expiration (`exp`) claim
- Auth code in JWT payload used for user lookup (not user ID directly)

## Dependencies

- `shelf` / `shelf_router`: HTTP server framework
- `postgres`: PostgreSQL driver (pure Dart, no native dependencies)
- `crypto`: HMAC-SHA256 for JWT signing

## Environment Variables

| Variable      | Description        | Default                       |
|---------------|--------------------|-------------------------------|
| `DB_HOST`     | PostgreSQL host    | `localhost`                   |
| `DB_PORT`     | PostgreSQL port    | `5432`                        |
| `DB_NAME`     | Database name      | `hht_portal`                  |
| `DB_USER`     | Database user      | `app_user`                    |
| `DB_PASSWORD` | Database password  | (required)                    |
| `DB_SSL`      | Enable SSL         | `true`                        |
| `JWT_SECRET`  | JWT signing secret | (dev default, change in prod) |

## Testing

### Running Tests Locally

Tests require a PostgreSQL database. Use Doppler to provide credentials:

```bash
# Run all tests (unit + integration) with coverage
doppler run -- ./tool/coverage.sh

# Run only unit tests
doppler run -- ./tool/coverage.sh -u

# Run only integration tests
doppler run -- ./tool/coverage.sh -i
```

### Coverage Threshold

The project requires **85% code coverage**. The coverage script will fail if coverage drops below this threshold.

### Test Structure

| Directory           | Description                             | Database Required |
|---------------------|-----------------------------------------|-------------------|
| `test/`             | Unit tests (HTTP validation, JWT, etc.) | No                |
| `integration_test/` | Integration tests (database operations) | Yes               |

### CI/CD

In GitHub Actions, tests run automatically with a PostgreSQL service container. Environment variables are set in the workflow:

```yaml
env:
  DB_HOST: localhost
  DB_PORT: '5432'
  DB_NAME: sponsor_portal
  DB_USER: postgres
  DB_PASSWORD: postgres
  DB_SSL: 'false'
  JWT_SECRET: test-jwt-secret-for-ci
```

See `.github/workflows/portal-server-ci.yml` for the full configuration.

### Troubleshooting

**"password authentication failed"**: Run with Doppler to get credentials:
```bash
doppler run -- ./tool/coverage.sh
```

**SSL errors**: The local Docker database doesn't support SSL. The tests default to `DB_SSL=false` when the environment variable is not set to `'true'`.

## Usage

```dart
import 'package:portal_functions/portal_functions.dart';

// Initialize database
final config = DatabaseConfig.fromEnvironment();
await Database.instance.initialize(config);

// Use handlers with shelf router
final router = Router();
router.post('/api/v1/auth/register', registerHandler);
```

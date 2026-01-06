# Diary Server Tests

## Test Structure

```
test/                      # Unit tests (no database required)
  jwt_test.dart           # JWT token generation/verification
  sponsor_config_test.dart # Sponsor configuration logic

integration_test/          # Integration tests (require PostgreSQL)
  test_server.dart        # Test server helper
  auth_test.dart          # Authentication endpoint tests
  enrollment_test.dart    # Enrollment and sync endpoint tests
```

## Running Tests Locally

### Unit Tests Only (fast, no setup required)

```bash
./tool/test.sh --unit
# or
dart test test/
```

### Integration Tests (require PostgreSQL)

```bash
# Option 1: Auto-start database container
./tool/test.sh --integration --start-db --stop-db

# Option 2: Manual database (if already running)
./tool/test.sh --integration

# Option 3: Direct dart command with env vars
DB_HOST=localhost DB_PORT=5432 DB_NAME=sponsor_portal \
DB_USER=app_user DB_PASSWORD=your_password DB_SSL=false \
dart test integration_test/
```

### All Tests with Coverage

```bash
./tool/coverage.sh --unit
./tool/coverage.sh --integration --start-db --stop-db
```

## CI/CD Integration

Integration tests run in GitHub Actions using PostgreSQL as a service container.

See `.github/workflows/diary-server-ci.yml`

### Environment Variables for Tests

| Variable      | Description            | CI Value         | Local (Doppler)       |
|---------------|------------------------|------------------|-----------------------|
| `DB_HOST`     | PostgreSQL host        | `localhost`      | `localhost`           |
| `DB_PORT`     | PostgreSQL port        | `5432`           | `5432`                |
| `DB_NAME`     | Database name          | `sponsor_portal` | `sponsor_portal`      |
| `DB_USER`     | Database user          | `postgres`       | `app_user`            |
| `DB_PASSWORD` | Database password      | `postgres`       | `LOCAL_DB_PASSWORD`   |
| `DB_SSL`      | Enable SSL             | `false`          | `false`               |

## Test Database Setup

Integration tests expect the database schema to be applied. The schema is applied:

- **Locally**: Automatically when starting `docker-compose.db.yml`
- **CI**: Explicitly via `psql -f database/init.sql`

## Writing New Tests

### Unit Tests

Unit tests should not require a database. Test pure business logic:

```dart
// test/my_test.dart
import 'package:test/test.dart';

void main() {
  group('MyFeature', () {
    test('does something', () {
      // Test logic without database
    });
  });
}
```

### Integration Tests

Integration tests use `TestServer` helper which manages server lifecycle:

```dart
// integration_test/my_integration_test.dart
@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'test_server.dart';

void main() {
  late TestServer server;
  late http.Client client;

  setUpAll(() async {
    server = TestServer();
    await server.start();
    client = http.Client();
  });

  tearDownAll(() async {
    client.close();
    await server.stop();
  });

  test('my API test', () async {
    final response = await client.get(
      Uri.parse('${server.baseUrl}/my/endpoint'),
    );
    expect(response.statusCode, equals(200));
  });
}
```

## Troubleshooting

### "Database not initialized" errors

Ensure PostgreSQL is running and the schema is applied:
```bash
docker exec -it sponsor-portal-postgres psql -U postgres -d sponsor_portal -c '\dt'
```

### Connection refused in CI

Check that the service container is healthy before running tests. The workflow
should wait for the health check.

### Tests pass locally but fail in CI

Check environment variable differences. CI uses `postgres` user while local
development typically uses `app_user`.

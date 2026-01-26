# Database Test Suite

Comprehensive test suite for the Diary Database, covering compliance requirements, data integrity, and business logic.

## Overview

This test suite validates:
- **Audit trail immutability** (FDA 21 CFR Part 11)
- **Trigger functionality** (event sourcing)
- **Row-Level Security policies** (access control)
- **Tamper detection** (cryptographic integrity)
- **Conflict resolution** (offline sync)
- **ALCOA+ compliance** (regulatory requirements)

## Test Framework

These tests use PostgreSQL's built-in testing capabilities with transactional isolation. Each test runs in a transaction that is rolled back, ensuring no persistent changes to the database.

For production deployment, consider integrating with:
- **pgTap** - PostgreSQL unit testing framework
- **pg_prove** - Test harness for pgTap tests
- **CI/CD integration** - GitHub Actions, GitLab CI, etc.

## Test Files

### Core Functionality Tests
- **test_audit_trail.sql** - Audit trail immutability and integrity
- **test_triggers.sql** - Trigger behavior and state synchronization
- **test_rls_policies.sql** - Row-Level Security access control
- **test_tamper_detection.sql** - Cryptographic hash verification
- **test_conflict_resolution.sql** - Offline sync conflict handling

### Compliance Tests
- **test_alcoa_compliance.sql** - ALCOA+ principle validation
- **test_compliance_functions.sql** - Compliance verification functions

### Test Infrastructure
- **setup_test_data.sql** - Create test fixtures
- **run_all_tests.sh** - Execute complete test suite

## Running Tests

### Option 1: Individual Test Files

```bash
# Run specific test
psql -U postgres -d dbtest_test -f database/tests/test_audit_trail.sql

# Run with output
psql -U postgres -d dbtest_test -f database/tests/test_audit_trail.sql | grep -E "(PASS|FAIL|Test)"
```

### Option 2: Complete Test Suite

```bash
# Run all tests
cd database/tests
./run_all_tests.sh

# Or with psql
psql -U postgres -d dbtest_test -f run_all_tests.sql
```

### Option 3: With pgTap (Recommended for CI/CD)

```bash
# Install pgTap extension
CREATE EXTENSION pgtap;

# Run tests with pg_prove
pg_prove -U postgres -d dbtest_test database/tests/*.sql
```

## Test Database Setup

Create a separate test database to avoid affecting development/production:

```sql
-- Create test database
CREATE DATABASE dbtest_test;

-- Connect to test database
\c dbtest_test

-- Initialize schema
\i database/init.sql

-- Load test data
\i database/tests/setup_test_data.sql
```

## Test Structure

Each test file follows this pattern:

```sql
-- =====================================================
-- Test: [Test Name]
-- Purpose: [What is being tested]
-- =====================================================

BEGIN;  -- Start transaction

-- Setup test data
INSERT INTO ...;

-- Run test
DO $$
DECLARE
    v_result BOOLEAN;
BEGIN
    -- Test logic here
    v_result := (SELECT ...);

    IF v_result THEN
        RAISE NOTICE 'PASS: Test description';
    ELSE
        RAISE EXCEPTION 'FAIL: Test description';
    END IF;
END $$;

ROLLBACK;  -- Cleanup (no persistent changes)
```

## Test Coverage

### Audit Trail (test_audit_trail.sql)
- ✅ Audit entries are immutable (cannot UPDATE)
- ✅ Audit entries are permanent (cannot DELETE)
- ✅ Signature hash automatically computed
- ✅ Hash verification works correctly
- ✅ State table updated via trigger
- ✅ All required metadata captured

### Triggers (test_triggers.sql)
- ✅ State synchronization from audit
- ✅ Validation triggers enforce rules
- ✅ Environment-aware state protection
- ✅ Annotation resolution triggers
- ✅ Conflict detection triggers

### RLS Policies (test_rls_policies.sql)
- ✅ USER role: Own data only
- ✅ INVESTIGATOR role: Assigned sites only
- ✅ ANALYST role: Read-only assigned sites
- ✅ ADMIN role: Global access
- ✅ Cross-site access prevented
- ✅ Direct state modification blocked

### Tamper Detection (test_tamper_detection.sql)
- ✅ Hash computed on insert
- ✅ Hash verification detects tampering
- ✅ Audit chain validation works
- ✅ Batch verification performs correctly

### Conflict Resolution (test_conflict_resolution.sql)
- ✅ Conflicts detected correctly
- ✅ Auto-resolution triggers work
- ✅ Manual resolution supported
- ✅ Conflict history preserved

### ALCOA+ Compliance (test_alcoa_compliance.sql)
- ✅ Attributable: User ID and role captured
- ✅ Legible: Data in structured format
- ✅ Contemporaneous: Timestamps present
- ✅ Original: Immutability enforced
- ✅ Accurate: Hash verification
- ✅ Complete: All metadata present
- ✅ Consistent: Parent references valid
- ✅ Enduring: Permanent retention
- ✅ Available: Retrievable via SQL

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Database Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - name: Setup database
        run: |
          psql -U postgres -c "CREATE DATABASE dbtest_test;"
          psql -U postgres -d dbtest_test -f database/init.sql

      - name: Run tests
        run: |
          cd database/tests
          ./run_all_tests.sh
```

## Test Maintenance

### Adding New Tests

1. Create test file: `test_new_feature.sql`
2. Follow standard test structure
3. Add to `run_all_tests.sh` or `run_all_tests.sql`
4. Document in this README

### Updating Tests

When schema changes:
1. Update affected test files
2. Re-run full test suite
3. Update `setup_test_data.sql` if needed
4. Verify all tests pass before merging

### Test Data

Test data is created in `setup_test_data.sql`:
- Deterministic UUIDs for reproducibility
- Multiple test users with different roles
- Various test scenarios (conflicts, annotations, etc.)
- All tests use same fixtures for consistency

## Troubleshooting

### Tests Fail to Run

```sql
-- Check if database initialized
SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';
-- Should return 13

-- Check if test data loaded
SELECT COUNT(*) FROM sites WHERE site_id LIKE 'test_%';
-- Should return > 0
```

### Permission Errors

```sql
-- Ensure test user has required permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO test_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO test_user;
```

### RLS Policy Tests Fail

```sql
-- Set JWT claims for role testing
SET request.jwt.claims = '{"sub": "user_123", "role": "USER"}';

-- Reset between tests
RESET request.jwt.claims;
```

## Compliance Notes

Per `spec/core-practices.md:61-100`:
- ✅ Test-Driven Development: Tests written for all compliance features
- ✅ Integration-First: Tests use real database, no mocks
- ✅ Real Environment: Tests run against actual PostgreSQL
- ✅ Compliance Validation: ALCOA+ principles verified

Tests provide evidence for regulatory inspections:
- FDA 21 CFR Part 11: Audit trail validation
- HIPAA: Access control verification
- GDPR: Data handling compliance

## References

- **Core Practices**: `spec/core-practices.md:61-100`
- **Compliance Requirements**: `spec/compliance-practices.md`
- **Database Schema**: `database/schema.sql`
- **pgTap Documentation**: https://pgtap.org/

---

**Version**: 1.0
**Last Updated**: 2025-10-15
**Status**: Design Stage

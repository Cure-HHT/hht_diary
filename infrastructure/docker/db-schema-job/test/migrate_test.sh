#!/usr/bin/env bash
# infrastructure/docker/db-schema-job/test/migrate_test.sh
#
# Behavioural tests for migrate_database() and reset_database() in entrypoint.sh.
#
# Design notes:
#   - Uses a temp MIGRATIONS_DIR with trivial idempotent test migrations
#     (approach (b)) so tests exercise the runner logic cleanly without
#     depending on real migration SQL that assumes baseline tables exist.
#   - Each runner function calls `exit` on success, so invocations are
#     wrapped in subshells: ( migrate_database ) || true
#     DB side effects (INSERTs into schema_migrations) persist across
#     subshell boundaries since the DB is external.
#   - Source entrypoint.sh AFTER exporting required env vars + _DOPPLER_INJECTED=1.
#     The BASH_SOURCE guard means sourcing won't run the dispatcher.
#
# Usage (inside postgres:17 container):
#   bash infrastructure/docker/db-schema-job/test/migrate_test.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
ENTRYPOINT="${REPO_ROOT}/infrastructure/docker/db-schema-job/entrypoint.sh"
SCHEMA_MIGRATIONS_SQL="${REPO_ROOT}/database/schema_migrations.sql"

DB_HOST="${PGHOST:-postgres}"
DB_USER="${PGUSER:-postgres}"
DB_PASSWORD="${PGPASSWORD:-postgres}"
TEST_DB="migrate_test_$$"

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }

psql_test() {
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${TEST_DB}" -tAc "$1"
}

# ---------------------------------------------------------------------------
# Setup: create a fresh test DB with only schema_migrations
# ---------------------------------------------------------------------------
echo "=== Setup: creating test DB ${TEST_DB} ==="
PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE \"${TEST_DB}\""
PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d "${TEST_DB}" -v ON_ERROR_STOP=1 -f "${SCHEMA_MIGRATIONS_SQL}"
echo "Test DB ready."

# ---------------------------------------------------------------------------
# Create a temp MIGRATIONS_DIR with 2 trivial idempotent test migrations
# ---------------------------------------------------------------------------
MIGRATIONS_DIR=$(mktemp -d)
cat > "${MIGRATIONS_DIR}/001_t.sql" <<'SQL'
CREATE TABLE IF NOT EXISTS t1 (x int);
SQL
cat > "${MIGRATIONS_DIR}/002_t.sql" <<'SQL'
CREATE TABLE IF NOT EXISTS t2 (x int);
SQL

# ---------------------------------------------------------------------------
# Source entrypoint.sh (BASH_SOURCE guard prevents dispatcher from running)
# ---------------------------------------------------------------------------
export DB_HOST DB_USER DB_PASSWORD
export DB_PORT=5432
export DB_NAME="${TEST_DB}"
export SCHEMA_BUCKET="gs://unused-in-test"
export SCHEMA_PREFIX="db-schema"
export SPONSOR="test-sponsor"
export ENVIRONMENT="dev"
export MIGRATIONS_DIR
export MODE="migrate"
export _DOPPLER_INJECTED=1
# Suppress optional vars used only by reset_database (gsutil/gcloud calls)
export DEFAULT_USER_PWD=""
export RESET_IDS="false"
export SKIP_IF_TABLES_EXIST="true"
export LOG_LEVEL="INFO"

# shellcheck source=../entrypoint.sh
source "${ENTRYPOINT}"

# ---------------------------------------------------------------------------
# TEST 1: migrate_database applies all pending migrations (001 + 002 → max id=2)
# ---------------------------------------------------------------------------
echo ""
echo "=== TEST 1: First migrate run applies both pending migrations ==="
( migrate_database ) || true

actual=$(psql_test "SELECT COALESCE(MAX(id), -1) FROM schema_migrations")
if [[ "${actual}" == "2" ]]; then
    pass "TEST 1: MAX(id) == 2 after first migrate run"
else
    fail "TEST 1: expected MAX(id)=2, got '${actual}'"
fi

row_count_after_first=$(psql_test "SELECT COUNT(*) FROM schema_migrations")

# ---------------------------------------------------------------------------
# TEST 2: Re-running migrate_database is idempotent (no new rows inserted)
# ---------------------------------------------------------------------------
echo ""
echo "=== TEST 2: Second migrate run is idempotent ==="
( migrate_database ) || true

actual_max=$(psql_test "SELECT COALESCE(MAX(id), -1) FROM schema_migrations")
actual_count=$(psql_test "SELECT COUNT(*) FROM schema_migrations")
if [[ "${actual_max}" == "2" && "${actual_count}" == "${row_count_after_first}" ]]; then
    pass "TEST 2: idempotent — MAX(id)=2, row count unchanged at ${actual_count}"
else
    fail "TEST 2: expected MAX(id)=2 and count=${row_count_after_first}, got MAX(id)=${actual_max} count=${actual_count}"
fi

# ---------------------------------------------------------------------------
# TEST 3: Adding a new migration file causes only that migration to be applied
# ---------------------------------------------------------------------------
echo ""
echo "=== TEST 3: Adding migration 003 applies only 003 ==="
cat > "${MIGRATIONS_DIR}/003_t.sql" <<'SQL'
CREATE TABLE IF NOT EXISTS t3 (x int);
SQL

( migrate_database ) || true

actual_max=$(psql_test "SELECT COALESCE(MAX(id), -1) FROM schema_migrations")
actual_count=$(psql_test "SELECT COUNT(*) FROM schema_migrations")
if [[ "${actual_max}" == "3" && "${actual_count}" == "3" ]]; then
    pass "TEST 3: MAX(id)=3 and row count=3 after adding migration 003"
else
    fail "TEST 3: expected MAX(id)=3 count=3, got MAX(id)=${actual_max} count=${actual_count}"
fi

# ---------------------------------------------------------------------------
# TEST 4: reset_database rejects prod (MODE=reset is not permitted on prod)
# ---------------------------------------------------------------------------
echo ""
echo "=== TEST 4: reset_database refuses to run on prod ==="
prod_output_file=$(mktemp)
( ENVIRONMENT=prod reset_database ) > "${prod_output_file}" 2>&1 || true
prod_output=$(cat "${prod_output_file}")
rm -f "${prod_output_file}"
if echo "${prod_output}" | grep -q "not permitted on prod"; then
    pass "TEST 4: prod guard triggered — output contains 'not permitted on prod'"
else
    fail "TEST 4: expected 'not permitted on prod' in output; got: ${prod_output}"
fi

# ---------------------------------------------------------------------------
# Teardown
# ---------------------------------------------------------------------------
echo ""
echo "=== Teardown ==="
rm -rf "${MIGRATIONS_DIR}"
PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${TEST_DB}' AND pid <> pg_backend_pid();" \
    > /dev/null 2>&1 || true
PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres \
    -c "DROP DATABASE IF EXISTS \"${TEST_DB}\"" > /dev/null 2>&1 || true
echo "Test DB ${TEST_DB} dropped."

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
exit 0

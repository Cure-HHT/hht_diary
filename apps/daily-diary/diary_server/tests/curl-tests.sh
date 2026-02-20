#!/bin/bash
# HHT Diary Server API Test Suite - curl version
# Usage: ./curl-tests.sh [base_url]
# Example: ./curl-tests.sh http://localhost:8080
#
# Requirements:
# - curl
# - jq (for JSON parsing)
# - Server running at base URL

set -e

# Configuration
BASE_URL="${1:-${BASE_URL:-http://localhost:8080}}"
CONTENT_TYPE="Content-Type: application/json"

# Test data
TEST_USERNAME="testuser$(date +%s)"
TEST_PASSWORD_HASH="a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3"
TEST_APP_UUID="550e8400-e29b-41d4-a716-446655440000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# State variables
AUTH_TOKEN=""
USER_ID=""

# Helper functions
log_test() {
    echo -e "\n${YELLOW}TEST: $1${NC}"
}

log_pass() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    ((TESTS_FAILED++))
}

check_status() {
    local expected=$1
    local actual=$2
    local test_name=$3

    if [ "$actual" -eq "$expected" ]; then
        log_pass "$test_name (status: $actual)"
        return 0
    else
        log_fail "$test_name (expected: $expected, got: $actual)"
        return 1
    fi
}

# ============================================================================
# HEALTH CHECK
# ============================================================================

test_health() {
    log_test "Health Check"

    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/health")
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    check_status 200 "$status" "Health endpoint returns 200"

    if echo "$body" | jq -e '.status == "ok"' > /dev/null 2>&1; then
        log_pass "Status is 'ok'"
    else
        log_fail "Status should be 'ok'"
    fi
}

# ============================================================================
# REGISTRATION TESTS
# ============================================================================

test_register_success() {
    log_test "Register - Success"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
        -H "$CONTENT_TYPE" \
        -d "{\"username\":\"$TEST_USERNAME\",\"passwordHash\":\"$TEST_PASSWORD_HASH\",\"appUuid\":\"$TEST_APP_UUID\"}")

    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    check_status 200 "$status" "Registration returns 200"

    AUTH_TOKEN=$(echo "$body" | jq -r '.jwt // empty')
    USER_ID=$(echo "$body" | jq -r '.userId // empty')

    if [ -n "$AUTH_TOKEN" ] && [ "$AUTH_TOKEN" != "null" ]; then
        log_pass "JWT token received"
    else
        log_fail "JWT token missing"
    fi

    if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
        log_pass "User ID received"
    else
        log_fail "User ID missing"
    fi
}

test_register_username_too_short() {
    log_test "Register - Username Too Short"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
        -H "$CONTENT_TYPE" \
        -d '{"username":"abc","passwordHash":"'"$TEST_PASSWORD_HASH"'","appUuid":"'"$TEST_APP_UUID"'"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Short username rejected"
}

test_register_invalid_chars() {
    log_test "Register - Invalid Username Characters"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
        -H "$CONTENT_TYPE" \
        -d '{"username":"test-user-123","passwordHash":"'"$TEST_PASSWORD_HASH"'","appUuid":"'"$TEST_APP_UUID"'"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Invalid chars rejected"
}

test_register_username_with_at() {
    log_test "Register - Username Contains @"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
        -H "$CONTENT_TYPE" \
        -d '{"username":"test@user","passwordHash":"'"$TEST_PASSWORD_HASH"'","appUuid":"'"$TEST_APP_UUID"'"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Username with @ rejected"
}

test_register_invalid_hash() {
    log_test "Register - Invalid Password Hash"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
        -H "$CONTENT_TYPE" \
        -d '{"username":"validuser123","passwordHash":"not-a-valid-hash","appUuid":"'"$TEST_APP_UUID"'"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Invalid hash rejected"
}

test_register_missing_app_uuid() {
    log_test "Register - Missing appUuid"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
        -H "$CONTENT_TYPE" \
        -d '{"username":"validuser456","passwordHash":"'"$TEST_PASSWORD_HASH"'"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Missing appUuid rejected"
}

test_register_duplicate() {
    log_test "Register - Duplicate Username"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
        -H "$CONTENT_TYPE" \
        -d "{\"username\":\"$TEST_USERNAME\",\"passwordHash\":\"$TEST_PASSWORD_HASH\",\"appUuid\":\"different-uuid\"}")

    status=$(echo "$response" | tail -n1)
    check_status 409 "$status" "Duplicate username returns 409"
}

# ============================================================================
# LOGIN TESTS
# ============================================================================

test_login_success() {
    log_test "Login - Success"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
        -H "$CONTENT_TYPE" \
        -d "{\"username\":\"$TEST_USERNAME\",\"passwordHash\":\"$TEST_PASSWORD_HASH\"}")

    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    check_status 200 "$status" "Login returns 200"

    AUTH_TOKEN=$(echo "$body" | jq -r '.jwt // empty')
    if [ -n "$AUTH_TOKEN" ] && [ "$AUTH_TOKEN" != "null" ]; then
        log_pass "JWT token received on login"
    else
        log_fail "JWT token missing on login"
    fi
}

test_login_missing_fields() {
    log_test "Login - Missing Username"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
        -H "$CONTENT_TYPE" \
        -d '{"passwordHash":"'"$TEST_PASSWORD_HASH"'"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Missing username rejected"
}

test_login_invalid_credentials() {
    log_test "Login - Invalid Credentials"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
        -H "$CONTENT_TYPE" \
        -d '{"username":"'"$TEST_USERNAME"'","passwordHash":"0000000000000000000000000000000000000000000000000000000000000000"}')

    status=$(echo "$response" | tail -n1)
    check_status 401 "$status" "Invalid credentials rejected"
}

# ============================================================================
# CHANGE PASSWORD TESTS
# ============================================================================

test_change_password_success() {
    log_test "Change Password - Success"

    if [ -z "$AUTH_TOKEN" ]; then
        log_fail "No auth token available"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/change-password" \
        -H "$CONTENT_TYPE" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d '{"currentPasswordHash":"'"$TEST_PASSWORD_HASH"'","newPasswordHash":"b3a8e0e1f9ab1bfe3a36f231f676f78bb30a519d2b21e6c530c0eee8ebb4a5d0"}')

    status=$(echo "$response" | tail -n1)
    check_status 200 "$status" "Password changed successfully"

    # Update password hash for subsequent tests
    TEST_PASSWORD_HASH="b3a8e0e1f9ab1bfe3a36f231f676f78bb30a519d2b21e6c530c0eee8ebb4a5d0"
}

test_change_password_missing_auth() {
    log_test "Change Password - Missing Authorization"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/change-password" \
        -H "$CONTENT_TYPE" \
        -d '{"currentPasswordHash":"'"$TEST_PASSWORD_HASH"'","newPasswordHash":"c4b9f1f2a0bc2cfe4b47c342c787c89cc41b620e3c32f7d641f0fff9fcc5b6e1"}')

    status=$(echo "$response" | tail -n1)
    check_status 401 "$status" "Missing auth rejected"
}

# ============================================================================
# LINK PATIENT TESTS
# ============================================================================

test_link_missing_code() {
    log_test "Link Patient - Missing Code"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/link" \
        -H "$CONTENT_TYPE" \
        -d '{"appUuid":"'"$TEST_APP_UUID"'"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Missing code rejected"
}

test_link_invalid_format() {
    log_test "Link Patient - Invalid Code Format"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/link" \
        -H "$CONTENT_TYPE" \
        -d '{"code":"SHORT","appUuid":"'"$TEST_APP_UUID"'"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Invalid format rejected"
}

test_link_unknown_code() {
    log_test "Link Patient - Unknown Code"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/link" \
        -H "$CONTENT_TYPE" \
        -d '{"code":"XX00000000","appUuid":"'"$TEST_APP_UUID"'"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Unknown code rejected"
}

# ============================================================================
# DEPRECATED ENDPOINT TEST
# ============================================================================

test_enroll_deprecated() {
    log_test "Enroll - Deprecated Endpoint"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/enroll" \
        -H "$CONTENT_TYPE" \
        -d '{"enrollmentCode":"TEST123"}')

    status=$(echo "$response" | tail -n1)
    check_status 410 "$status" "Deprecated endpoint returns 410"
}

# ============================================================================
# SYNC TESTS
# ============================================================================

test_sync_empty() {
    log_test "Sync Events - Empty Array"

    if [ -z "$AUTH_TOKEN" ]; then
        log_fail "No auth token available"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/sync" \
        -H "$CONTENT_TYPE" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d '{"events":[]}')

    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    check_status 200 "$status" "Sync empty returns 200"

    if echo "$body" | jq -e '.syncedCount == 0' > /dev/null 2>&1; then
        log_pass "Synced count is 0"
    else
        log_fail "Synced count should be 0"
    fi
}

test_sync_single_event() {
    log_test "Sync Events - Single Event"

    if [ -z "$AUTH_TOKEN" ]; then
        log_fail "No auth token available"
        return
    fi

    event_id="123e4567-e89b-12d3-a456-$(date +%s%N | cut -c1-12)"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/sync" \
        -H "$CONTENT_TYPE" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d '{
            "events": [{
                "event_id": "'"$event_id"'",
                "event_type": "NOSEBLEEDRECORDED",
                "data": {
                    "timestamp": "2025-02-19T08:30:00.000Z",
                    "duration": 15,
                    "severity": 3
                }
            }]
        }')

    status=$(echo "$response" | tail -n1)
    check_status 200 "$status" "Sync single event returns 200"
}

test_sync_missing_auth() {
    log_test "Sync Events - Missing Authorization"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/sync" \
        -H "$CONTENT_TYPE" \
        -d '{"events":[]}')

    status=$(echo "$response" | tail -n1)
    check_status 401 "$status" "Missing auth rejected"
}

test_sync_invalid_events() {
    log_test "Sync Events - Invalid Events (not array)"

    if [ -z "$AUTH_TOKEN" ]; then
        log_fail "No auth token available"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/sync" \
        -H "$CONTENT_TYPE" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d '{"events":"not-an-array"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Non-array events rejected"
}

# ============================================================================
# RECORDS TESTS
# ============================================================================

test_records_success() {
    log_test "Get Records - Success"

    if [ -z "$AUTH_TOKEN" ]; then
        log_fail "No auth token available"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/records" \
        -H "$CONTENT_TYPE" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d '{}')

    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    check_status 200 "$status" "Get records returns 200"

    if echo "$body" | jq -e '.records | type == "array"' > /dev/null 2>&1; then
        log_pass "Records is an array"
    else
        log_fail "Records should be an array"
    fi
}

test_records_missing_auth() {
    log_test "Get Records - Missing Authorization"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/records" \
        -H "$CONTENT_TYPE" \
        -d '{}')

    status=$(echo "$response" | tail -n1)
    check_status 401 "$status" "Missing auth rejected"
}

# ============================================================================
# FCM TOKEN TESTS
# ============================================================================

test_fcm_missing_token() {
    log_test "FCM Token - Missing Token"

    if [ -z "$AUTH_TOKEN" ]; then
        log_fail "No auth token available"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/fcm-token" \
        -H "$CONTENT_TYPE" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d '{"platform":"ios"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Missing token rejected"
}

test_fcm_invalid_platform() {
    log_test "FCM Token - Invalid Platform"

    if [ -z "$AUTH_TOKEN" ]; then
        log_fail "No auth token available"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/fcm-token" \
        -H "$CONTENT_TYPE" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d '{"fcm_token":"test-token","platform":"windows"}')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Invalid platform rejected"
}

test_fcm_no_linked_patient() {
    log_test "FCM Token - No Linked Patient"

    if [ -z "$AUTH_TOKEN" ]; then
        log_fail "No auth token available"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/user/fcm-token" \
        -H "$CONTENT_TYPE" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d '{"fcm_token":"test-token-12345","platform":"ios"}')

    status=$(echo "$response" | tail -n1)
    check_status 409 "$status" "No linked patient returns 409"
}

# ============================================================================
# SPONSOR CONFIG TESTS
# ============================================================================

test_sponsor_config_callisto() {
    log_test "Sponsor Config - Callisto"

    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/v1/sponsor/config?sponsorId=callisto")

    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    check_status 200 "$status" "Callisto config returns 200"

    if echo "$body" | jq -e '.sponsorId == "callisto"' > /dev/null 2>&1; then
        log_pass "SponsorId is callisto"
    else
        log_fail "SponsorId should be callisto"
    fi

    if echo "$body" | jq -e '.flags.requireOldEntryJustification == true' > /dev/null 2>&1; then
        log_pass "Callisto requires old entry justification"
    else
        log_fail "Callisto should require old entry justification"
    fi
}

test_sponsor_config_unknown() {
    log_test "Sponsor Config - Unknown Sponsor"

    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/v1/sponsor/config?sponsorId=unknownsponsor")

    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    check_status 200 "$status" "Unknown sponsor returns 200 with defaults"

    if echo "$body" | jq -e '.isDefault == true' > /dev/null 2>&1; then
        log_pass "Returns default config"
    else
        log_fail "Should return default config"
    fi
}

test_sponsor_config_missing_id() {
    log_test "Sponsor Config - Missing sponsorId"

    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/v1/sponsor/config")

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Missing sponsorId rejected"
}

test_sponsor_config_wrong_method() {
    log_test "Sponsor Config - Wrong HTTP Method"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/sponsor/config?sponsorId=callisto" \
        -H "$CONTENT_TYPE" \
        -d '{}')

    status=$(echo "$response" | tail -n1)
    check_status 405 "$status" "POST method rejected"
}

# ============================================================================
# SECURITY TESTS
# ============================================================================

test_sql_injection() {
    log_test "Security - SQL Injection Attempt"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
        -H "$CONTENT_TYPE" \
        -d '{"username":"admin'"'"'; DROP TABLE users; --","passwordHash":"'"$TEST_PASSWORD_HASH"'"}')

    status=$(echo "$response" | tail -n1)

    if [ "$status" -eq 400 ] || [ "$status" -eq 401 ]; then
        log_pass "SQL injection rejected (status: $status)"
    else
        log_fail "SQL injection should be rejected (got: $status)"
    fi

    if [ "$status" -ne 500 ]; then
        log_pass "No server error on injection attempt"
    else
        log_fail "Server error on injection attempt"
    fi
}

test_malformed_json() {
    log_test "Security - Malformed JSON"

    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
        -H "$CONTENT_TYPE" \
        -d '{ "username": "test", broken json')

    status=$(echo "$response" | tail -n1)
    check_status 400 "$status" "Malformed JSON rejected"
}

# ============================================================================
# MAIN
# ============================================================================

echo "============================================"
echo "HHT Diary Server API Test Suite"
echo "============================================"
echo "Base URL: $BASE_URL"
echo "Test Username: $TEST_USERNAME"
echo "============================================"

# Check if server is running
if ! curl -s "$BASE_URL/health" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Server not reachable at $BASE_URL${NC}"
    echo "Start the server with: doppler run -- dart run bin/server.dart"
    exit 1
fi

# Run all tests
echo -e "\n========== HEALTH CHECK =========="
test_health

echo -e "\n========== REGISTRATION =========="
test_register_success
test_register_username_too_short
test_register_invalid_chars
test_register_username_with_at
test_register_invalid_hash
test_register_missing_app_uuid
test_register_duplicate

echo -e "\n========== LOGIN =========="
test_login_success
test_login_missing_fields
test_login_invalid_credentials

echo -e "\n========== CHANGE PASSWORD =========="
test_change_password_success
test_change_password_missing_auth

echo -e "\n========== PATIENT LINKING =========="
test_link_missing_code
test_link_invalid_format
test_link_unknown_code

echo -e "\n========== DEPRECATED ENDPOINTS =========="
test_enroll_deprecated

echo -e "\n========== SYNC EVENTS =========="
test_sync_empty
test_sync_single_event
test_sync_missing_auth
test_sync_invalid_events

echo -e "\n========== RECORDS =========="
test_records_success
test_records_missing_auth

echo -e "\n========== FCM TOKEN =========="
test_fcm_missing_token
test_fcm_invalid_platform
test_fcm_no_linked_patient

echo -e "\n========== SPONSOR CONFIG =========="
test_sponsor_config_callisto
test_sponsor_config_unknown
test_sponsor_config_missing_id
test_sponsor_config_wrong_method

echo -e "\n========== SECURITY =========="
test_sql_injection
test_malformed_json

# Summary
echo -e "\n============================================"
echo "TEST SUMMARY"
echo "============================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "Total: $((TESTS_PASSED + TESTS_FAILED))"
echo "============================================"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

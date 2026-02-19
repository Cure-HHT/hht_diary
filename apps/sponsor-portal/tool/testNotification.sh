#!/usr/bin/env bash
# ============================================================================
# Test FCM Notification via Portal Server API
# ============================================================================
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
#   REQ-CAL-p00082: Patient Alert Delivery
#
# Tests the questionnaire notification flow by calling the portal server's
# API endpoints. When running locally with FCM_CONSOLE_MODE=true, the
# server logs the FCM payload to stdout instead of sending it.
#
# PREREQUISITES:
#   1. Portal server running locally: ./tool/run_local.sh
#   2. Database seeded with at least one patient with trial_started=true
#   3. Firebase Auth emulator or Identity Platform for auth tokens
#
# USAGE:
#   ./tool/testNotification.sh                          # Send nose_hht to first active patient
#   ./tool/testNotification.sh --type eq                # Send EQ questionnaire
#   ./tool/testNotification.sh --type qol               # Send QoL questionnaire
#   ./tool/testNotification.sh --patient <patient_id>   # Target specific patient
#   ./tool/testNotification.sh --status                 # Check questionnaire status
#   ./tool/testNotification.sh --delete <instance_id>   # Delete a questionnaire
#   ./tool/testNotification.sh --help                   # Show help
#
# WHAT THIS TESTS:
#   When the portal server runs with FCM_CONSOLE_MODE=true (default in
#   run_local.sh), it logs the FCM message payload to the server's console
#   instead of sending it to Firebase. Look for the "FCM CONSOLE MODE"
#   banner in the server output.
#
#   There is no Firebase emulator for FCM - only Auth and Firestore have
#   emulators. So this is the closest we can get to testing the notification
#   flow locally.
# ============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
PORTAL_URL="${PORTAL_URL:-http://localhost:8080}"
FIREBASE_EMULATOR_URL="${FIREBASE_EMULATOR_URL:-http://localhost:9099}"
DEV_EMAIL="mike.bushe@anspar.org"
DEV_PASSWORD="curehht"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
QUESTIONNAIRE_TYPE="nose_hht"
PATIENT_ID=""
MODE="send"
INSTANCE_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            QUESTIONNAIRE_TYPE="$2"
            shift 2
            ;;
        --patient)
            PATIENT_ID="$2"
            shift 2
            ;;
        --status)
            MODE="status"
            shift
            ;;
        --delete)
            MODE="delete"
            INSTANCE_ID="$2"
            shift 2
            ;;
        --help|-h)
            echo "Test FCM Notification via Portal Server API"
            echo ""
            echo "Usage: ./tool/testNotification.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --type <type>        Questionnaire type: nose_hht, qol, eq (default: nose_hht)"
            echo "  --patient <id>       Target patient UUID (default: first active patient)"
            echo "  --status             Check questionnaire status instead of sending"
            echo "  --delete <id>        Delete a questionnaire instance by ID"
            echo "  --help, -h           Show this help"
            echo ""
            echo "Prerequisites:"
            echo "  Portal server running: ./tool/run_local.sh"
            echo "  Server should show FCM_CONSOLE_MODE=true in startup logs"
            echo ""
            echo "Examples:"
            echo "  ./tool/testNotification.sh                   # Send nose_hht"
            echo "  ./tool/testNotification.sh --type eq         # Send EQ"
            echo "  ./tool/testNotification.sh --status          # Check status"
            echo "  ./tool/testNotification.sh --delete <uuid>   # Delete/revoke"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage"
            exit 1
            ;;
    esac
done

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "============================================================"
echo "  FCM Notification Test"
echo "============================================================"
echo ""
echo "  Portal Server:       $PORTAL_URL"
echo "  Firebase Emulator:   $FIREBASE_EMULATOR_URL"
echo "  Questionnaire Type:  $QUESTIONNAIRE_TYPE"
echo "  Mode:                $MODE"
echo ""

# Step 1: Check portal server is running
log_info "Checking portal server..."
if ! curl -s "$PORTAL_URL/api/v1/portal/health" > /dev/null 2>&1; then
    # Try a simple GET - some servers may not have /health
    if ! curl -s -o /dev/null -w "%{http_code}" "$PORTAL_URL/" > /dev/null 2>&1; then
        log_error "Portal server not reachable at $PORTAL_URL"
        log_error "Start it first: ./tool/run_local.sh --no-ui"
        exit 1
    fi
fi
log_success "Portal server is running"

# Step 2: Get auth token from Firebase emulator
log_info "Authenticating as $DEV_EMAIL..."

AUTH_RESPONSE=$(curl -s -X POST \
    "${FIREBASE_EMULATOR_URL}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${DEV_EMAIL}\",\"password\":\"${DEV_PASSWORD}\",\"returnSecureToken\":true}")

ID_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"idToken" *: *"[^"]*"' | sed 's/"idToken" *: *"//g' | sed 's/"//g')

if [ -z "$ID_TOKEN" ]; then
    log_error "Failed to authenticate. Is the Firebase emulator running?"
    log_error "Response: $AUTH_RESPONSE"
    log_error ""
    log_error "Make sure you started with: ./tool/run_local.sh"
    log_error "(without --dev flag, so Firebase emulator is used)"
    exit 1
fi

log_success "Authenticated (token: ${ID_TOKEN:0:20}...)"

# Step 3: Find a patient with trial_started=true (if no patient specified)
if [ -z "$PATIENT_ID" ]; then
    log_info "Looking up active trial patients..."

    # Use the patients endpoint to find a trial-active patient
    PATIENTS_RESPONSE=$(curl -s -X GET \
        "$PORTAL_URL/api/v1/portal/patients" \
        -H "Authorization: Bearer $ID_TOKEN" \
        -H "Content-Type: application/json")

    # Extract first patient_id from response
    PATIENT_ID=$(echo "$PATIENTS_RESPONSE" | grep -o '"patient_id" *: *"[^"]*"' | head -1 | sed 's/"patient_id" *: *"//g' | sed 's/"//g')

    if [ -z "$PATIENT_ID" ]; then
        log_warn "No patients found via API. Trying direct DB query..."

        # Fallback: query DB directly (requires psql and local postgres)
        PATIENT_ID=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h localhost -p 5432 -U postgres -d sponsor_portal -t -A -c \
            "SELECT patient_id FROM patients WHERE trial_started = true LIMIT 1" 2>/dev/null || true)

        PATIENT_ID=$(echo "$PATIENT_ID" | tr -d '[:space:]')

        if [ -z "$PATIENT_ID" ]; then
            log_error "No trial-active patients found in database."
            log_error "Start a trial first via the portal UI, or seed the database:"
            log_error "  ./tool/run_local.sh --reset"
            exit 1
        fi
    fi

    log_success "Using patient: $PATIENT_ID"
fi

echo ""

# Step 4: Execute the requested mode
case $MODE in
    status)
        log_info "Fetching questionnaire status for patient $PATIENT_ID..."

        STATUS_RESPONSE=$(curl -s -X GET \
            "$PORTAL_URL/api/v1/portal/patients/$PATIENT_ID/questionnaires" \
            -H "Authorization: Bearer $ID_TOKEN" \
            -H "Content-Type: application/json")

        echo ""
        echo -e "${GREEN}Questionnaire Status:${NC}"
        echo "$STATUS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$STATUS_RESPONSE"
        ;;

    send)
        log_info "Sending $QUESTIONNAIRE_TYPE questionnaire to patient $PATIENT_ID..."
        log_info ""
        log_info "Watch the portal server console for the FCM CONSOLE MODE output!"
        log_info ""

        SEND_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
            "$PORTAL_URL/api/v1/portal/patients/$PATIENT_ID/questionnaires/$QUESTIONNAIRE_TYPE/send" \
            -H "Authorization: Bearer $ID_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"study_event": "Test Event"}')

        HTTP_CODE=$(echo "$SEND_RESPONSE" | tail -1)
        BODY=$(echo "$SEND_RESPONSE" | sed '$d')

        echo ""
        if [ "$HTTP_CODE" = "200" ]; then
            log_success "Questionnaire sent! (HTTP $HTTP_CODE)"
            echo -e "${GREEN}Response:${NC}"
            echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"

            # Extract instance ID for convenient copy-paste
            SENT_INSTANCE_ID=$(echo "$BODY" | grep -o '"instance_id" *: *"[^"]*"' | sed 's/"instance_id" *: *"//g' | sed 's/"//g')
            if [ -n "$SENT_INSTANCE_ID" ]; then
                echo ""
                log_info "To delete this questionnaire later:"
                echo "  ./tool/testNotification.sh --delete $SENT_INSTANCE_ID --patient $PATIENT_ID"
            fi
        else
            log_error "Send failed (HTTP $HTTP_CODE)"
            echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
        fi

        echo ""
        echo "============================================================"
        echo "  Check the portal server terminal for:"
        echo "  ============================================================"
        echo "  [FCM CONSOLE MODE] Would send questionnaire_sent:"
        echo "    Token: ..."
        echo "    Patient: $PATIENT_ID"
        echo "    Data: {\"type\":\"questionnaire_sent\",...}"
        echo "  ============================================================"
        echo ""
        echo "  If you see 'No FCM token found for patient' that's expected -"
        echo "  the patient_fcm_tokens table doesn't exist yet."
        echo "  The questionnaire was still created in the database."
        echo "============================================================"
        ;;

    delete)
        if [ -z "$INSTANCE_ID" ]; then
            log_error "Instance ID required for delete mode"
            log_error "Usage: ./tool/testNotification.sh --delete <instance-id> --patient <patient-id>"
            exit 1
        fi

        log_info "Deleting questionnaire $INSTANCE_ID for patient $PATIENT_ID..."

        DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
            "$PORTAL_URL/api/v1/portal/patients/$PATIENT_ID/questionnaires/$INSTANCE_ID" \
            -H "Authorization: Bearer $ID_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"reason": "Test revocation"}')

        HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -1)
        BODY=$(echo "$DELETE_RESPONSE" | sed '$d')

        echo ""
        if [ "$HTTP_CODE" = "200" ]; then
            log_success "Questionnaire deleted! (HTTP $HTTP_CODE)"
            echo -e "${GREEN}Response:${NC}"
            echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
        else
            log_error "Delete failed (HTTP $HTTP_CODE)"
            echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
        fi
        ;;
esac

echo ""

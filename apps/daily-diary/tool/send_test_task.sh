#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-CAL-p00081: Patient Task System
#   REQ-d00006: Mobile App Build and Release Process
#
# Insert a test questionnaire task for a patient in the local database.
# The mobile app will discover this task on next sync (app start or resume).
#
# Usage:
#   doppler run -- ./tool/send_test_task.sh --seed
#   doppler run -- ./tool/send_test_task.sh --code CAXXXXXXXX
#   doppler run -- ./tool/send_test_task.sh --patient 840-001-001
#   doppler run -- ./tool/send_test_task.sh --list
#   doppler run -- ./tool/send_test_task.sh --code CAXXXXXXXX --type eq
#
# Options:
#   --seed              Create a test patient with a linking code (first-time setup)
#   --code <code>       Patient linking code (e.g. CA-ABCD1234 or CAABCD1234)
#   --patient <id>      Patient ID directly (e.g. 840-001-001)
#   --type <type>       Questionnaire type: nose_hht (default), qol, eq
#   --event <event>     Study event name (default: screening)
#   --list              List all connected patients
#   -h, --help          Show this help
#
# Requires:
#   - psql installed
#   - Local PostgreSQL running (started by ./tool/run_local.sh)
#   - Doppler configured (for DB password), OR set PGPASSWORD env var

set -e

# Local database connection (hardcoded — Doppler injects cloud DB vars that
# we must ignore since this tool only targets the local PostgreSQL).
LOCAL_DB_HOST="localhost"
LOCAL_DB_PORT="5432"
LOCAL_DB_NAME="sponsor_portal"
LOCAL_DB_USER="postgres"

# Only use Doppler for the password
if [[ -z "${PGPASSWORD:-}" ]]; then
  if [[ -n "${LOCAL_DB_ROOT_PASSWORD:-}" ]]; then
    export PGPASSWORD="$LOCAL_DB_ROOT_PASSWORD"
  fi
fi

# Defaults
QUESTIONNAIRE_TYPE="nose_hht"
STUDY_EVENT="screening"
VERSION="1"
PATIENT_ID=""
LINKING_CODE=""
LIST_MODE=false
SEED_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --seed) SEED_MODE=true; shift ;;
    --code) LINKING_CODE="$2"; shift 2 ;;
    --patient) PATIENT_ID="$2"; shift 2 ;;
    --type) QUESTIONNAIRE_TYPE="$2"; shift 2 ;;
    --event) STUDY_EVENT="$2"; shift 2 ;;
    --list) LIST_MODE=true; shift ;;
    -h|--help)
      sed -n '2,/^$/s/^# \?//p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1. Use --help for usage."; exit 1 ;;
  esac
done

PSQL="psql -h $LOCAL_DB_HOST -p $LOCAL_DB_PORT -U $LOCAL_DB_USER -d $LOCAL_DB_NAME"

# Check psql is available
if ! command -v psql &>/dev/null; then
  echo "Error: psql not found. Install PostgreSQL client tools."
  exit 1
fi

# Check DB is reachable
if ! $PSQL -c "SELECT 1" &>/dev/null; then
  echo "Error: Cannot connect to database at $LOCAL_DB_HOST:$LOCAL_DB_PORT/$LOCAL_DB_NAME"
  echo "Is PostgreSQL running? (start with: ./tool/run_local.sh)"
  echo "If using Doppler: doppler run -- $0 $*"
  exit 1
fi

# --- Seed mode: create test patient + linking code ---
if $SEED_MODE; then
  TEST_SITE_ID="TEST-SITE-001"
  TEST_PATIENT_ID="TEST-001-001"

  # Generate random 8-char code (same charset as production)
  CHARS="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  RANDOM_PART=""
  for i in $(seq 1 8); do
    RANDOM_PART="${RANDOM_PART}${CHARS:$((RANDOM % ${#CHARS})):1}"
  done
  CODE="CA${RANDOM_PART}"
  DISPLAY_CODE="${CODE:0:2}-${CODE:2}"
  CODE_HASH=$(echo -n "$CODE" | shasum -a 256 | cut -d' ' -f1)

  # Find the Developer Admin portal user for generated_by FK
  ADMIN_ID=$($PSQL -tAc "
    SELECT pu.id FROM portal_users pu
    JOIN portal_user_roles pur ON pu.id = pur.user_id
    WHERE pur.role = 'Developer Admin' LIMIT 1;
  ")
  if [[ -z "$ADMIN_ID" || "$ADMIN_ID" == "" ]]; then
    echo "Error: No Developer Admin found. Run the seed data first:"
    echo "  docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal < database/seed_local_dev.sql"
    exit 1
  fi

  echo "=== Seeding test data ==="
  echo ""

  # 1. Create test site
  $PSQL -c "
    INSERT INTO sites (site_id, site_name, site_number)
    VALUES ('$TEST_SITE_ID', 'Test Site', '001')
    ON CONFLICT (site_id) DO NOTHING;
  " > /dev/null
  echo "  Site:    $TEST_SITE_ID (Test Site)"

  # 2. Create test patient
  $PSQL -c "
    INSERT INTO patients (patient_id, site_id, edc_subject_key)
    VALUES ('$TEST_PATIENT_ID', '$TEST_SITE_ID', '$TEST_PATIENT_ID')
    ON CONFLICT (patient_id) DO NOTHING;
  " > /dev/null
  echo "  Patient: $TEST_PATIENT_ID"

  # 3. Create linking code (SHA-256 hash must match what diary server computes)
  $PSQL -c "
    INSERT INTO patient_linking_codes (
      patient_id, code, code_hash, generated_by, expires_at
    ) VALUES (
      '$TEST_PATIENT_ID', '$CODE', '$CODE_HASH',
      '$ADMIN_ID'::uuid, now() + interval '72 hours'
    );
  " > /dev/null
  echo "  Code:    $DISPLAY_CODE  (expires in 72h)"

  echo ""
  echo "=== Next steps ==="
  echo "  1. Enter this code in the mobile app:  $DISPLAY_CODE"
  echo "  2. After linking, send a test task:"
  echo "     doppler run -- $0 --code $DISPLAY_CODE --type nose_hht"
  echo ""
  exit 0
fi

# --- List mode ---
if $LIST_MODE; then
  echo "=== Patients ==="
  echo ""
  ROWS=$($PSQL --no-align --tuples-only --field-separator '|' -c "
    SELECT
      p.patient_id,
      p.mobile_linking_status,
      COALESCE(plc.code, '(no code)'),
      CASE WHEN plc.used_at IS NOT NULL THEN 'used'
           WHEN plc.expires_at < now() THEN 'expired'
           ELSE 'active' END,
      (SELECT COUNT(*) FROM questionnaire_instances qi
       WHERE qi.patient_id = p.patient_id AND qi.deleted_at IS NULL)
    FROM patients p
    LEFT JOIN patient_linking_codes plc
      ON p.patient_id = plc.patient_id
      AND plc.id = (
        SELECT id FROM patient_linking_codes
        WHERE patient_id = p.patient_id
        ORDER BY generated_at DESC LIMIT 1
      )
    ORDER BY p.patient_id;
  ")
  if [[ -z "$ROWS" ]]; then
    echo "  (none — run --seed to create a test patient)"
  else
    printf "  %-20s  %-18s  %-14s  %-8s  %s\n" "PATIENT" "STATUS" "CODE" "CODE ST" "TASKS"
    echo "$ROWS" | while IFS='|' read -r pid status code code_st tasks; do
      printf "  %-20s  %-18s  %-14s  %-8s  %s\n" "$pid" "$status" "$code" "$code_st" "$tasks"
    done
  fi
  echo ""
  echo "Use: $0 --patient <patient_id> [--type nose_hht|qol|eq]"
  echo "     $0 --seed  (to create a test patient with linking code)"
  exit 0
fi

# --- Resolve patient_id ---
if [[ -n "$LINKING_CODE" ]]; then
  # Strip dashes, whitespace, and uppercase for code lookup
  CLEAN_CODE=$(printf '%s' "$LINKING_CODE" | tr -d ' ' | tr -d '-' | tr '[:lower:]' '[:upper:]')
  PATIENT_ID=$($PSQL -tAc "
    SELECT patient_id FROM patient_linking_codes
    WHERE UPPER(REPLACE(code, '-', '')) = '$CLEAN_CODE'
    LIMIT 1;
  ")
  if [[ -z "$PATIENT_ID" || "$PATIENT_ID" == "" ]]; then
    echo "Error: No patient found for linking code: $LINKING_CODE"
    echo "Use --list to see connected patients."
    exit 1
  fi
  echo "Found patient: $PATIENT_ID (from code: $LINKING_CODE)"
elif [[ -z "$PATIENT_ID" ]]; then
  echo "Error: Provide --code <linking_code> or --patient <patient_id>"
  echo "       Use --list to see connected patients, or --help for usage."
  exit 1
fi

# Verify patient exists
EXISTS=$($PSQL -tAc "SELECT COUNT(*) FROM patients WHERE patient_id = '$PATIENT_ID';")
if [[ "$EXISTS" -eq 0 ]]; then
  echo "Error: Patient '$PATIENT_ID' not found in database."
  echo "Use --list to see available patients."
  exit 1
fi

# Validate questionnaire type
case "$QUESTIONNAIRE_TYPE" in
  nose_hht|qol|eq) ;;
  *)
    echo "Error: Invalid type '$QUESTIONNAIRE_TYPE'. Must be one of: nose_hht, qol, eq"
    exit 1
    ;;
esac

# Insert the questionnaire instance with status='sent'
INSTANCE_ID=$($PSQL -tAc "
  INSERT INTO questionnaire_instances (
    patient_id, questionnaire_type, status, study_event, version, sent_at
  ) VALUES (
    '$PATIENT_ID', '$QUESTIONNAIRE_TYPE', 'sent', '$STUDY_EVENT', '$VERSION', now()
  )
  RETURNING id;
")

echo ""
echo "=== Questionnaire task created ==="
echo "  Instance ID:  $INSTANCE_ID"
echo "  Patient:      $PATIENT_ID"
echo "  Type:         $QUESTIONNAIRE_TYPE"
echo "  Study event:  $STUDY_EVENT"
echo "  Status:       sent"
echo ""
echo "The mobile app will show this task on next sync."
echo "Sync triggers: app start, resume from background, or pull-to-refresh."

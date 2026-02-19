#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-CAL-p00081: Patient Task System
#   REQ-d00006: Mobile App Build and Release Process
#
# Insert a test questionnaire task for a patient in the local database.
# The mobile app will discover this task on next sync (app start or resume).
#
# Usage:
#   doppler run -- ./tool/send_test_task.sh --code CAXXXXXXXX
#   doppler run -- ./tool/send_test_task.sh --patient 840-001-001
#   doppler run -- ./tool/send_test_task.sh --list
#   doppler run -- ./tool/send_test_task.sh --code CAXXXXXXXX --type eq
#
# Options:
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

# Database connection (matches docker-compose.db.yml / dev-env defaults)
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-sponsor_portal}"
DB_USER="${DB_USER:-postgres}"

# Map password from Doppler or environment to PGPASSWORD
if [[ -z "${PGPASSWORD:-}" ]]; then
  if [[ -n "${DB_PASSWORD:-}" ]]; then
    export PGPASSWORD="$DB_PASSWORD"
  elif [[ -n "${LOCAL_DB_ROOT_PASSWORD:-}" ]]; then
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

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
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

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

# Check psql is available
if ! command -v psql &>/dev/null; then
  echo "Error: psql not found. Install PostgreSQL client tools."
  exit 1
fi

# Check DB is reachable
if ! $PSQL -c "SELECT 1" &>/dev/null; then
  echo "Error: Cannot connect to database at $DB_HOST:$DB_PORT/$DB_NAME"
  echo "Is PostgreSQL running? (start with: ./tool/run_local.sh)"
  echo "If using Doppler: doppler run -- $0 $*"
  exit 1
fi

# --- List mode ---
if $LIST_MODE; then
  echo "=== Connected patients ==="
  echo ""
  $PSQL --no-align --tuples-only --field-separator ' | ' -c "
    SELECT
      p.patient_id AS patient,
      p.mobile_linking_status AS status,
      COALESCE(plc.code, '(no code)') AS linking_code,
      (SELECT COUNT(*) FROM questionnaire_instances qi
       WHERE qi.patient_id = p.patient_id AND qi.deleted_at IS NULL) AS tasks
    FROM patients p
    LEFT JOIN patient_linking_codes plc
      ON p.patient_id = plc.patient_id AND plc.used_at IS NOT NULL
    ORDER BY p.patient_id;
  " | while IFS='|' read -r pid status code tasks; do
    printf "  %-20s  %-16s  code: %-14s  tasks: %s\n" "$pid" "$status" "$code" "$tasks"
  done
  echo ""
  echo "Use: $0 --patient <patient_id> [--type nose_hht|qol|eq]"
  exit 0
fi

# --- Resolve patient_id ---
if [[ -n "$LINKING_CODE" ]]; then
  # Strip dashes, whitespace, and uppercase for code lookup
  CLEAN_CODE=$(echo "$LINKING_CODE" | tr -d '- ' | tr '[:lower:]' '[:upper:]')
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

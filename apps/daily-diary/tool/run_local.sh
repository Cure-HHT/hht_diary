#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-CAL-p00081: Patient Task System
#   REQ-d00006: Mobile App Build and Release Process
#
# Run the mobile app with a local diary server for development.
#
# This script:
#   1. Starts local PostgreSQL (if not running)
#   2. Starts the diary server locally (background)
#   3. Launches the mobile app pointing to the local server
#
# Prerequisites:
#   - Docker running (for PostgreSQL)
#   - Doppler configured (for secrets)
#   - Flutter installed
#
# Usage:
#   ./tool/run_local.sh          # Android (physical or emulator, uses adb reverse)
#   ./tool/run_local.sh --web    # Chrome/web (uses localhost)
#   ./tool/run_local.sh --ios    # iOS simulator (uses localhost)
#
# To insert a test questionnaire task after the app is linked:
#   psql -h localhost -U app_user -d hht_diary -c "
#     INSERT INTO questionnaire_instances (
#       patient_id, questionnaire_type, status, study_event, version, sent_at
#     ) VALUES (
#       '<your-patient-id>', 'nose_hht', 'sent', 'screening', 1, now()
#     );
#   "

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DIARY_SERVER="$REPO_ROOT/apps/daily-diary/diary_server"
CLINICAL_DIARY="$REPO_ROOT/apps/daily-diary/clinical_diary"
DEV_ENV="$REPO_ROOT/tools/dev-env"
DEVICE=""
# All platforms use localhost. For Android (physical device or emulator),
# adb reverse forwards the device's localhost:8080 to the host machine.
BACKEND_URL="http://localhost:8080"
USE_ADB_REVERSE=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --web) DEVICE="chrome"; USE_ADB_REVERSE=false; shift ;;
    --ios) USE_ADB_REVERSE=false; shift ;;
    --device) DEVICE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== Local Development Environment ==="
echo ""

# 1. Start PostgreSQL if not running
if docker ps --filter "name=sponsor-portal-postgres" --format '{{.Names}}' | grep -q sponsor-portal-postgres; then
  echo "[DB] PostgreSQL already running"
else
  echo "[DB] Starting PostgreSQL..."
  (cd "$DEV_ENV" && doppler run -- docker compose -f docker-compose.db.yml up -d)
  echo "[DB] Waiting for PostgreSQL to be healthy..."
  sleep 5
fi

# 2. Start diary server in background
echo "[SERVER] Starting diary server on :8080..."
(cd "$DIARY_SERVER" && doppler run -- ./tool/run_local.sh) &
DIARY_PID=$!
echo "[SERVER] Diary server PID: $DIARY_PID"

# Wait for server to be ready
sleep 3

# 3. Set up adb reverse for Android (physical device or emulator)
#    Applies to ALL connected Android devices so both physical and emulator work.
if $USE_ADB_REVERSE; then
  echo "[ADB] Setting up port forwarding (localhost:8080 → host:8080)..."
  for serial in $(adb devices | awk 'NR>1 && $2=="device" {print $1}'); do
    adb -s "$serial" reverse tcp:8080 tcp:8080 2>/dev/null \
      && echo "[ADB]   ✓ $serial" \
      || echo "[ADB]   ✗ $serial (failed)"
  done
fi

# 4. Launch mobile app pointing to local server
echo "[APP] Launching mobile app with local backend..."

CMD="flutter run --dart-define=APP_FLAVOR=local --dart-define=BACKEND_URL=$BACKEND_URL"

if [[ -n "$DEVICE" ]]; then
  CMD="$CMD -d $DEVICE"
  if [[ "$DEVICE" != "chrome" ]]; then
    CMD="$CMD --flavor dev"
  fi
else
  CMD="$CMD --flavor dev"
fi

echo "[APP] Command: $CMD"
echo ""

# Cleanup diary server on exit
cleanup() {
  echo ""
  echo "[CLEANUP] Stopping diary server (PID: $DIARY_PID)..."
  kill $DIARY_PID 2>/dev/null || true
}
trap cleanup EXIT

(cd "$CLINICAL_DIARY" && $CMD)

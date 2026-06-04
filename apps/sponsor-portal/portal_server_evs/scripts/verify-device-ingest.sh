#!/usr/bin/env bash
# Verify that diary entries recorded on a real device have been ingested into the
# local throwaway Postgres behind portal_server_evs. This is the DETERMINISTIC
# half of the hybrid Android device test (see docs/e2e/android-device-runbook.md):
# a human records entries on the device by hand, then this script confirms the
# expected diary event types landed in the event store and materialized into the
# canonical diary_entries view.
#
# Verifies: DIARY-DEV-participant-ingest/C — device-authored entries reach the
#   receiving node's event log + projection.
#
# Usage:
#   verify-device-ingest.sh <participantId> [expected_entry_type ...]
#
#   participantId        e.g. P-SELF (the id the device linked to)
#   expected_entry_type  defaults to: epistaxis_event no_epistaxis_event
#                        unknown_day_event   (pass your own list to override,
#                        e.g. add a survey id like phq9_survey)
set -euo pipefail

PARTICIPANT_ID="${1:-}"
if [[ -z "$PARTICIPANT_ID" ]]; then
  echo "usage: $0 <participantId> [expected_entry_type ...]" >&2
  exit 2
fi
shift || true
EXPECTED=("$@")
if [[ ${#EXPECTED[@]} -eq 0 ]]; then
  EXPECTED=(epistaxis_event no_epistaxis_event unknown_day_event)
fi

# Same fixed LOCAL throwaway values as run-link-e2e.sh — never inherited from the
# ambient env (which may point at a real database).
PG_CONTAINER="evs-pg"
DB_USER="postgres"
DB_NAME="hht_diary"

psql() { docker exec "$PG_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -tA "$@"; }

echo "==> Diary events ingested into the event log (entry_type | aggregate_id):"
psql -c "
  SELECT entry_type || '  |  ' || aggregate_id
  FROM events
  WHERE entry_type LIKE '%epistaxis%'
     OR entry_type LIKE '%unknown_day%'
     OR entry_type LIKE '%_survey'
  ORDER BY entry_type;" || {
    echo "!! could not query Postgres ($PG_CONTAINER/$DB_NAME). Is the local stack up?" >&2
    exit 1
  }

echo
echo "==> Materialized rows in the canonical diary_entries view:"
psql -c "SELECT row_key FROM view_rows WHERE view_name = 'diary_entries' ORDER BY row_key;"

echo
echo "==> Checking expected entry types for participant '$PARTICIPANT_ID':"
status=0
for et in "${EXPECTED[@]}"; do
  count="$(psql -c "SELECT count(*) FROM events WHERE entry_type = '$et';")"
  if [[ "${count:-0}" -gt 0 ]]; then
    echo "    PASS  $et  (${count} event(s))"
  else
    echo "    MISS  $et  (no events ingested)"
    status=1
  fi
done

echo
if [[ $status -eq 0 ]]; then
  echo "RESULT: PASS — all expected entry types were ingested."
else
  echo "RESULT: INCOMPLETE — one or more expected entry types are missing (see MISS above)."
fi
exit $status

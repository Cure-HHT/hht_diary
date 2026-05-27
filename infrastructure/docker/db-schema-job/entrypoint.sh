#!/bin/bash
# infrastructure/docker/db-schema-job/entrypoint.sh
# For one sponsor, this deploys the database schema to Cloud SQL from a GCS bucket.
# Entrypoint script for database schema deployment job
# Downloads schema from GCS and applies to Cloud SQL
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00057: Automated database schema deployment
#   REQ-p00042: Infrastructure audit trail for FDA compliance
#   REQ-d00031: Identity Platform Integration (user seeding)
#   REQ-d00058: Secrets Management via Doppler

set -euo pipefail

# -----------------------------------------------------------------------------
# Logging (defined early so Doppler bootstrap can use it)
# -----------------------------------------------------------------------------

log() {
    local level="$1"
    shift
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [$level] $*"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# -----------------------------------------------------------------------------
# Doppler Bootstrap
# Fetches DOPPLER_TOKEN from Secret Manager and re-execs with doppler run
# to inject all secrets (DB_HOST, DB_PASSWORD, DEFAULT_USER_PWD, etc.)
# If DOPPLER_PROJECT_ID is not set, falls back to explicit env vars.
# -----------------------------------------------------------------------------

if [ -n "${DOPPLER_PROJECT_ID:-}" ] && [ -z "${_DOPPLER_INJECTED:-}" ]; then
    : "${DOPPLER_CONFIG_NAME:?DOPPLER_CONFIG_NAME is required when DOPPLER_PROJECT_ID is set}"

    log_info "Doppler Project: ${DOPPLER_PROJECT_ID}"
    log_info "Doppler Config:  ${DOPPLER_CONFIG_NAME}"

    log_info "Fetching DOPPLER_TOKEN from Secret Manager..."
    DOPPLER_TOKEN="$(gcloud secrets versions access latest --secret=DOPPLER_TOKEN 2>&1)" || true
    if [ -z "$DOPPLER_TOKEN" ]; then
        log_error "Failed to fetch DOPPLER_TOKEN from Secret Manager"
        log_error "Ensure the service account has secretmanager.versions.access permission"
        exit 1
    fi
    export DOPPLER_TOKEN
    log_info "DOPPLER_TOKEN fetched (length: ${#DOPPLER_TOKEN} chars)"

    export _DOPPLER_INJECTED=1
    log_info "Re-executing with Doppler-injected secrets..."
    exec doppler run --project "${DOPPLER_PROJECT_ID}" --config "${DOPPLER_CONFIG_NAME}" -- "$0" "$@"
fi

# -----------------------------------------------------------------------------
# Configuration
# After Doppler injection, DB_* vars are available as env vars from Doppler.
# Without Doppler, they must be passed as explicit Cloud Run env vars.
# -----------------------------------------------------------------------------

# Required environment variables (from Doppler or explicit)
: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:=5432}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${SCHEMA_BUCKET:?SCHEMA_BUCKET is required}"
: "${SCHEMA_PREFIX:=db-schema}"
: "${SCHEMA_FILE:=init-consolidated.sql}"
: "${SPONSOR_DATA_FILE:=seed_data_dev.sql}"
: "${SPONSOR:?SPONSOR is required}"
: "${ENVIRONMENT:?ENVIRONMENT is required}"

# Optional environment variables (from Doppler or explicit)
: "${DEFAULT_USER_PWD:=}"

# Optional settings
SKIP_IF_TABLES_EXIST="${SKIP_IF_TABLES_EXIST:-true}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
# migrate (default): apply pending migrations/NNN to the live DB.
# reset: drop + reapply the consolidated baseline + seed (manual, never prod).
MODE="${MODE:-migrate}"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-/app/migrations}"

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

# Implements: DIARY-OPS-db-reset-non-prod/A+B
reset_database() {
    if [[ "${ENVIRONMENT,,}" == "prod" ]]; then
        log_error "MODE=reset is not permitted on prod (drop + reapply destroys data)."
        log_error "Prod schema changes go through MODE=migrate only."
        exit 10
    fi
    log_info "MODE=reset: drop + reapply consolidated baseline (${ENVIRONMENT})"
    log_info "Starting database schema deployment"
    log_info "Sponsor: ${SPONSOR}, Environment: ${ENVIRONMENT}"
    log_info "Database: ${DB_NAME} on ${DB_HOST}:${DB_PORT}"
    log_info "Running as: $(gcloud auth list) 2>&1" # --filter=status:ACTIVE --format='value(account)' 2>/dev/null || echo 'unknown')"


    # Obtain the consolidated baseline.
    # Prefer the baked-in baseline (built into the image at build time) so
    # reset uses a versioned, auditable artifact instead of a mutable bucket
    # object. Fall back to gsutil only when the baked file is absent (e.g.
    # older images that pre-date this change).
    # Implements: DIARY-OPS-db-reset-non-prod/C
    local baked_baseline="/app/baseline/init-consolidated.sql"
    if [[ -f "${baked_baseline}" ]]; then
        log_info "Using baked-in baseline from image: ${baked_baseline}"
        cp "${baked_baseline}" /tmp/${SCHEMA_FILE}
    else
        log_warn "Baked baseline not found — falling back to GCS download (pre-CUR-1320 image)"
        log_info "Downloading schema from ${SCHEMA_BUCKET}/${SCHEMA_PREFIX}/${SCHEMA_FILE}"
        gsutil cp "${SCHEMA_BUCKET}/${SCHEMA_PREFIX}/${SCHEMA_FILE}" /tmp/${SCHEMA_FILE}
    fi

    if [[ ! -f /tmp/${SCHEMA_FILE} ]]; then
        log_error "Failed to obtain schema file (baked baseline missing and GCS download failed)."
        exit 1
    fi

    local schema_size
    schema_size=$(wc -c < /tmp/${SCHEMA_FILE})
    log_info "Schema file obtained: ${schema_size} bytes."

    # Download seed data file from GCS
    log_info "Downloading seed data from ${SCHEMA_BUCKET}/${SCHEMA_PREFIX}/${SPONSOR_DATA_FILE}"
    if gsutil cp "${SCHEMA_BUCKET}/${SCHEMA_PREFIX}/${SPONSOR_DATA_FILE}" "/tmp/${SPONSOR_DATA_FILE}" 2>/dev/null; then
        local seed_size
        seed_size=$(wc -c < "/tmp/${SPONSOR_DATA_FILE}")
        log_info "Seed data file downloaded: ${seed_size} bytes."
    else
        log_warn "Seed data file not found or failed to download - skipping seed data initialization"
    fi

    export PGDATABASE="${DB_NAME}"
    export PGUSER="${DB_USER}"
    export PGPASSWORD="${DB_PASSWORD}"

    env | grep PG > /tmp/env_vars.txt 2>&1
    log_info "ENVIRONMENT VARIABLES: $(cat /tmp/env_vars.txt)"

    # DROP database if it exists
    log_info "Checking if database ${DB_NAME} exists..."
    if psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1; then
        log_info "Database ${DB_NAME} exists, terminating active connections..."
        psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();"
        log_info "Dropping database ${DB_NAME}..."
        psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "DROP DATABASE \"${DB_NAME}\""
        log_info "Database ${DB_NAME} dropped"
    else
        log_warn "Database ${DB_NAME} does not exist, skipping drop"
    fi

    # CREATE database
    log_info "Creating database ${DB_NAME}..."
    if ! psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE \"${DB_NAME}\""; then
        log_error "Failed to create database ${DB_NAME}"
        exit 2
    fi
    log_info "Database ${DB_NAME} created"

    # Apply schema
    log_info "Applying database schema..."
    local start_time
    start_time=$(date +%s)

    psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -f /tmp/${SCHEMA_FILE} 2>&1 | tee /tmp/schema_output.log
    local psql_status=$?
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    if [ $psql_status -ne 0 ]; then
        log_error "Schema application failed after ${duration} seconds"
        log_error "Last 50 lines of output:"
        tail -50 /tmp/schema_output.log
        exit 3
    fi
    log_info "Schema applied successfully in ${duration} seconds"
    # log_info "Schema execution: $(cat /tmp/schema_output.log)"

    # Initialize Data (seed data must be applied after schema creates tables)
    if [[ -f "/tmp/${SPONSOR_DATA_FILE}" ]]; then
        log_info "Applying seed data..."
        local seed_start_time
        seed_start_time=$(date +%s)

        if psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -f "/tmp/${SPONSOR_DATA_FILE}" 2>&1 | tee /tmp/seed_output.log; then
            local seed_end_time seed_duration
            seed_end_time=$(date +%s)
            seed_duration=$((seed_end_time - seed_start_time))
            log_info "Seed data applied successfully in ${seed_duration} seconds"
        else
            log_error "Seed data application failed: $(tail -20 /tmp/seed_output.log)"
            exit 4
        fi
    else
        log_info "No seed data file found - skipping data initialization"
    fi

    # Verify schema application
    log_info "Verifying schema application..."
    local verification_query="
    SELECT
        (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public') as table_count,
        (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public') as index_count,
        (SELECT COUNT(*) FROM pg_trigger WHERE NOT tgisinternal) as trigger_count,
        (SELECT COUNT(*) FROM pg_policies) as policy_count
    "

    log_info "Schema verification: $(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "${verification_query}")"

    # -------------------------------------------------------------------------
    # Reset Identity Platform users (optional - requires RESET_IDS=true)
    # 1. Batch-delete all existing users via Firebase Admin SDK
    # 2. Re-seed users from portal_users table via seed_identity_users.js
    #
    # Both steps use the same Node.js script and Firebase Admin SDK — the
    # raw Identity Toolkit REST API returns 0 users for projects created via
    # Identity Platform (vs. Firebase), so the Admin SDK is the reliable path.
    # -------------------------------------------------------------------------
    if [[ "${RESET_IDS:-false}" == "true" ]]; then
        local id_project="${SPONSOR}-${ENVIRONMENT}"
        log_info "Resetting Identity Platform users for project: ${id_project}"

        # --- Step 1: Delete all existing users via Firebase Admin SDK ---
        log_info "Deleting all existing Identity Platform users..."
        if node /app/seed_identity_users.js \
            --project="${SPONSOR}" \
            --env="${ENVIRONMENT}" \
            --delete-all; then
            log_info "Identity Platform users deleted successfully"
        else
            log_warn "Identity Platform user deletion failed (non-fatal)"
        fi

        # --- Step 2: Re-seed users from portal_users table ---
        if [[ -n "${DEFAULT_USER_PWD}" ]]; then
            log_info "Seeding Identity Platform users..."

            # Extract comma-separated emails and names from portal_users table
            local user_emails
            user_emails=$(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
                "SELECT string_agg(email, ',') FROM portal_users")

            local user_names
            user_names=$(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
                "SELECT string_agg(name, ',') FROM portal_users")

            if [[ -n "${user_emails}" ]]; then
                log_info "Found portal users to seed: ${user_emails}"

                # CUR-1296 (REQ-d00170-A,B): tee stdout so we can pluck the
                # email->uid map seed_identity_users.js emits between the
                # ---SEED_IDENTITY_USERS_MAP_BEGIN--- / END markers, then
                # stamp portal_users.firebase_uid from it. Without this
                # step, portal_users.firebase_uid stays NULL after a reset
                # and uid-only auth (post CUR-1296 / REQ-d00167) returns
                # 401 uid_not_bound for every login attempt. The local-stack
                # db-schema-job has had this stamping step since CUR-1296;
                # this is the prod port (omitted at the time, surfaced by
                # the first full UAT reset on 2026-05-10).
                local seed_log=/tmp/seed_identity_users.log
                if node /app/seed_identity_users.js \
                    --project="${SPONSOR}" \
                    --env="${ENVIRONMENT}" \
                    --password="${DEFAULT_USER_PWD}" \
                    --users="${user_emails}" \
                    --user-names="${user_names}" 2>&1 | tee "${seed_log}"; then
                    log_info "Identity Platform users seeded successfully"
                else
                    log_warn "Identity Platform user seeding failed (non-fatal)"
                fi

                local seed_map
                seed_map=$(awk '/---SEED_IDENTITY_USERS_MAP_BEGIN---/,/---SEED_IDENTITY_USERS_MAP_END---/' \
                              "${seed_log}" \
                           | grep -v 'SEED_IDENTITY_USERS_MAP' || true)

                if [[ -z "${seed_map}" || "${seed_map}" == "[]" ]]; then
                    log_warn "No email->uid map emitted; portal_users.firebase_uid will stay NULL (login will fail with uid_not_bound)"
                else
                    # Parse + validate the map up front. Process substitution
                    # (done < <(... | jq ...)) swallows jq's exit code even
                    # under `set -e`, so a malformed map would silently produce
                    # a zero-iteration loop and quietly leave firebase_uid NULL
                    # — defeating the whole stamping step. Capture with explicit
                    # error handling instead and iterate via a here-string.
                    local parsed_rows
                    if ! parsed_rows=$(echo "${seed_map}" | jq -c '.[]' 2>/tmp/jq_err); then
                        log_error "Failed to parse email->uid map as JSON: $(cat /tmp/jq_err 2>/dev/null || echo '?')"
                        log_error "Raw seed_map: ${seed_map}"
                        exit 5
                    fi

                    log_info "Stamping portal_users.firebase_uid from seed map"
                    local attempted=0 updated=0
                    while IFS= read -r row; do
                        local row_email row_uid hit
                        row_email=$(echo "${row}" | jq -r '.email')
                        row_uid=$(echo "${row}" | jq -r '.uid')
                        # psql -c does NOT expand :'name' substitutions
                        # (client-side parser feature); feed via stdin so
                        # psql substitutes before sending to the server.
                        # `RETURNING 1` distinguishes "row updated" from
                        # "no matching email" — a seed map entry may not
                        # have a corresponding portal_users row.
                        hit=$(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" \
                                   -tA -v ON_ERROR_STOP=1 \
                                   -v email="${row_email}" -v uid="${row_uid}" <<'EOF'
UPDATE portal_users SET firebase_uid = :'uid' WHERE LOWER(email) = LOWER(:'email') RETURNING 1;
EOF
                        )
                        attempted=$((attempted + 1))
                        if [[ -n "${hit}" ]]; then
                            updated=$((updated + 1))
                        fi
                    done <<< "${parsed_rows}"
                    log_info "Stamped firebase_uid on ${updated}/${attempted} portal_users rows from seed map"
                fi
            else
                log_warn "No portal users found in database - skipping Identity Platform seeding"
            fi
        else
            log_info "DEFAULT_USER_PWD not set - skipping Identity Platform user seeding (delete-only reset)"
        fi
    else
        log_info "RESET_IDS not set - skipping Identity Platform reset"
    fi

    log_info "Stamping all present migrations as applied (post-reset)..."
    stamp_all_present

    # Log completion
    log_info "=========================================="
    log_info "Database schema deployment COMPLETE"
    log_info "Sponsor: ${SPONSOR}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Database: ${DB_NAME}"
    log_info "Execution time: ${duration} seconds"
    log_info "=========================================="

    exit 0
}

# List migration files in MIGRATIONS_DIR, sorted by numeric id. Echoes "<id> <path>".
list_migrations() {
    local f base num
    for f in "${MIGRATIONS_DIR}"/[0-9]*.sql; do
        [[ -e "$f" ]] || continue
        base=$(basename "$f")
        num=$(echo "$base" | grep -oE '^[0-9]+' | sed 's/^0*//')
        echo "${num:-0} ${f}"
    done | sort -n
}

# Stamp every present migration as applied WITHOUT running it (used after a reset,
# where the consolidated baseline already contains all of them).
stamp_all_present() {
    local num path base
    while read -r num path; do
        base=$(basename "$path")
        # num is digits-only (safe to interpolate). base is passed via -v so
        # psql performs :'mname' substitution — feed via stdin because psql -c
        # disables variable interpolation; stdin mode preserves it.
        psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 \
            -v mname="${base}" \
            <<< "INSERT INTO schema_migrations (id, name) VALUES (${num}, :'mname') ON CONFLICT (id) DO NOTHING;"
    done < <(list_migrations)
}

# Implements: DIARY-OPS-schema-migrate-on-deploy/A+C
migrate_database() {
    export PGDATABASE="${DB_NAME}" PGUSER="${DB_USER}" PGPASSWORD="${DB_PASSWORD}"
    log_info "MODE=migrate: applying pending migrations (${ENVIRONMENT})"

    # Concurrency is provided by the deploy workflow's per-env concurrency group
    # (only one migrate job per environment runs at a time). A DB-level advisory
    # lock would require single-session execution, which conflicts with applying
    # CONCURRENTLY-index migrations per-file; not warranted at this phase. If
    # migrate is ever run OUTSIDE that workflow, the operator must ensure no
    # concurrent run against the same database.

    local applied_max
    applied_max=$(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
        "SELECT COALESCE(MAX(id), 0) FROM schema_migrations")
    log_info "Current schema version: ${applied_max}"

    local num path base applied=0
    # NOTE: if the job crashes between applying a migration and stamping it,
    # the migration re-runs on the next deploy — so migrations MUST be
    # written to be re-runnable (IF NOT EXISTS / guarded). Migrations that
    # add named constraints without IF NOT EXISTS are NOT safe to retry.
    while read -r num path; do
        [[ "${num}" -le "${applied_max}" ]] && continue
        base=$(basename "$path")
        log_info "Applying migration ${num}: ${base}"
        if ! psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -f "${path}"; then
            log_error "Migration ${num} (${base}) failed."
            exit 3
        fi
        # num is digits-only (safe to interpolate). base is passed via -v so
        # psql performs :'mname' substitution — feed via stdin because psql -c
        # disables variable interpolation; stdin mode preserves it.
        psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 \
            -v mname="${base}" \
            <<< "INSERT INTO schema_migrations (id, name) VALUES (${num}, :'mname') ON CONFLICT (id) DO NOTHING;"
        applied=$((applied + 1))
    done < <(list_migrations)

    log_info "MODE=migrate complete: ${applied} migration(s) applied; version now $(
        psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -tAc "SELECT COALESCE(MAX(id),0) FROM schema_migrations")"
    exit 0
}

# Only dispatch when executed directly, not when sourced (tests source this file).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${MODE}" in
        migrate) migrate_database "$@" ;;
        reset)   reset_database "$@" ;;
        *)       log_error "Unknown MODE='${MODE}' (expected 'migrate' or 'reset')"; exit 11 ;;
    esac
fi

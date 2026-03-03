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

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    log_info "Starting database schema deployment"
    log_info "Sponsor: ${SPONSOR}, Environment: ${ENVIRONMENT}"
    log_info "Database: ${DB_NAME} on ${DB_HOST}:${DB_PORT}"
    log_info "Running as: $(gcloud auth list) 2>&1" # --filter=status:ACTIVE --format='value(account)' 2>/dev/null || echo 'unknown')"


    # Download schema file from GCS
    log_info "Downloading schema from ${SCHEMA_BUCKET}/${SCHEMA_PREFIX}/${SCHEMA_FILE}"
    gsutil cp "${SCHEMA_BUCKET}/${SCHEMA_PREFIX}/${SCHEMA_FILE}" /tmp/${SCHEMA_FILE}

    if [[ ! -f /tmp/${SCHEMA_FILE} ]]; then
        log_error "Failed to download schema file."
        exit 1
    fi

    local schema_size
    schema_size=$(wc -c < /tmp/${SCHEMA_FILE})
    log_info "Schema file downloaded: ${schema_size} bytes."

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
        log_info "Database ${DB_NAME} exists, dropping..."
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
    # 1. Batch-delete all existing users via Identity Toolkit REST API
    # 2. Re-seed users from portal_users table via seed_identity_users.js
    # -------------------------------------------------------------------------
    if [[ "${RESET_IDS:-false}" == "true" ]]; then
        local id_project="${SPONSOR}-${ENVIRONMENT}"
        log_info "Resetting Identity Platform users for project: ${id_project}"

        # Get access token for Identity Toolkit API calls
        local access_token
        access_token=$(gcloud auth print-access-token 2>/dev/null)
        if [[ -z "${access_token}" ]]; then
            log_warn "Failed to obtain access token - skipping Identity Platform reset"
        else
            # --- Step 1: Batch-delete existing users ---
            log_info "Looking up existing Identity Platform users..."
            local api_base="https://identitytoolkit.googleapis.com/v1/projects/${id_project}"
            local all_local_ids=()
            local next_page_token=""

            # Paginate through all users via accounts:batchGet
            while true; do
                local batch_url="${api_base}/accounts:batchGet?maxResults=1000"
                if [[ -n "${next_page_token}" ]]; then
                    batch_url="${batch_url}&nextPageToken=${next_page_token}"
                fi

                local response
                response=$(curl -sf -H "Authorization: Bearer ${access_token}" \
                    -H "Content-Type: application/json" \
                    "${batch_url}" 2>/dev/null) || true

                if [[ -z "${response}" ]]; then
                    log_warn "Empty response from accounts:batchGet - may have no users"
                    break
                fi

                # Extract localIds from response
                local page_ids
                page_ids=$(echo "${response}" | jq -r '.users[]?.localId // empty' 2>/dev/null)
                if [[ -n "${page_ids}" ]]; then
                    while IFS= read -r uid; do
                        all_local_ids+=("${uid}")
                    done <<< "${page_ids}"
                fi

                # Check for next page
                next_page_token=$(echo "${response}" | jq -r '.nextPageToken // empty' 2>/dev/null)
                if [[ -z "${next_page_token}" ]]; then
                    break
                fi
            done

            local user_count=${#all_local_ids[@]}
            log_info "Found ${user_count} existing Identity Platform users"

            if [[ ${user_count} -gt 0 ]]; then
                log_info "Batch-deleting ${user_count} users..."

                # Build JSON array of localIds for batchDelete
                local ids_json
                ids_json=$(printf '%s\n' "${all_local_ids[@]}" | jq -R . | jq -s '.')

                local delete_response
                delete_response=$(curl -sf -X POST \
                    -H "Authorization: Bearer ${access_token}" \
                    -H "Content-Type: application/json" \
                    -d "{\"localIds\": ${ids_json}, \"force\": true}" \
                    "${api_base}/accounts:batchDelete" 2>/dev/null) || true

                # Check for errors in the response
                local error_count
                error_count=$(echo "${delete_response}" | jq -r '.errors | length // 0' 2>/dev/null)
                if [[ "${error_count}" -gt 0 ]]; then
                    log_warn "Batch delete completed with ${error_count} errors"
                    log_warn "Details: $(echo "${delete_response}" | jq -c '.errors' 2>/dev/null)"
                else
                    log_info "Batch-deleted ${user_count} Identity Platform users"
                fi
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

                    if node /app/seed_identity_users.js \
                        --project="${SPONSOR}" \
                        --env="${ENVIRONMENT}" \
                        --password="${DEFAULT_USER_PWD}" \
                        --users="${user_emails}" \
                        --user-names="${user_names}"; then
                        log_info "Identity Platform users seeded successfully"
                    else
                        log_warn "Identity Platform user seeding failed (non-fatal)"
                    fi
                else
                    log_warn "No portal users found in database - skipping Identity Platform seeding"
                fi
            else
                log_info "DEFAULT_USER_PWD not set - skipping Identity Platform user seeding (delete-only reset)"
            fi
        fi
    else
        log_info "RESET_IDS not set - skipping Identity Platform reset"
    fi

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

# Run main function
main "$@"

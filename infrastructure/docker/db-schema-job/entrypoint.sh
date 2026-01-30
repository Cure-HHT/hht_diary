#!/bin/bash
# infrastructure/docker/db-schema-job/entrypoint.sh
# For one sponsor, this deploys the database schema to Cloud SQL from a GCS bucket.
# Entrypoint script for database schema deployment job
# Downloads schema from GCS and applies to Cloud SQL
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00057: Automated database schema deployment
#   REQ-p00042: Infrastructure audit trail for FDA compliance

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Required environment variables
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

# Optional settings
SKIP_IF_TABLES_EXIST="${SKIP_IF_TABLES_EXIST:-true}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# -----------------------------------------------------------------------------
# Logging
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

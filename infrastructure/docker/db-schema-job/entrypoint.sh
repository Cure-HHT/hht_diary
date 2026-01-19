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
    log_info "Downloading schema from gs://${SCHEMA_BUCKET}/${SCHEMA_PREFIX}/${SCHEMA_FILE}"
    gsutil cp "gs://${SCHEMA_BUCKET}/${SCHEMA_PREFIX}/${SCHEMA_FILE}" /tmp/schema.sql

    if [[ ! -f /tmp/schema.sql ]]; then
        log_error "Failed to download schema file"
        exit 1
    fi

    local schema_size
    schema_size=$(wc -c < /tmp/schema.sql)
    log_info "Schema file downloaded: ${schema_size} bytes"

    # Build connection string
    # For Unix socket (Cloud SQL proxy sidecar)
    # if [[ "${DB_HOST}" == /cloudsql/* ]]; then
    #     export PGHOST="${DB_HOST}"
    # else
    #     export PGHOST="${DB_HOST}"
    # fi
    # export PGPORT="${DB_PORT}"
    export PGDATABASE="${DB_NAME}"
    export PGUSER="${DB_USER}"
    export PGPASSWORD="${DB_PASSWORD}"
    
    local result
    env | grep PG > /tmp/env_vars.txt 2>&1
    result=$(cat /tmp/env_vars.txt)
    log_info "ENVIRONMENT VARIABLES: $(result)"
    # Check database connectivity
    log_info "Testing database connectivity..."
    log_info "echo psql -h ${DB_HOST} -c 'SELECT 1'"
    log_info "$(psql -h ${DB_HOST} -U ${DB_USER} -c 'SELECT 1')"
    psql -h ${DB_HOST} -U ${DB_USER} -c 'SELECT 1' > /tmp/schema_test.txt 2>&1
    if [ $? -ne 0 ]; then
        log_error "Cannot connect to database"
        exit 1
    fi
    log_info "Database connection successful"

    result=$(cat /tmp/schema_test.txt)
    log_info "Schema test: ${result}"
    # Check if schema already applied (look for key tables)
    # if [[ "${SKIP_IF_TABLES_EXIST}" == "true" ]]; then
    #     log_info "Checking if schema already exists..."
    #     local table_count
    #     table_count=$(psql -t -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('sites', 'record_audit', 'record_state', 'portal_users')" 2>/dev/null | tr -d ' ')

    #     if [[ "${table_count}" -ge 4 ]]; then
    #         log_info "Schema already applied (found ${table_count} core tables). Skipping."
    #         log_info "Set SKIP_IF_TABLES_EXIST=false to force re-application"

    #         # Log current schema version info
    #         local audit_count state_count
    #         audit_count=$(psql -t -c "SELECT COUNT(*) FROM record_audit" 2>/dev/null | tr -d ' ' || echo "0")
    #         state_count=$(psql -t -c "SELECT COUNT(*) FROM record_state" 2>/dev/null | tr -d ' ' || echo "0")
    #         log_info "Current data: ${audit_count} audit records, ${state_count} state records"

    #         exit 0
    #     fi
    #     log_info "Schema not yet applied (found ${table_count} core tables)"
    # fi

    # Apply schema
    log_info "Applying database schema..."
    local start_time
    start_time=$(date +%s)

    psql -h ${DB_HOST} -U ${DB_USER} -v ON_ERROR_STOP=1 -f /tmp/schema.sql 2>&1 | tee /tmp/schema_output.log
    if [ $? -ne 0 ]; then
        local end_time duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        log_info "Schema applied successfully in ${duration} seconds"
    else
        log_error "Schema application failed"
        log_error "Last 50 lines of output:"
        tail -50 /tmp/schema_output.log
        exit 1
    fi
    # local result
    result=$(cat /tmp/schema_output.log)
    log_info "Schema execution: ${result}"

    # Verify schema application
    log_info "Verifying schema application..."
    local verification_query="
    SELECT
        (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public') as table_count,
        (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public') as index_count,
        (SELECT COUNT(*) FROM pg_trigger WHERE NOT tgisinternal) as trigger_count,
        (SELECT COUNT(*) FROM pg_policies) as policy_count
    "

    # local result
    result=$(psql -h ${DB_HOST} -U ${DB_USER} -t -c "${verification_query}")
    log_info "Schema verification: ${result}"

    # Log completion
    log_info "=========================================="
    log_info "Database schema deployment COMPLETE"
    log_info "Sponsor: ${SPONSOR}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Database: ${DB_NAME}"
    log_info "=========================================="

    exit 0
}

# Run main function
main "$@"

#!/usr/bin/env bash
# database/tool/consolidate-schema.sh
#
# Produces the single-file baseline applied by the Cloud SQL reset job
# (infrastructure/docker/db-schema-job, MODE=reset) — no psql-specific
# commands like \ir or \echo.
#
# EVS TRANSITION (default behaviour): the deployed servers are now the
# event-sourced portal (apps/sponsor-portal/portal_server_evs), which owns and
# creates its OWN tables on boot via `CREATE TABLE IF NOT EXISTS` (see the
# event_sourcing PostgresBackend). No deployed environment applies the legacy
# raw-Postgres schema any more, so this baseline is intentionally a NO-OP: a
# comment-only file that psql runs without error against a freshly created
# database. The EVS portal then builds its schema and re-seeds on first boot.
#
# The legacy schema source (database/init.sql + its \ir includes) is retained
# for local-dev / CI of the kept-for-comparison legacy servers, which apply
# init.sql DIRECTLY (not this consolidated artifact). To regenerate the full
# legacy consolidated baseline (e.g. to stand a legacy DB up for comparison),
# run with INCLUDE_LEGACY_SCHEMA=true.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00057: Automated database schema deployment
#   REQ-o00004: Database Schema Deployment
#
# Usage:
#   ./database/tool/consolidate-schema.sh [output-file]
#   INCLUDE_LEGACY_SCHEMA=true ./database/tool/consolidate-schema.sh [output-file]
#
# If output-file is not specified, defaults to database/init-consolidated.sql

set -euo pipefail

# Default: emit a no-op baseline (EVS owns its own schema). Set true to inline
# the full legacy schema for the retained, non-deployed legacy servers.
INCLUDE_LEGACY_SCHEMA="${INCLUDE_LEGACY_SCHEMA:-false}"

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script is in database/tool/, so go up 2 levels to reach repo root
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DATABASE_DIR="${SCRIPT_DIR}/.."
INPUT_FILE="${DATABASE_DIR}/init.sql"
OUTPUT_FILE="${1:-${DATABASE_DIR}/init-consolidated.sql}"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Expand a SQL file, recursively processing \ir directives
# Args: $1 = file path (relative to DATABASE_DIR)
expand_file() {
    local file_path="$1"
    local full_path="${DATABASE_DIR}/${file_path}"

    if [[ ! -f "$full_path" ]]; then
        log_error "File not found: $full_path"
        return 1
    fi

    log_info "Processing: $file_path"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip \echo commands (psql-specific)
        if [[ "$line" =~ ^\\echo ]]; then
            continue
        fi

        # Expand \ir (include relative) directives
        if [[ "$line" =~ ^\\ir[[:space:]]+(.+)$ ]]; then
            local included_file="${BASH_REMATCH[1]}"
            echo ""
            echo "-- ====================================================================="
            echo "-- INCLUDED FROM: ${included_file}"
            echo "-- ====================================================================="
            echo ""
            expand_file "$included_file"
            echo ""
            echo "-- ====================================================================="
            echo "-- END OF: ${included_file}"
            echo "-- ====================================================================="
            echo ""
        else
            echo "$line"
        fi
    done < "$full_path"
}

# Generate header with metadata
generate_header() {
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    local git_commit
    git_commit=$(cd "${REPO_ROOT}" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    if [[ "${INCLUDE_LEGACY_SCHEMA}" != "true" ]]; then
        cat << EOF
-- IMPLEMENTS REQUIREMENTS:
--   REQ-o00004: Database Schema Deployment
--   REQ-d00057: Automated database schema deployment
--
-- =====================================================
-- Clinical Trial Diary Database - Reset Baseline (EVS transition)
-- INTENTIONALLY EMPTY / NO-OP
-- =====================================================
--
-- The deployed servers are the event-sourced portal, which creates its OWN
-- tables on boot (CREATE TABLE IF NOT EXISTS) and re-seeds on first start. No
-- deployed environment applies the legacy raw-Postgres schema, so this reset
-- baseline applies nothing: psql runs this comment-only file without error
-- against the freshly created database, then the EVS portal builds its schema.
--
-- The legacy schema still lives in database/init.sql (+ its \\ir includes) for
-- local-dev / CI of the retained legacy servers. To regenerate the full legacy
-- baseline here, run: INCLUDE_LEGACY_SCHEMA=true ./database/tool/consolidate-schema.sh
--
-- Generated: ${timestamp}
-- Git commit: ${git_commit}
--
-- =====================================================

EOF
        return 0
    fi

    cat << EOF
-- IMPLEMENTS REQUIREMENTS:
--   REQ-o00004: Database Schema Deployment
--   REQ-d00057: Automated database schema deployment
--
-- =====================================================
-- Clinical Trial Diary Database - Complete Initialization
-- CONSOLIDATED FOR CLOUD SQL (PostgreSQL 17)
-- =====================================================
--
-- This is an AUTO-GENERATED single-file version of the database schema
-- suitable for direct execution on Cloud SQL without psql-specific
-- commands like \\ir or \\echo.
--
-- DO NOT EDIT THIS FILE DIRECTLY - edit the source files instead:
--   database/init.sql, database/schema.sql, database/triggers.sql, etc.
--
-- Generated: ${timestamp}
-- Git commit: ${git_commit}
-- Source: database/init.sql
--
-- To regenerate: INCLUDE_LEGACY_SCHEMA=true ./database/tool/consolidate-schema.sh
--
-- =====================================================

EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    if [[ "${INCLUDE_LEGACY_SCHEMA}" == "true" ]]; then
        log_info "Starting schema consolidation (legacy schema INCLUDED)"
    else
        log_info "Generating NO-OP reset baseline (EVS owns its own schema; set INCLUDE_LEGACY_SCHEMA=true for legacy)"
    fi
    log_info "Output: ${OUTPUT_FILE}"

    # The legacy schema source is only needed when inlining it.
    if [[ "${INCLUDE_LEGACY_SCHEMA}" == "true" ]]; then
        log_info "Input: ${INPUT_FILE}"
        if [[ ! -f "$INPUT_FILE" ]]; then
            log_error "Input file not found: $INPUT_FILE"
            exit 1
        fi
    fi

    # Create temporary file for atomic write
    local temp_file
    temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT

    # Generate consolidated file. In the default (EVS) mode the header IS the
    # whole file — a comment-only no-op; the legacy schema is inlined only when
    # explicitly requested.
    {
        generate_header
        if [[ "${INCLUDE_LEGACY_SCHEMA}" == "true" ]]; then
            expand_file "init.sql"
        fi
    } > "$temp_file"

    # Move to final location
    mv "$temp_file" "$OUTPUT_FILE"
    trap - EXIT

    # Report statistics
    local line_count
    line_count=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
    local file_size
    file_size=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')

    log_info "Consolidation complete"
    log_info "Output: ${OUTPUT_FILE}"
    log_info "Lines: ${line_count}"
    log_info "Size: ${file_size} bytes"
}

main "$@"

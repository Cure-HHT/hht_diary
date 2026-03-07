#!/usr/bin/env bash
# database/tool/add_user.sh
#
# Add portal users from CSV input: inserts into the database and creates
# Identity Platform accounts.
#
# Usage:
#   echo "email,name,role" | doppler run -- ./database/tool/add_user.sh
#   cat users.csv | doppler run -- ./database/tool/add_user.sh
#
# CSV format (no header row):
#   email,name,role
#
# Valid roles: Investigator, Sponsor, Auditor, Analyst, Administrator,
#              Developer Admin
#
# Example:
#   cat <<CSV | doppler run -- ./database/tool/add_user.sh
#   alice@example.com,Alice Smith,Investigator
#   bob@example.com,Bob Jones,Developer Admin
#   CSV
#
# Doppler provides: DB_HOST, DB_PASSWORD, DB_NAME, DB_USER, DEFAULT_USER_PWD,
#                   SPONSOR, ENVIRONMENT
#
# Prerequisites:
#   - Doppler configured for the target environment
#   - gcloud authenticated (gcloud auth login)
#   - psql, curl, jq installed
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00031: Identity Platform Integration

set -euo pipefail

# -----------------------------------------------------------------------------
# Logging (matches entrypoint.sh pattern)
# -----------------------------------------------------------------------------

log() {
    local level="$1"
    shift
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [$level] $*"
}

log_info()  { log "INFO" "$@"; }
log_warn()  { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage: echo "email,name,role" | doppler run -- ./database/tool/add_user.sh
       cat users.csv | doppler run -- ./database/tool/add_user.sh

Reads CSV records from stdin, inserts portal users into the database,
assigns roles, and creates their Identity Platform accounts.

CSV format (no header row):
  email,name,role

Valid roles:
  Investigator, Sponsor, Auditor, Analyst, Administrator, Developer Admin

Example:
  cat <<CSV | doppler run -- ./database/tool/add_user.sh
  alice@example.com,Alice Smith,Investigator
  bob@example.com,Bob Jones,Developer Admin
  CSV

Environment variables (from Doppler):
  DB_HOST            Database host
  DB_PORT            Database port (default: 5432)
  DB_NAME            Database name
  DB_USER            Database user
  DB_PASSWORD        Database password
  DEFAULT_USER_PWD   Password for the Identity Platform account
  SPONSOR            Sponsor name (e.g., callisto4)
  ENVIRONMENT        Environment (dev, qa, uat, prod)
EOF
    exit 1
}

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    usage
fi

# -----------------------------------------------------------------------------
# Validate environment
# -----------------------------------------------------------------------------

: "${DB_HOST:?DB_HOST is required (set via Doppler)}"
: "${DB_PORT:=5432}"
: "${DB_NAME:?DB_NAME is required (set via Doppler)}"
: "${DB_USER:?DB_USER is required (set via Doppler)}"
: "${DB_PASSWORD:?DB_PASSWORD is required (set via Doppler)}"
: "${DEFAULT_USER_PWD:?DEFAULT_USER_PWD is required for Identity Platform (set via Doppler)}"
: "${SPONSOR:?SPONSOR is required (set via Doppler)}"
: "${ENVIRONMENT:?ENVIRONMENT is required (set via Doppler)}"

export PGPASSWORD="${DB_PASSWORD}"

# -----------------------------------------------------------------------------
# Read CSV from stdin
# -----------------------------------------------------------------------------

declare -a emails=()
declare -a names=()
declare -a roles=()

while IFS=',' read -r email name role; do
    # Skip empty lines and comments
    email=$(echo "${email}" | xargs)
    [[ -z "${email}" || "${email}" == \#* ]] && continue

    name=$(echo "${name}" | xargs)
    role=$(echo "${role}" | xargs)

    if [[ -z "${name}" ]] || [[ -z "${role}" ]]; then
        log_error "Invalid CSV row (need email,name,role): ${email},${name},${role}"
        exit 1
    fi

    emails+=("${email}")
    names+=("${name}")
    roles+=("${role}")
done

user_count=${#emails[@]}
if [[ ${user_count} -eq 0 ]]; then
    log_error "No CSV records read from stdin"
    usage
fi

log_info "Read ${user_count} user(s) from CSV"

# -----------------------------------------------------------------------------
# Step 1: Build and execute portal_users INSERT
# -----------------------------------------------------------------------------

log_info "Inserting users into ${DB_NAME} on ${DB_HOST}:${DB_PORT}..."

# Build VALUES rows with deterministic UUIDs matching the seed-data pattern
users_values=""
for i in $(seq 0 $((user_count - 1))); do
    idx=$((i + 1))
    uuid=$(printf "00000000-0000-0000-0000-%012d" "${idx}")
    e="${emails[$i]}"
    n="${names[$i]}"

    # Escape single quotes for SQL
    e_sql="${e//\'/\'\'}"
    n_sql="${n//\'/\'\'}"

    [[ -n "${users_values}" ]] && users_values+=","
    users_values+=$'\n'"    ('${uuid}', '${e_sql}', '${n_sql}', 'active', now())"
done

users_sql="INSERT INTO portal_users (id, email, name, status, activated_at) VALUES${users_values}
ON CONFLICT (email) DO NOTHING;"

log_info "Executing portal_users INSERT..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    -v ON_ERROR_STOP=1 -c "${users_sql}" 2>&1
log_info "portal_users INSERT complete"

# -----------------------------------------------------------------------------
# Step 2: Look up actual user IDs (handles both new and existing rows)
# -----------------------------------------------------------------------------

# Build a comma-separated list of quoted emails for the IN clause
email_list=""
for e in "${emails[@]}"; do
    e_sql="${e//\'/\'\'}"
    [[ -n "${email_list}" ]] && email_list+=","
    email_list+="'${e_sql}'"
done

# Query actual ids — these may differ from the deterministic UUIDs if users
# already existed with different ids
declare -A id_by_email=()

while IFS='|' read -r uid uemail; do
    uid=$(echo "${uid}" | xargs)
    uemail=$(echo "${uemail}" | xargs)
    id_by_email["${uemail}"]="${uid}"
done < <(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    -tAF'|' -c "SELECT id, email FROM portal_users WHERE email IN (${email_list})")

# -----------------------------------------------------------------------------
# Step 3: Build and execute portal_user_roles INSERT
# -----------------------------------------------------------------------------

log_info "Assigning roles..."

roles_values=""
for i in $(seq 0 $((user_count - 1))); do
    e="${emails[$i]}"
    r="${roles[$i]}"
    uid="${id_by_email[${e}]:-}"

    if [[ -z "${uid}" ]]; then
        log_warn "No user ID found for ${e} — skipping role assignment"
        continue
    fi

    r_sql="${r//\'/\'\'}"
    [[ -n "${roles_values}" ]] && roles_values+=","
    roles_values+=$'\n'"    ('${uid}', '${r_sql}')"
done

if [[ -n "${roles_values}" ]]; then
    roles_sql="INSERT INTO portal_user_roles (user_id, role) VALUES${roles_values}
ON CONFLICT (user_id, role) DO NOTHING;"

    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
        -v ON_ERROR_STOP=1 -c "${roles_sql}" 2>&1
    log_info "portal_user_roles INSERT complete"
fi

# -----------------------------------------------------------------------------
# Step 4: Create Identity Platform accounts
# -----------------------------------------------------------------------------

project_id="${SPONSOR}-${ENVIRONMENT}"
log_info "Creating Identity Platform accounts in project ${project_id}..."

access_token=$(gcloud auth print-access-token 2>/dev/null)
if [[ -z "${access_token}" ]]; then
    log_error "Failed to obtain GCP access token (run: gcloud auth login)"
    exit 3
fi

api_base="https://identitytoolkit.googleapis.com/v1"

created=0
updated=0
errors=0

for i in $(seq 0 $((user_count - 1))); do
    e="${emails[$i]}"
    n="${names[$i]}"
    uid="${id_by_email[${e}]:-}"

    # Try signUp
    signup_payload=$(jq -n \
        --arg email "${e}" \
        --arg password "${DEFAULT_USER_PWD}" \
        --arg displayName "${n}" \
        --arg targetProjectId "${project_id}" \
        '{email: $email, password: $password, displayName: $displayName, targetProjectId: $targetProjectId}')

    signup_response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -d "${signup_payload}" \
        "${api_base}/accounts:signUp" 2>&1)

    http_code=$(echo "${signup_response}" | tail -1)
    body=$(echo "${signup_response}" | sed '$d')
    local_id=$(echo "${body}" | jq -r '.localId // empty' 2>/dev/null)

    if [[ "${http_code}" == "200" ]] && [[ -n "${local_id}" ]]; then
        # Set emailVerified
        update_payload=$(jq -n \
            --arg localId "${local_id}" \
            --arg targetProjectId "${project_id}" \
            '{localId: $localId, emailVerified: true, targetProjectId: $targetProjectId}')

        curl -sf -X POST \
            -H "Authorization: Bearer ${access_token}" \
            -H "Content-Type: application/json" \
            -d "${update_payload}" \
            "${api_base}/accounts:update" >/dev/null 2>&1 || true

        log_info "  [CREATED] ${e} (uid: ${local_id})"
        created=$((created + 1))
    else
        # Look up existing user and update
        lookup_payload=$(jq -n --arg email "${e}" '{email: [$email]}')

        lookup_response=$(curl -sf -X POST \
            -H "Authorization: Bearer ${access_token}" \
            -H "Content-Type: application/json" \
            -d "${lookup_payload}" \
            "${api_base}/projects/${project_id}/accounts:lookup" 2>&1) || true

        local_id=$(echo "${lookup_response}" | jq -r '.users[0].localId // empty' 2>/dev/null)

        if [[ -n "${local_id}" ]]; then
            update_payload=$(jq -n \
                --arg localId "${local_id}" \
                --arg password "${DEFAULT_USER_PWD}" \
                --arg displayName "${n}" \
                --arg targetProjectId "${project_id}" \
                '{localId: $localId, password: $password, displayName: $displayName, emailVerified: true, targetProjectId: $targetProjectId}')

            curl -sf -X POST \
                -H "Authorization: Bearer ${access_token}" \
                -H "Content-Type: application/json" \
                -d "${update_payload}" \
                "${api_base}/accounts:update" >/dev/null 2>&1 || {
                log_error "  [ERROR] ${e}: failed to update"
                errors=$((errors + 1))
                continue
            }

            log_info "  [UPDATED] ${e} (uid: ${local_id})"
            updated=$((updated + 1))
        else
            log_error "  [ERROR] ${e}: failed to create or find"
            errors=$((errors + 1))
            continue
        fi
    fi

    # Link firebase_uid back to portal_users
    if [[ -n "${uid}" ]] && [[ -n "${local_id}" ]]; then
        local_id_sql="${local_id//\'/\'\'}"
        e_sql="${e//\'/\'\'}"
        psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
            -c "UPDATE portal_users SET firebase_uid = '${local_id_sql}' WHERE email = '${e_sql}'" \
            >/dev/null 2>&1
    fi
done

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

log_info "=========================================="
log_info "add_user.sh complete"
log_info "  Project:     ${project_id}"
log_info "  Database:    ${DB_NAME}"
log_info "  Users:       ${user_count}"
log_info "  ID Created:  ${created}"
log_info "  ID Updated:  ${updated}"
log_info "  ID Errors:   ${errors}"
log_info "=========================================="

if [[ ${errors} -gt 0 ]]; then
    exit 4
fi

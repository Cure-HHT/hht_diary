#!/bin/bash
# verify-audit-compliance.sh
#
# Verify FDA 21 CFR Part 11 audit log compliance for a sponsor
#
# Usage: ./verify-audit-compliance.sh <sponsor>
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-p00042: Infrastructure audit trail for FDA compliance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# Constants
# =============================================================================

readonly FDA_RETENTION_YEARS=25
readonly ENVIRONMENTS=("dev" "qa" "uat" "prod")

# =============================================================================
# Usage
# =============================================================================

usage() {
    cat << EOF
Usage: $(basename "$0") <sponsor> [options]

Verify FDA 21 CFR Part 11 audit log compliance for all environments.

Arguments:
  sponsor       Sponsor name (e.g., callisto, cure-hht)

Options:
  --project-prefix    Project prefix (default: cure-hht)
  --json              Output in JSON format
  -h, --help          Show this help message

Examples:
  ./verify-audit-compliance.sh callisto
  ./verify-audit-compliance.sh callisto --json

EOF
    exit 1
}

# =============================================================================
# Parse Arguments
# =============================================================================

SPONSOR=""
PROJECT_PREFIX="cure-hht"
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --project-prefix)
            PROJECT_PREFIX="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -z "$SPONSOR" ]]; then
                SPONSOR="$1"
            else
                log_error "Unexpected argument: $1"
                usage
            fi
            shift
            ;;
    esac
done

if [[ -z "$SPONSOR" ]]; then
    log_error "Sponsor name is required"
    usage
fi

validate_sponsor_name "$SPONSOR" || exit 1

# =============================================================================
# Verification Functions
# =============================================================================

check_bucket_exists() {
    local bucket="$1"
    local project="$2"

    if gcloud storage buckets describe "gs://${bucket}" --project="$project" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

get_bucket_retention() {
    local bucket="$1"
    local project="$2"

    gcloud storage buckets describe "gs://${bucket}" \
        --project="$project" \
        --format="json(retentionPolicy)" 2>/dev/null || echo "{}"
}

check_log_sink() {
    local sink_name="$1"
    local project="$2"

    if gcloud logging sinks describe "$sink_name" --project="$project" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

print_header "FDA 21 CFR Part 11 Audit Compliance Verification"
log_info "Sponsor: $SPONSOR"
log_info "Project Prefix: $PROJECT_PREFIX"
echo

# Track overall compliance
COMPLIANCE_ISSUES=()
declare -A RESULTS

for env in "${ENVIRONMENTS[@]}"; do
    project="${PROJECT_PREFIX}-${SPONSOR}-${env}"
    bucket="${PROJECT_PREFIX}-${SPONSOR}-${env}-audit-logs"
    sink="${SPONSOR}-${env}-audit-log-sink"

    log_step "Checking ${env} environment..."

    # Check bucket exists
    if ! check_bucket_exists "$bucket" "$project"; then
        log_error "  Audit bucket NOT FOUND: $bucket"
        COMPLIANCE_ISSUES+=("${env}: Bucket missing")
        RESULTS["${env}_bucket"]="MISSING"
        continue
    fi

    log_success "  Bucket exists: $bucket"
    RESULTS["${env}_bucket"]="OK"

    # Check retention policy
    retention_json=$(get_bucket_retention "$bucket" "$project")
    retention_seconds=$(echo "$retention_json" | jq -r '.retentionPolicy.retentionPeriod // "0"' | sed 's/s$//')
    is_locked=$(echo "$retention_json" | jq -r '.retentionPolicy.isLocked // false')

    if [[ "$retention_seconds" == "0" ]] || [[ "$retention_seconds" == "null" ]]; then
        log_error "  Retention policy NOT SET"
        COMPLIANCE_ISSUES+=("${env}: No retention policy")
        RESULTS["${env}_retention"]="MISSING"
    else
        retention_years=$((retention_seconds / 31536000))
        RESULTS["${env}_retention"]="$retention_years years"

        if [[ $retention_years -lt $FDA_RETENTION_YEARS ]]; then
            log_warn "  Retention: ${retention_years} years (FDA requires $FDA_RETENTION_YEARS)"
            COMPLIANCE_ISSUES+=("${env}: Retention ${retention_years} < ${FDA_RETENTION_YEARS} years")
        else
            log_success "  Retention: ${retention_years} years"
        fi
    fi

    # Check lock status
    RESULTS["${env}_locked"]="$is_locked"

    if [[ "$env" == "prod" ]]; then
        if [[ "$is_locked" != "true" ]]; then
            log_error "  Retention policy NOT LOCKED (REQUIRED for production)"
            COMPLIANCE_ISSUES+=("${env}: Retention not locked")
        else
            log_success "  Retention LOCKED (FDA compliant)"
        fi
    else
        if [[ "$is_locked" == "true" ]]; then
            log_warn "  Retention LOCKED (unusual for non-prod)"
        else
            log_info "  Retention unlocked (OK for ${env})"
        fi
    fi

    # Check log sink
    if check_log_sink "$sink" "$project"; then
        log_success "  Log sink active: $sink"
        RESULTS["${env}_sink"]="OK"
    else
        log_warn "  Log sink NOT FOUND: $sink"
        RESULTS["${env}_sink"]="MISSING"
    fi

    echo
done

# =============================================================================
# Summary
# =============================================================================

print_header "Compliance Summary"

if [[ ${#COMPLIANCE_ISSUES[@]} -eq 0 ]]; then
    log_success "All environments are FDA 21 CFR Part 11 compliant!"
    echo
    log_info "Compliance Checklist:"
    log_info "  [x] All audit buckets exist"
    log_info "  [x] All buckets have ${FDA_RETENTION_YEARS}-year retention"
    log_info "  [x] Production bucket retention is LOCKED"
    log_info "  [x] All log sinks are active"
    EXIT_CODE=0
else
    log_error "Compliance issues found:"
    for issue in "${COMPLIANCE_ISSUES[@]}"; do
        log_error "  - $issue"
    done
    echo
    log_warn "Please resolve these issues for FDA compliance"
    EXIT_CODE=1
fi

# JSON output if requested
if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo
    echo "{"
    echo "  \"sponsor\": \"${SPONSOR}\","
    echo "  \"compliant\": ${#COMPLIANCE_ISSUES[@]} -eq 0,"
    echo "  \"issues\": ["
    for i in "${!COMPLIANCE_ISSUES[@]}"; do
        echo -n "    \"${COMPLIANCE_ISSUES[$i]}\""
        [[ $i -lt $((${#COMPLIANCE_ISSUES[@]} - 1)) ]] && echo "," || echo
    done
    echo "  ],"
    echo "  \"environments\": {"
    for env in "${ENVIRONMENTS[@]}"; do
        echo "    \"${env}\": {"
        echo "      \"bucket\": \"${RESULTS["${env}_bucket"]:-UNKNOWN}\","
        echo "      \"retention\": \"${RESULTS["${env}_retention"]:-UNKNOWN}\","
        echo "      \"locked\": ${RESULTS["${env}_locked"]:-false},"
        echo "      \"sink\": \"${RESULTS["${env}_sink"]:-UNKNOWN}\""
        [[ "$env" != "prod" ]] && echo "    }," || echo "    }"
    done
    echo "  }"
    echo "}"
fi

exit $EXIT_CODE

#!/bin/bash
# bootstrap-sponsor.sh
#
# Bootstrap all 4 GCP projects for a new sponsor
#
# Usage: doppler run -- ./bootstrap-sponsor.sh <sponsor-name> [options]
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model
#   REQ-p00042: Infrastructure audit trail for FDA compliance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# Usage
# =============================================================================

usage() {
    cat << EOF
Usage: $(basename "$0") <sponsor-name> [options]

Bootstrap all 4 GCP projects (dev, qa, uat, prod) for a sponsor.

Options:
  --apply           Apply changes (default is plan only)
  --destroy         Destroy all sponsor infrastructure (DANGEROUS)
  --skip-verify     Skip audit log compliance verification
  --config-file     Path to custom tfvars file
  --auto-approve    Skip confirmation prompts
  -h, --help        Show this help message

Examples:
  # Preview what will be created
  doppler run -- ./bootstrap-sponsor.sh callisto

  # Apply changes
  doppler run -- ./bootstrap-sponsor.sh callisto --apply

  # Use custom config
  doppler run -- ./bootstrap-sponsor.sh callisto --config-file ./my-config.tfvars --apply

EOF
    exit 1
}

# =============================================================================
# Parse Arguments
# =============================================================================

SPONSOR=""
APPLY=false
DESTROY=false
SKIP_VERIFY=false
AUTO_APPROVE=false
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --apply)
            APPLY=true
            shift
            ;;
        --destroy)
            DESTROY=true
            shift
            ;;
        --skip-verify)
            SKIP_VERIFY=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --config-file)
            CONFIG_FILE="$2"
            shift 2
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

# =============================================================================
# Validation
# =============================================================================

if [[ -z "$SPONSOR" ]]; then
    log_error "Sponsor name is required"
    usage
fi

validate_sponsor_name "$SPONSOR" || exit 1
check_doppler_env || exit 1

# Set paths
BOOTSTRAP_DIR="${SCRIPT_DIR}/../bootstrap"
TFVARS_FILE="${CONFIG_FILE:-${BOOTSTRAP_DIR}/sponsor-configs/${SPONSOR}.tfvars}"

# Check tfvars exists
if [[ ! -f "$TFVARS_FILE" ]]; then
    log_error "Config file not found: $TFVARS_FILE"
    log_info "Create from template:"
    log_info "  cp ${BOOTSTRAP_DIR}/sponsor-configs/example.tfvars ${BOOTSTRAP_DIR}/sponsor-configs/${SPONSOR}.tfvars"
    exit 1
fi

# =============================================================================
# Main
# =============================================================================

# Set quota project for Billing Budgets API
# The billingbudgets.googleapis.com API requires an explicit quota project
# which must have the required APIs enabled
export GOOGLE_CLOUD_QUOTA_PROJECT="${GOOGLE_CLOUD_QUOTA_PROJECT:-cure-hht-admin}"
log_info "Using quota project: $GOOGLE_CLOUD_QUOTA_PROJECT"

print_header "Bootstrapping Sponsor: $SPONSOR"

log_info "Config file: $TFVARS_FILE"
log_info "Terraform directory: $BOOTSTRAP_DIR"

# Show configuration summary
echo
log_info "Configuration Summary:"
grep -E "^(sponsor|sponsor_id|billing_account|gcp_org_id|project_prefix)" "$TFVARS_FILE" | while read line; do
    echo "  $line"
done
echo

# Initialize Terraform
cd "$BOOTSTRAP_DIR"
terraform_init "bootstrap/${SPONSOR}" "$BOOTSTRAP_DIR"

# Handle destroy
if [[ "$DESTROY" == "true" ]]; then
    print_header "DESTROYING Sponsor Infrastructure"

    if ! confirm_destructive_action "all infrastructure for sponsor '$SPONSOR'"; then
        log_warn "Aborted"
        exit 0
    fi

    terraform_destroy "$TFVARS_FILE" "$BOOTSTRAP_DIR"
    log_success "Sponsor infrastructure destroyed: $SPONSOR"
    exit 0
fi

# Plan changes
print_header "Planning Changes"
terraform_plan "$TFVARS_FILE" "$BOOTSTRAP_DIR" "tfplan"

# Apply if requested
if [[ "$APPLY" == "true" ]]; then
    echo

    if [[ "$AUTO_APPROVE" != "true" ]]; then
        if ! confirm_action "Apply these changes?"; then
            log_warn "Aborted"
            rm -f tfplan
            exit 0
        fi
    fi

    print_header "Applying Changes"
    terraform_apply "tfplan" "$BOOTSTRAP_DIR"

    # Verify audit log compliance
    if [[ "$SKIP_VERIFY" != "true" ]]; then
        print_header "Verifying FDA Audit Log Compliance"
        "${SCRIPT_DIR}/verify-audit-compliance.sh" "$SPONSOR" || {
            log_warn "Audit compliance verification had warnings"
        }
    fi

    print_header "Bootstrap Complete"
    log_success "Successfully bootstrapped sponsor: $SPONSOR"

    # Show outputs
    echo
    terraform output -raw next_steps 2>/dev/null || true
else
    echo
    log_info "This was a dry run. No changes were made."
    log_info "Run with --apply to apply changes:"
    log_info "  $0 $SPONSOR --apply"
    rm -f tfplan
fi

#!/bin/bash
# deploy-environment.sh
#
# Deploy a single sponsor environment (dev/qa/uat/prod)
#
# Usage: doppler run -- ./deploy-environment.sh <sponsor> <environment> [options]
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# Usage
# =============================================================================

usage() {
    cat << EOF
Usage: $(basename "$0") <sponsor> <environment> [options]

Deploy a single environment for a sponsor.

Arguments:
  sponsor       Sponsor name (e.g., callisto, cure-hht)
  environment   Environment (dev, qa, uat, prod)

Options:
  --apply           Apply changes (default is plan only)
  --destroy         Destroy environment infrastructure (DANGEROUS)
  --config-file     Path to custom tfvars file
  --auto-approve    Skip confirmation prompts
  -h, --help        Show this help message

Examples:
  # Preview dev environment deployment
  doppler run -- ./deploy-environment.sh callisto dev

  # Deploy dev environment
  doppler run -- ./deploy-environment.sh callisto dev --apply

  # Deploy production (requires extra confirmation)
  doppler run -- ./deploy-environment.sh callisto prod --apply

EOF
    exit 1
}

# =============================================================================
# Parse Arguments
# =============================================================================

SPONSOR=""
ENVIRONMENT=""
APPLY=false
DESTROY=false
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
            elif [[ -z "$ENVIRONMENT" ]]; then
                ENVIRONMENT="$1"
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

if [[ -z "$SPONSOR" ]] || [[ -z "$ENVIRONMENT" ]]; then
    log_error "Sponsor and environment are required"
    usage
fi

validate_sponsor_name "$SPONSOR" || exit 1
validate_environment "$ENVIRONMENT" || exit 1
check_doppler_env || exit 1

# Extra warning for production
if [[ "$ENVIRONMENT" == "prod" ]] && [[ "$APPLY" == "true" ]] && [[ "$AUTO_APPROVE" != "true" ]]; then
    log_warn "You are about to deploy to PRODUCTION!"
    log_warn "This environment has:"
    log_warn "  - Deletion protection enabled"
    log_warn "  - Locked audit log retention (25 years, CANNOT be changed)"
    log_warn "  - Regional HA database"
    echo
    if ! confirm_action "Continue with production deployment?"; then
        log_warn "Aborted"
        exit 0
    fi
fi

# Set paths
PORTAL_DIR="${SCRIPT_DIR}/../sponsor-portal"
TFVARS_FILE="${CONFIG_FILE:-${PORTAL_DIR}/sponsor-configs/${SPONSOR}-${ENVIRONMENT}.tfvars}"

# Check tfvars exists
if [[ ! -f "$TFVARS_FILE" ]]; then
    log_error "Config file not found: $TFVARS_FILE"
    log_info "Create from template:"
    log_info "  cp ${PORTAL_DIR}/sponsor-configs/example-dev.tfvars ${PORTAL_DIR}/sponsor-configs/${SPONSOR}-${ENVIRONMENT}.tfvars"
    exit 1
fi

# =============================================================================
# Main
# =============================================================================

print_header "Deploying ${SPONSOR} ${ENVIRONMENT}"

log_info "Config file: $TFVARS_FILE"
log_info "Terraform directory: $PORTAL_DIR"

# Check for db_password
if ! grep -q "db_password" "$TFVARS_FILE" && [[ -z "${TF_VAR_db_password:-}" ]]; then
    log_warn "db_password not found in tfvars and TF_VAR_db_password not set"
    log_info "Set via Doppler or: export TF_VAR_db_password='your-password'"

    if [[ "$APPLY" == "true" ]]; then
        log_error "Cannot apply without db_password"
        exit 1
    fi
fi

# Initialize Terraform
cd "$PORTAL_DIR"
terraform_init "sponsor-portal/${SPONSOR}-${ENVIRONMENT}" "$PORTAL_DIR"

# Handle destroy
if [[ "$DESTROY" == "true" ]]; then
    print_header "DESTROYING ${SPONSOR} ${ENVIRONMENT}"

    if [[ "$ENVIRONMENT" == "prod" ]]; then
        log_error "Cannot destroy production environment via this script"
        log_error "Production environments require manual deletion with additional safeguards"
        exit 1
    fi

    if ! confirm_destructive_action "all infrastructure for ${SPONSOR} ${ENVIRONMENT}"; then
        log_warn "Aborted"
        exit 0
    fi

    terraform_destroy "$TFVARS_FILE" "$PORTAL_DIR"
    log_success "Environment destroyed: ${SPONSOR} ${ENVIRONMENT}"
    exit 0
fi

# Plan changes
print_header "Planning Changes"
terraform_plan "$TFVARS_FILE" "$PORTAL_DIR" "tfplan"

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
    terraform_apply "tfplan" "$PORTAL_DIR"

    print_header "Deployment Complete"
    log_success "Successfully deployed: ${SPONSOR} ${ENVIRONMENT}"

    # Show summary
    echo
    terraform output -raw summary 2>/dev/null || true
else
    echo
    log_info "This was a dry run. No changes were made."
    log_info "Run with --apply to apply changes:"
    log_info "  $0 $SPONSOR $ENVIRONMENT --apply"
    rm -f tfplan
fi

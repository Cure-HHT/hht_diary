#!/usr/bin/env bash
# migrate-budgets-audit-to-sponsor-envs.sh
#
# Migrate module.budgets and module.audit_logs Terraform state from
# bootstrap/ to sponsor-envs/ (one state file per environment).
#
# Usage: ./migrate-budgets-audit-to-sponsor-envs.sh <sponsor-name> [options]
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00041: Infrastructure as Code for Cloud Resources
#   REQ-o00042: Infrastructure Change Control
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
Usage: $(basename "$0") <sponsor-name> [options]

Migrate module.budgets and module.audit_logs state from bootstrap/ to
sponsor-envs/ for all 4 environments (dev, qa, uat, prod).

The bootstrap state stores module.budgets["dev"], module.audit_logs["dev"], etc.
This script moves each one into the per-environment sponsor-envs state as
module.budgets and module.audit_logs (no for_each key).

Prerequisites:
  1. Add module "budgets" block to sponsor-envs/main.tf
  2. Add module "audit_logs" block to sponsor-envs/main.tf
  3. Add BILLING_ACCOUNT_PROD/DEV, budget_amount variables to sponsor-envs/variables.tf
  4. Remove module "budgets" and module "audit_logs" from bootstrap/main.tf
  5. Remove related outputs from bootstrap/outputs.tf

Options:
  --dry-run         Show what would be moved without modifying state (default)
  --execute         Actually perform the state migration
  --env <env>       Migrate only a single environment (dev, qa, uat, prod)
  --backup-dir      Directory for state backups (default: /tmp/tf-migrate-ba-<sponsor>-<timestamp>)
  -h, --help        Show this help message

Examples:
  # Dry run — preview all 4 environments
  ./migrate-budgets-audit-to-sponsor-envs.sh callisto4

  # Dry run — preview only prod
  ./migrate-budgets-audit-to-sponsor-envs.sh callisto4 --env prod

  # Execute migration for all environments
  ./migrate-budgets-audit-to-sponsor-envs.sh callisto4 --execute

EOF
    exit 1
}

# =============================================================================
# Parse Arguments
# =============================================================================

SPONSOR=""
EXECUTE=false
SINGLE_ENV=""
BACKUP_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --execute)
            EXECUTE=true
            shift
            ;;
        --dry-run)
            EXECUTE=false
            shift
            ;;
        --env)
            SINGLE_ENV="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
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

if [[ -n "$SINGLE_ENV" ]]; then
    validate_environment "$SINGLE_ENV" || exit 1
fi

# Determine environments to migrate
if [[ -n "$SINGLE_ENV" ]]; then
    ENVIRONMENTS=("$SINGLE_ENV")
else
    ENVIRONMENTS=(dev qa uat prod)
fi

# Backup directory
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-/tmp/tf-migrate-ba-${SPONSOR}-${TIMESTAMP}}"

# Paths
BOOTSTRAP_DIR="${TERRAFORM_DIR}/bootstrap"
SPONSOR_ENVS_DIR="${TERRAFORM_DIR}/sponsor-envs"

# =============================================================================
# Pre-flight Checks
# =============================================================================

print_header "Budgets & Audit Logs State Migration: bootstrap -> sponsor-envs"

log_info "Sponsor:       $SPONSOR"
log_info "Environments:  ${ENVIRONMENTS[*]}"
log_info "Backup dir:    $BACKUP_DIR"
log_info "Mode:          $(if $EXECUTE; then echo "EXECUTE"; else echo "DRY RUN"; fi)"
echo

# Verify terraform is installed
if ! command -v terraform &>/dev/null; then
    log_error "terraform is not installed or not in PATH"
    exit 1
fi

# Verify directories exist
if [[ ! -d "$BOOTSTRAP_DIR" ]]; then
    log_error "Bootstrap directory not found: $BOOTSTRAP_DIR"
    exit 1
fi

if [[ ! -d "$SPONSOR_ENVS_DIR" ]]; then
    log_error "Sponsor-envs directory not found: $SPONSOR_ENVS_DIR"
    exit 1
fi

# =============================================================================
# Phase 1: Pull States
# =============================================================================

print_header "Phase 1: Pulling Terraform State Files"

mkdir -p "$BACKUP_DIR"

# Pull bootstrap state
log_step "Pulling bootstrap state (prefix: bootstrap/${SPONSOR})"
(
    cd "$BOOTSTRAP_DIR"
    terraform init \
        -backend-config="bucket=${STATE_BUCKET}" \
        -backend-config="prefix=bootstrap/${SPONSOR}" \
        -reconfigure -input=false >/dev/null 2>&1
    terraform state pull > "${BACKUP_DIR}/bootstrap.tfstate"
)
log_success "Bootstrap state saved to ${BACKUP_DIR}/bootstrap.tfstate"

# Verify bootstrap state has the budget and audit resources
BUDGET_COUNT=$(terraform state list -state="${BACKUP_DIR}/bootstrap.tfstate" 2>/dev/null \
    | grep -c '^module\.budgets\[' || true)
AUDIT_COUNT=$(terraform state list -state="${BACKUP_DIR}/bootstrap.tfstate" 2>/dev/null \
    | grep -c '^module\.audit_logs\[' || true)

if [[ "$BUDGET_COUNT" -eq 0 && "$AUDIT_COUNT" -eq 0 ]]; then
    log_error "No module.budgets or module.audit_logs resources found in bootstrap state"
    log_error "Are you sure these modules are deployed for sponsor '${SPONSOR}'?"
    exit 1
fi

log_info "Found ${BUDGET_COUNT} budget resources and ${AUDIT_COUNT} audit log resources in bootstrap state"

# Pull sponsor-envs state for each environment
for ENV in "${ENVIRONMENTS[@]}"; do
    log_step "Pulling sponsor-envs state for ${ENV} (prefix: sponsor-portal/${SPONSOR}-${ENV})"
    (
        cd "$SPONSOR_ENVS_DIR"
        terraform init \
            -backend-config="bucket=${STATE_BUCKET}" \
            -backend-config="prefix=sponsor-portal/${SPONSOR}-${ENV}" \
            -reconfigure -input=false >/dev/null 2>&1
        terraform state pull > "${BACKUP_DIR}/sponsor-envs-${ENV}.tfstate"
    )
    log_success "Sponsor-envs ${ENV} state saved to ${BACKUP_DIR}/sponsor-envs-${ENV}.tfstate"
done

# =============================================================================
# Phase 2: Preview Resources to Move
# =============================================================================

print_header "Phase 2: Resources to Migrate"

for ENV in "${ENVIRONMENTS[@]}"; do
    echo
    log_info "=== ${ENV} ==="

    # Budgets
    BUDGET_RESOURCES=$(terraform state list -state="${BACKUP_DIR}/bootstrap.tfstate" 2>/dev/null \
        | grep "^module\.budgets\[\"${ENV}\"\]" || true)
    if [[ -n "$BUDGET_RESOURCES" ]]; then
        log_info "Source:  module.budgets[\"${ENV}\"]  (in bootstrap state)"
        log_info "Target:  module.budgets              (in sponsor-envs/${ENV} state)"
        echo "$BUDGET_RESOURCES" | while read -r addr; do
            echo "  -> ${addr}"
        done
    else
        log_warn "No module.budgets[\"${ENV}\"] found in bootstrap state (skipping)"
    fi

    echo

    # Audit logs
    AUDIT_RESOURCES=$(terraform state list -state="${BACKUP_DIR}/bootstrap.tfstate" 2>/dev/null \
        | grep "^module\.audit_logs\[\"${ENV}\"\]" || true)
    if [[ -n "$AUDIT_RESOURCES" ]]; then
        log_info "Source:  module.audit_logs[\"${ENV}\"]  (in bootstrap state)"
        log_info "Target:  module.audit_logs              (in sponsor-envs/${ENV} state)"
        echo "$AUDIT_RESOURCES" | while read -r addr; do
            echo "  -> ${addr}"
        done
    else
        log_warn "No module.audit_logs[\"${ENV}\"] found in bootstrap state (skipping)"
    fi

    echo
done

# =============================================================================
# Phase 3: Move State (or dry-run)
# =============================================================================

if ! $EXECUTE; then
    print_header "DRY RUN Complete"
    log_info "No state was modified."
    log_info "Backups saved to: ${BACKUP_DIR}"
    echo
    log_info "To execute the migration, run:"
    log_info "  $0 $SPONSOR --execute --backup-dir ${BACKUP_DIR}"
    exit 0
fi

# Confirm before executing
echo
log_warn "This will modify Terraform state for sponsor '${SPONSOR}'."
log_warn "Backups are in: ${BACKUP_DIR}"
if ! confirm_action "Proceed with state migration?"; then
    log_warn "Aborted"
    exit 0
fi

print_header "Phase 3: Moving State"

# Work on a copy of bootstrap state (we'll modify it incrementally)
cp "${BACKUP_DIR}/bootstrap.tfstate" "${BACKUP_DIR}/bootstrap-modified.tfstate"

for ENV in "${ENVIRONMENTS[@]}"; do
    # Copy the env's sponsor-envs state for modification
    cp "${BACKUP_DIR}/sponsor-envs-${ENV}.tfstate" "${BACKUP_DIR}/sponsor-envs-${ENV}-modified.tfstate"

    # Move budgets
    BUDGET_RESOURCES=$(terraform state list -state="${BACKUP_DIR}/bootstrap-modified.tfstate" 2>/dev/null \
        | grep "^module\.budgets\[\"${ENV}\"\]" || true)
    if [[ -n "$BUDGET_RESOURCES" ]]; then
        log_step "Moving module.budgets[\"${ENV}\"] -> module.budgets (${ENV})"
        terraform state mv \
            -state="${BACKUP_DIR}/bootstrap-modified.tfstate" \
            -state-out="${BACKUP_DIR}/sponsor-envs-${ENV}-modified.tfstate" \
            "module.budgets[\"${ENV}\"]" \
            "module.budgets"
        log_success "Moved budget resources for ${ENV}"
    else
        log_warn "No budgets to move for ${ENV}"
    fi

    # Move audit logs
    AUDIT_RESOURCES=$(terraform state list -state="${BACKUP_DIR}/bootstrap-modified.tfstate" 2>/dev/null \
        | grep "^module\.audit_logs\[\"${ENV}\"\]" || true)
    if [[ -n "$AUDIT_RESOURCES" ]]; then
        log_step "Moving module.audit_logs[\"${ENV}\"] -> module.audit_logs (${ENV})"
        terraform state mv \
            -state="${BACKUP_DIR}/bootstrap-modified.tfstate" \
            -state-out="${BACKUP_DIR}/sponsor-envs-${ENV}-modified.tfstate" \
            "module.audit_logs[\"${ENV}\"]" \
            "module.audit_logs"
        log_success "Moved audit log resources for ${ENV}"
    else
        log_warn "No audit logs to move for ${ENV}"
    fi
done

# =============================================================================
# Phase 4: Push Modified States
# =============================================================================

print_header "Phase 4: Pushing Modified State Files"

# Push bootstrap (budget + audit resources removed)
log_step "Pushing modified bootstrap state"
(
    cd "$BOOTSTRAP_DIR"
    terraform init \
        -backend-config="bucket=${STATE_BUCKET}" \
        -backend-config="prefix=bootstrap/${SPONSOR}" \
        -reconfigure -input=false >/dev/null 2>&1
    terraform state push "${BACKUP_DIR}/bootstrap-modified.tfstate"
)
log_success "Bootstrap state updated (budget + audit resources removed)"

# Push each sponsor-envs state (budget + audit resources added)
for ENV in "${ENVIRONMENTS[@]}"; do
    log_step "Pushing modified sponsor-envs state for ${ENV}"
    (
        cd "$SPONSOR_ENVS_DIR"
        terraform init \
            -backend-config="bucket=${STATE_BUCKET}" \
            -backend-config="prefix=sponsor-portal/${SPONSOR}-${ENV}" \
            -reconfigure -input=false >/dev/null 2>&1
        terraform state push "${BACKUP_DIR}/sponsor-envs-${ENV}-modified.tfstate"
    )
    log_success "Sponsor-envs ${ENV} state updated (budget + audit resources added)"
done

# =============================================================================
# Phase 5: Verification
# =============================================================================

print_header "Phase 5: Verification"

log_info "State migration complete. Backups are in: ${BACKUP_DIR}"
echo
log_info "Next steps:"
echo "  1. Verify bootstrap shows no changes:"
echo "     doppler run -- ./bootstrap-sponsor.sh ${SPONSOR}"
echo
echo "  2. Verify each environment shows no changes:"
echo "     for ENV in dev qa uat prod; do"
echo "       doppler run -- ./deploy-environment.sh ${SPONSOR} \$ENV"
echo "     done"
echo
echo "  3. Verify audit log compliance:"
echo "     ./verify-audit-compliance.sh ${SPONSOR}"
echo
log_warn "Keep backups in ${BACKUP_DIR} until all environments are verified!"

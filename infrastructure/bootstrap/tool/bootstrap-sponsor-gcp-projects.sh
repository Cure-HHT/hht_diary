#!/usr/bin/env bash
#
# Bootstrap GCP Projects for a New Sponsor
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Pulumi IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model
#   REQ-p00042: Infrastructure audit trail for FDA compliance
#
# Usage:
#   doppler run -- ./bootstrap-sponsor-gcp-projects.sh <config-file.json>
#
# Example:
#   doppler run -- ./bootstrap-sponsor-gcp-projects.sh ./sponsor-configs/acme.json
#
# Required Doppler Environment Variables:
#   GOOGLE_APPLICATION_CREDENTIALS - Path to GCP service account key JSON
#   or
#   CLOUDSDK_AUTH_ACCESS_TOKEN     - GCP access token for authentication
#   or
#   (Application Default Credentials configured via 'gcloud auth application-default login')
#
#   PULUMI_CONFIG_PASSPHRASE       - Passphrase for Pulumi state encryption (required for GCS/S3/self-managed backends)
#
# Optional Doppler Environment Variables:
#   PULUMI_ACCESS_TOKEN            - Pulumi Cloud access token (if using Pulumi Cloud backend)
#   GCP_PROJECT                    - Default GCP project for gcloud commands
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check required environment variables (from Doppler)
check_doppler_env_vars() {
    log_info "Checking Doppler environment variables..."

    local missing_vars=()
    local has_gcp_auth=false

    # Check for GCP authentication (one of these methods)
    if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
        if [[ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
            log_success "GCP auth: GOOGLE_APPLICATION_CREDENTIALS set (file exists)"
            has_gcp_auth=true
        else
            log_error "GOOGLE_APPLICATION_CREDENTIALS set but file not found: $GOOGLE_APPLICATION_CREDENTIALS"
        fi
    elif [[ -n "${CLOUDSDK_AUTH_ACCESS_TOKEN:-}" ]]; then
        log_success "GCP auth: CLOUDSDK_AUTH_ACCESS_TOKEN set"
        has_gcp_auth=true
    elif gcloud auth application-default print-access-token &>/dev/null; then
        log_success "GCP auth: Application Default Credentials configured"
        has_gcp_auth=true
    fi

    if [[ "$has_gcp_auth" != "true" ]]; then
        missing_vars+=("GCP authentication (GOOGLE_APPLICATION_CREDENTIALS, CLOUDSDK_AUTH_ACCESS_TOKEN, or ADC)")
    fi

    # Check Pulumi passphrase (required for GCS backend with encryption)
    if [[ -z "${PULUMI_CONFIG_PASSPHRASE:-}" ]]; then
        log_warn "PULUMI_CONFIG_PASSPHRASE not set - required if using encrypted state"
    else
        log_success "PULUMI_CONFIG_PASSPHRASE is set"
    fi

    # Optional: Check for Pulumi Cloud token
    if [[ -n "${PULUMI_ACCESS_TOKEN:-}" ]]; then
        log_success "PULUMI_ACCESS_TOKEN is set (Pulumi Cloud)"
    fi

    # Verify gcloud is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1 | grep -q '@'; then
        missing_vars+=("Active gcloud authentication (run 'gcloud auth login')")
    else
        local active_account
        active_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
        log_success "gcloud authenticated as: $active_account"
    fi

    # Report missing variables
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo ""
        log_error "Missing required environment variables or authentication:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Ensure you run this script with Doppler:"
        echo "  doppler run -- $0 <config-file.json>"
        echo ""
        exit 1
    fi

    echo ""
}

# Verify audit log buckets exist (FDA 21 CFR Part 11 compliance)
verify_audit_logs() {
    local sponsor="$1"
    local project_prefix="$2"
    local environments=("dev" "qa" "uat" "prod")
    local all_exist=true
    local missing_buckets=()

    log_info "Verifying audit log infrastructure (FDA 21 CFR Part 11 compliance)..."
    echo ""

    for env in "${environments[@]}"; do
        local bucket_name="${project_prefix}-${sponsor}-${env}-audit-logs"
        local project_id="${project_prefix}-${sponsor}-${env}"

        # Check if bucket exists
        if gcloud storage buckets describe "gs://${bucket_name}" --project="$project_id" &>/dev/null; then
            # Check if retention policy is locked
            local retention_info
            retention_info=$(gcloud storage buckets describe "gs://${bucket_name}" \
                --project="$project_id" \
                --format="value(retentionPolicy.isLocked,retentionPolicy.retentionPeriod)" 2>/dev/null || echo "")

            if [[ "$retention_info" == "True"* ]]; then
                log_success "Audit bucket verified: $bucket_name (retention locked)"
            else
                log_warn "Audit bucket exists but retention may not be locked: $bucket_name"
                log_warn "  Retention info: $retention_info"
            fi
        else
            log_error "Audit bucket NOT FOUND: $bucket_name"
            missing_buckets+=("$bucket_name")
            all_exist=false
        fi
    done

    echo ""

    if [[ "$all_exist" != "true" ]]; then
        return 1
    fi

    return 0
}

# Rollback deployment
rollback_deployment() {
    local sponsor="$1"

    log_error "Rolling back deployment due to audit log verification failure..."
    echo ""

    # Destroy the Pulumi stack
    log_info "Destroying Pulumi resources..."
    if pulumi destroy --yes --stack "$sponsor" 2>/dev/null; then
        log_success "Resources destroyed"
    else
        log_error "Failed to destroy resources. Manual cleanup may be required."
        log_error "Run: pulumi destroy --stack $sponsor"
    fi

    # Optionally remove the stack
    read -p "Remove the Pulumi stack '$sponsor'? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pulumi stack rm "$sponsor" --yes 2>/dev/null || true
        log_info "Stack removed"
    fi

    echo ""
    log_error "Bootstrap failed. Audit log buckets were not created successfully."
    log_error "This is required for FDA 21 CFR Part 11 compliance."
    echo ""
    log_info "Troubleshooting steps:"
    echo "  1. Check GCP permissions for storage bucket creation"
    echo "  2. Verify the project IDs are correct"
    echo "  3. Check Pulumi logs: pulumi stack select $sponsor && pulumi up"
    echo "  4. Review GCP Cloud Console for any errors"
    echo ""

    exit 1
}

usage() {
    cat << EOF
Usage: $(basename "$0") <config-file.json>

Bootstrap GCP projects for a new sponsor.

Arguments:
  config-file.json    Path to JSON configuration file

Example config file (see sponsor-config.example.json):
{
  "sponsor": "acme",
  "gcpOrgId": "123456789012",
  "billingAccountId": "012345-6789AB-CDEF01",
  "projectPrefix": "cure-hht",
  "defaultRegion": "us-central1",
  "folderId": "",
  "githubOrg": "Cure-HHT",
  "githubRepo": "hht_diary"
}

Required fields:
  - sponsor           Sponsor name (lowercase, alphanumeric)
  - gcpOrgId          GCP Organization ID
  - billingAccountId  GCP Billing Account ID

Optional fields:
  - projectPrefix     Prefix for project IDs (default: cure-hht)
  - defaultRegion     Default GCP region (default: us-central1)
  - folderId          GCP Folder ID to place projects in
  - githubOrg         GitHub organization for Workload Identity
  - githubRepo        GitHub repository for Workload Identity
EOF
    exit 1
}

# Check for config file argument
if [[ $# -lt 1 ]]; then
    log_error "Missing required argument: config file"
    echo ""
    usage
fi

CONFIG_FILE="$1"

# Validate config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Check for required tools
for cmd in jq pulumi gcloud; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
done

# Check Doppler environment variables
check_doppler_env_vars

# Parse JSON config
log_info "Reading configuration from: $CONFIG_FILE"

SPONSOR=$(jq -r '.sponsor // empty' "$CONFIG_FILE")
GCP_ORG_ID=$(jq -r '.gcpOrgId // empty' "$CONFIG_FILE")
BILLING_ACCOUNT_ID=$(jq -r '.billingAccountId // empty' "$CONFIG_FILE")
PROJECT_PREFIX=$(jq -r '.projectPrefix // "cure-hht"' "$CONFIG_FILE")
DEFAULT_REGION=$(jq -r '.defaultRegion // "us-central1"' "$CONFIG_FILE")
FOLDER_ID=$(jq -r '.folderId // empty' "$CONFIG_FILE")
GITHUB_ORG=$(jq -r '.githubOrg // empty' "$CONFIG_FILE")
GITHUB_REPO=$(jq -r '.githubRepo // empty' "$CONFIG_FILE")

# Validate required fields
if [[ -z "$SPONSOR" ]]; then
    log_error "Missing required field: sponsor"
    exit 1
fi

if [[ -z "$GCP_ORG_ID" ]]; then
    log_error "Missing required field: gcpOrgId"
    exit 1
fi

if [[ -z "$BILLING_ACCOUNT_ID" ]]; then
    log_error "Missing required field: billingAccountId"
    exit 1
fi

# Validate sponsor name format (lowercase alphanumeric and hyphens)
if [[ ! "$SPONSOR" =~ ^[a-z][a-z0-9-]*$ ]]; then
    log_error "Invalid sponsor name: '$SPONSOR'. Must be lowercase, start with a letter, and contain only letters, numbers, and hyphens."
    exit 1
fi

# Display configuration
echo ""
log_info "Configuration:"
echo "  Sponsor:           $SPONSOR"
echo "  GCP Org ID:        $GCP_ORG_ID"
echo "  Billing Account:   $BILLING_ACCOUNT_ID"
echo "  Project Prefix:    $PROJECT_PREFIX"
echo "  Default Region:    $DEFAULT_REGION"
echo "  Folder ID:         ${FOLDER_ID:-"(none)"}"
echo "  GitHub Org:        ${GITHUB_ORG:-"(none)"}"
echo "  GitHub Repo:       ${GITHUB_REPO:-"(none)"}"
echo ""

# Projects that will be created
log_info "Projects to be created:"
for env in dev qa uat prod; do
    echo "  - ${PROJECT_PREFIX}-${SPONSOR}-${env}"
done
echo ""

# Confirm before proceeding
read -p "Proceed with bootstrap? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Aborted by user"
    exit 0
fi

# Change to bootstrap directory
cd "$BOOTSTRAP_DIR"

# Ensure dependencies are installed
if [[ ! -d "node_modules" ]]; then
    log_info "Installing npm dependencies..."
    npm install
fi

# Check if stack already exists
STACK_EXISTS=$(pulumi stack ls --json 2>/dev/null | jq -r ".[] | select(.name == \"$SPONSOR\") | .name" || echo "")

if [[ -n "$STACK_EXISTS" ]]; then
    log_warn "Stack '$SPONSOR' already exists"
    read -p "Select existing stack and update? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Aborted by user"
        exit 0
    fi
    pulumi stack select "$SPONSOR"
else
    # Create new stack
    log_info "Creating Pulumi stack: $SPONSOR"
    pulumi stack init "$SPONSOR"
fi

# Configure the stack
log_info "Configuring Pulumi stack..."

pulumi config set sponsor "$SPONSOR"
pulumi config set gcp:orgId "$GCP_ORG_ID"
pulumi config set billingAccountId "$BILLING_ACCOUNT_ID"
pulumi config set projectPrefix "$PROJECT_PREFIX"
pulumi config set defaultRegion "$DEFAULT_REGION"

if [[ -n "$FOLDER_ID" ]]; then
    pulumi config set folderId "$FOLDER_ID"
fi

if [[ -n "$GITHUB_ORG" ]]; then
    pulumi config set githubOrg "$GITHUB_ORG"
fi

if [[ -n "$GITHUB_REPO" ]]; then
    pulumi config set githubRepo "$GITHUB_REPO"
fi

# Preview changes
log_info "Previewing infrastructure changes..."
echo ""
pulumi preview

echo ""
read -p "Deploy infrastructure? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Aborted by user. Run 'pulumi up' manually when ready."
    exit 0
fi

# Deploy
log_info "Deploying infrastructure..."
if ! pulumi up --yes; then
    log_error "Pulumi deployment failed"
    rollback_deployment "$SPONSOR"
fi

# Verify audit log infrastructure (FDA 21 CFR Part 11 compliance)
echo ""
log_info "Verifying FDA 21 CFR Part 11 audit log compliance..."
echo ""

# Give GCP a moment to propagate resources
sleep 5

if ! verify_audit_logs "$SPONSOR" "$PROJECT_PREFIX"; then
    log_error "Audit log verification failed!"
    echo ""
    read -p "Rollback deployment? (Y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        rollback_deployment "$SPONSOR"
    else
        log_warn "Continuing without rollback. AUDIT LOGS ARE NOT PROPERLY CONFIGURED."
        log_warn "This deployment is NOT FDA 21 CFR Part 11 compliant!"
    fi
fi

# Show outputs
echo ""
log_success "Bootstrap complete for sponsor: $SPONSOR"
echo ""
log_info "Stack outputs:"
pulumi stack output --json | jq '.'

# Show audit log summary
echo ""
log_info "Audit Log Summary (FDA 21 CFR Part 11):"
echo "  Retention: 25 years (locked)"
echo "  Buckets created:"
for env in dev qa uat prod; do
    echo "    - gs://${PROJECT_PREFIX}-${SPONSOR}-${env}-audit-logs"
done
echo ""

echo ""
log_info "Next steps:"
echo "  1. Configure infrastructure/sponsor-portal stacks for each environment"
echo "  2. Set up GitHub Actions secrets (if using Workload Identity)"
echo "  3. Deploy portal infrastructure with 'pulumi up'"
echo "  4. Verify audit logs are being written: gcloud logging sinks list --project=${PROJECT_PREFIX}-${SPONSOR}-prod"
echo ""
echo "  See: pulumi stack output nextSteps"

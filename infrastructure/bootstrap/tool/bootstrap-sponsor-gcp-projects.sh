#!/usr/bin/env bash
#
# Bootstrap GCP Projects for a New Sponsor
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Pulumi IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model
#
# Usage:
#   ./bootstrap-sponsor-gcp-projects.sh <config-file.json>
#
# Example:
#   ./bootstrap-sponsor-gcp-projects.sh ./sponsor-configs/acme.json
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
pulumi up --yes

# Show outputs
echo ""
log_success "Bootstrap complete for sponsor: $SPONSOR"
echo ""
log_info "Stack outputs:"
pulumi stack output --json | jq '.'

echo ""
log_info "Next steps:"
echo "  1. Configure infrastructure/sponsor-portal stacks for each environment"
echo "  2. Set up GitHub Actions secrets (if using Workload Identity)"
echo "  3. Deploy portal infrastructure with 'pulumi up'"
echo ""
echo "  See: pulumi stack output nextSteps"

#!/bin/bash
# common.sh - Shared functions for Terraform orchestration scripts
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

readonly TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly STATE_BUCKET="cure-hht-terraform-state"
readonly DEFAULT_REGION="europe-west9"

# Environment offset function (compatible with Bash 3.x on macOS)
# Returns the VPC CIDR offset for each environment
get_env_offset() {
    local env="$1"
    case "$env" in
        dev)  echo 0 ;;
        qa)   echo 64 ;;
        uat)  echo 128 ;;
        prod) echo 192 ;;
        *)    echo 0 ;;
    esac
}

# =============================================================================
# Colors and Logging
# =============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

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
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_sponsor_name() {
    local sponsor="$1"

    if [[ -z "$sponsor" ]]; then
        log_error "Sponsor name is required"
        return 1
    fi

    if [[ ! "$sponsor" =~ ^[a-z][a-z0-9-]*$ ]]; then
        log_error "Invalid sponsor name: '$sponsor'"
        log_error "Must be lowercase, start with letter, contain only alphanumeric and hyphens"
        return 1
    fi

    if [[ ${#sponsor} -gt 20 ]]; then
        log_error "Sponsor name too long (max 20 characters): '$sponsor'"
        return 1
    fi

    return 0
}

validate_environment() {
    local env="$1"

    if [[ -z "$env" ]]; then
        log_error "Environment is required"
        return 1
    fi

    case "$env" in
        dev|qa|uat|prod)
            return 0
            ;;
        *)
            log_error "Invalid environment: '$env'"
            log_error "Must be one of: dev, qa, uat, prod"
            return 1
            ;;
    esac
}

validate_sponsor_id() {
    local sponsor_id="$1"

    if [[ -z "$sponsor_id" ]]; then
        log_error "Sponsor ID is required"
        return 1
    fi

    if [[ ! "$sponsor_id" =~ ^[0-9]+$ ]]; then
        log_error "Sponsor ID must be a number: '$sponsor_id'"
        return 1
    fi

    if [[ "$sponsor_id" -lt 1 || "$sponsor_id" -gt 254 ]]; then
        log_error "Sponsor ID must be between 1 and 254: '$sponsor_id'"
        return 1
    fi

    return 0
}

# =============================================================================
# Doppler/Environment Functions
# =============================================================================

check_doppler_env() {
    # Check if running under Doppler or if GCP credentials are available
    if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
        log_info "Using GOOGLE_APPLICATION_CREDENTIALS"
        return 0
    fi

    if [[ -n "${CLOUDSDK_AUTH_ACCESS_TOKEN:-}" ]]; then
        log_info "Using CLOUDSDK_AUTH_ACCESS_TOKEN"
        return 0
    fi

    # Check if gcloud is authenticated
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
        log_info "Using gcloud application default credentials"
        return 0
    fi

    log_error "No GCP credentials found"
    log_error "Run with: doppler run -- $0 ..."
    log_error "Or authenticate with: gcloud auth application-default login"
    return 1
}

# =============================================================================
# Terraform Functions
# =============================================================================

terraform_init() {
    local state_prefix="$1"
    local working_dir="${2:-$(pwd)}"

    log_step "Initializing Terraform with state prefix: $state_prefix"

    (
        cd "$working_dir"
        terraform init \
            -backend-config="bucket=${STATE_BUCKET}" \
            -backend-config="prefix=${state_prefix}" \
            -reconfigure
    )
}

terraform_plan() {
    local tfvars_file="$1"
    local working_dir="${2:-$(pwd)}"
    local plan_file="${3:-tfplan}"

    log_step "Planning Terraform changes..."

    (
        cd "$working_dir"
        terraform plan \
            -var-file="$tfvars_file" \
            -out="$plan_file"
    )
}

terraform_apply() {
    local plan_file="${1:-tfplan}"
    local working_dir="${2:-$(pwd)}"

    log_step "Applying Terraform changes..."

    (
        cd "$working_dir"
        terraform apply "$plan_file"
        rm -f "$plan_file"
    )
}

terraform_destroy() {
    local tfvars_file="$1"
    local working_dir="${2:-$(pwd)}"

    log_warn "Destroying Terraform resources..."

    (
        cd "$working_dir"
        terraform destroy \
            -var-file="$tfvars_file"
    )
}

# =============================================================================
# VPC CIDR Calculation Functions
# =============================================================================

# Calculate VPC CIDR for a sponsor/environment
# Usage: get_vpc_cidr <sponsor_id> <environment>
# Returns: e.g., "10.1.192.0/18" for sponsor_id=1, env=prod
get_vpc_cidr() {
    local sponsor_id="$1"
    local env="$2"
    local offset
    offset=$(get_env_offset "$env")

    echo "10.${sponsor_id}.${offset}.0/18"
}

# Calculate app subnet CIDR
# Usage: get_app_subnet_cidr <sponsor_id> <environment>
get_app_subnet_cidr() {
    local sponsor_id="$1"
    local env="$2"
    local offset
    offset=$(get_env_offset "$env")

    echo "10.${sponsor_id}.${offset}.0/22"
}

# Calculate database subnet CIDR
# Usage: get_db_subnet_cidr <sponsor_id> <environment>
get_db_subnet_cidr() {
    local sponsor_id="$1"
    local env="$2"
    local offset
    offset=$(get_env_offset "$env")
    local db_offset=$((offset + 4))

    echo "10.${sponsor_id}.${db_offset}.0/22"
}

# Calculate EDC peering subnet CIDR
# Usage: get_edc_subnet_cidr <sponsor_id> <environment>
get_edc_subnet_cidr() {
    local sponsor_id="$1"
    local env="$2"
    local offset
    offset=$(get_env_offset "$env")
    local edc_offset=$((offset + 8))

    echo "10.${sponsor_id}.${edc_offset}.0/22"
}

# Calculate VPC connector CIDR (must be /28)
# Usage: get_connector_cidr <sponsor_id> <environment>
get_connector_cidr() {
    local sponsor_id="$1"
    local env="$2"
    local offset
    offset=$(get_env_offset "$env")
    local connector_offset=$((offset + 12))

    echo "10.${sponsor_id}.${connector_offset}.0/28"
}

# =============================================================================
# GCP Helper Functions
# =============================================================================

get_project_id() {
    local prefix="$1"
    local sponsor="$2"
    local env="$3"

    echo "${prefix}-${sponsor}-${env}"
}

check_project_exists() {
    local project_id="$1"

    if gcloud projects describe "$project_id" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Confirmation Functions
# =============================================================================

confirm_action() {
    local message="${1:-Are you sure?}"
    local default="${2:-n}"

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="$message [Y/n] "
    else
        prompt="$message [y/N] "
    fi

    read -p "$prompt" -n 1 -r
    echo

    if [[ "$default" == "y" ]]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

confirm_destructive_action() {
    local resource="$1"

    log_warn "This will DESTROY: $resource"
    log_warn "This action cannot be undone!"
    echo
    read -p "Type 'yes' to confirm: " confirm

    [[ "$confirm" == "yes" ]]
}

# =============================================================================
# Output Functions
# =============================================================================

print_separator() {
    echo "============================================================"
}

print_header() {
    local title="$1"
    echo
    print_separator
    echo "$title"
    print_separator
}

print_next_steps() {
    local -a steps=("$@")

    echo
    log_info "Next steps:"
    for i in "${!steps[@]}"; do
        echo "  $((i+1)). ${steps[$i]}"
    done
}

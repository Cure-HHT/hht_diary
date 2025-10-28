#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#   REQ-d00029: Cross-Platform Development Support
#
# Clinical Diary Development Environment Setup
# Cross-platform setup script for Docker-based development environments
#
# Usage:
#   ./setup.sh              # Interactive setup
#   ./setup.sh --role dev   # Setup specific role
#   ./setup.sh --help       # Show help

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================================
# Helper Functions
# ============================================================

info() {
  echo -e "${BLUE}ℹ ${NC}$1"
}

success() {
  echo -e "${GREEN}✓${NC} $1"
}

warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

error() {
  echo -e "${RED}✗${NC} $1"
}

# ============================================================
# Check Prerequisites
# ============================================================

check_docker() {
  info "Checking Docker installation..."

  if ! command -v docker &> /dev/null; then
    error "Docker not found. Please install Docker:"
    echo ""
    echo "  • Windows/Mac: https://www.docker.com/products/docker-desktop"
    echo "  • Linux: https://docs.docker.com/engine/install/"
    echo ""
    exit 1
  fi

  success "Docker found: $(docker --version)"

  # Check if Docker daemon is running
  if ! docker info &> /dev/null; then
    error "Docker daemon is not running. Please start Docker Desktop."
    exit 1
  fi

  success "Docker daemon is running"
}

check_docker_compose() {
  info "Checking Docker Compose..."

  if ! docker compose version &> /dev/null; then
    error "Docker Compose not found. Please install Docker Compose v2+"
    exit 1
  fi

  success "Docker Compose found: $(docker compose version)"
}

detect_platform() {
  case "$(uname -s)" in
    Linux*)     PLATFORM="Linux";;
    Darwin*)    PLATFORM="macOS";;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="Windows";;
    *)          PLATFORM="Unknown";;
  esac

  info "Detected platform: $PLATFORM"
}

# ============================================================
# Build Docker Images
# ============================================================

build_base_image() {
  info "Building base image..."
  cd "$SCRIPT_DIR"

  docker build \
    -f docker/base.Dockerfile \
    -t clinical-diary-base:latest \
    docker/

  success "Base image built successfully"
}

build_role_image() {
  local role=$1
  info "Building $role image..."

  docker build \
    -f "docker/${role}.Dockerfile" \
    -t "clinical-diary-${role}:latest" \
    --build-arg BASE_IMAGE_TAG=latest \
    docker/

  success "$role image built successfully"
}

build_all_images() {
  info "Building all Docker images..."
  echo ""

  build_base_image
  echo ""

  for role in dev qa ops mgmt; do
    build_role_image "$role"
    echo ""
  done

  success "All images built successfully!"
}

# ============================================================
# Start Services
# ============================================================

start_service() {
  local role=$1
  info "Starting $role container..."

  cd "$SCRIPT_DIR"
  docker compose up -d "$role"

  success "$role container started"
  echo ""
  info "Access container with:"
  echo "  docker compose exec $role bash"
  echo ""
  info "Or use VS Code Dev Containers:"
  echo "  1. Open VS Code"
  echo "  2. Command Palette → 'Dev Containers: Reopen in Container'"
  echo "  3. Select: Clinical Diary - $(echo $role | sed 's/.*/\u&/')"
}

# ============================================================
# Validation
# ============================================================

validate_setup() {
  info "Validating installation..."
  echo ""

  cd "$SCRIPT_DIR"

  # Check if images exist
  for image in clinical-diary-base clinical-diary-dev clinical-diary-qa clinical-diary-ops clinical-diary-mgmt; do
    if docker images "$image:latest" --format "{{.Repository}}" | grep -q "$image"; then
      success "Image exists: $image:latest"
    else
      warning "Image missing: $image:latest"
    fi
  done

  echo ""

  # Check if volumes exist
  for volume in clinical-diary-repos clinical-diary-exchange qa-reports; do
    if docker volume ls --format "{{.Name}}" | grep -q "$volume"; then
      success "Volume exists: $volume"
    else
      info "Volume will be created on first container start: $volume"
    fi
  done

  echo ""
  success "Validation complete!"
}

# ============================================================
# Interactive Setup
# ============================================================

interactive_setup() {
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Clinical Diary Development Environment Setup"
  echo "════════════════════════════════════════════════════════════"
  echo ""

  detect_platform
  echo ""

  check_docker
  echo ""

  check_docker_compose
  echo ""

  info "This will build Docker images for all roles:"
  echo "  • dev  - Developer environment (Flutter, Android SDK)"
  echo "  • qa   - QA environment (Playwright, testing tools)"
  echo "  • ops  - DevOps environment (Terraform, deployment)"
  echo "  • mgmt - Management environment (read-only)"
  echo ""

  read -p "Continue? [Y/n] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
    info "Setup cancelled."
    exit 0
  fi

  build_all_images
  echo ""

  validate_setup
  echo ""

  info "Which role would you like to start? (or press Enter to skip)"
  echo "  1) dev  - Developer"
  echo "  2) qa   - QA/Testing"
  echo "  3) ops  - DevOps"
  echo "  4) mgmt - Management"
  echo ""
  read -p "Select [1-4 or Enter]: " -r choice

  case $choice in
    1) start_service dev;;
    2) start_service qa;;
    3) start_service ops;;
    4) start_service mgmt;;
    "") info "Skipping container start. Start manually with: docker compose up -d <role>";;
    *) warning "Invalid choice. Start manually with: docker compose up -d <role>";;
  esac

  echo ""
  success "Setup complete!"
  echo ""
  info "Next steps:"
  echo "  1. Set up Doppler secrets (see tools/dev-env/doppler-setup.md)"
  echo "  2. Configure Git identity per role"
  echo "  3. Clone repositories into /workspace/repos"
  echo ""
  info "Documentation:"
  echo "  • README: tools/dev-env/README.md"
  echo "  • Doppler: tools/dev-env/doppler-setup.md"
  echo "  • Architecture: docs/dev-environment-architecture.md"
  echo ""
}

# ============================================================
# Main
# ============================================================

show_help() {
  cat <<EOF
Clinical Diary Development Environment Setup

Usage:
  ./setup.sh [OPTIONS]

Options:
  --help              Show this help message
  --role <role>       Build and start specific role (dev|qa|ops|mgmt)
  --build-only        Build images without starting containers
  --validate          Validate installation only
  --rebuild           Rebuild all images from scratch (no cache)

Examples:
  ./setup.sh                 # Interactive setup
  ./setup.sh --role dev      # Build and start dev container
  ./setup.sh --build-only    # Build all images
  ./setup.sh --validate      # Check installation
  ./setup.sh --rebuild       # Rebuild everything

EOF
}

main() {
  case "${1:-}" in
    --help)
      show_help
      ;;
    --role)
      detect_platform
      check_docker
      check_docker_compose
      if [ -z "${2:-}" ]; then
        error "Role not specified. Use: dev, qa, ops, or mgmt"
        exit 1
      fi
      build_base_image
      build_role_image "$2"
      start_service "$2"
      ;;
    --build-only)
      detect_platform
      check_docker
      check_docker_compose
      build_all_images
      validate_setup
      ;;
    --validate)
      detect_platform
      check_docker
      check_docker_compose
      validate_setup
      ;;
    --rebuild)
      detect_platform
      check_docker
      check_docker_compose
      info "Rebuilding all images from scratch..."
      docker compose build --no-cache
      success "Rebuild complete!"
      validate_setup
      ;;
    "")
      interactive_setup
      ;;
    *)
      error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
}

main "$@"

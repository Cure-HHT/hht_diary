#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#   REQ-d00058: Secrets Management via Doppler
#
# Dev Container Pre-Build Check
# Validates that required base images exist before VS Code tries to build
#
# This script is called by devcontainer.json via initializeCommand
# It runs on the HOST (not in container) before build starts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error() {
  echo -e "${RED}✗${NC} $1" >&2
}

warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

success() {
  echo -e "${GREEN}✓${NC} $1"
}

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Dev Container Pre-Build Check"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check 1: Docker is running
info "Checking Docker daemon..."
if ! docker info &> /dev/null; then
  error "Docker daemon is not running"
  echo ""
  echo "  Please start Docker Desktop and try again."
  echo ""
  exit 1
fi
success "Docker daemon is running"

# Check 2: Base image exists
info "Checking for base Docker image..."
if docker images clinical-diary-base:latest --format "{{.Repository}}" | grep -q "clinical-diary-base"; then
  success "Base image 'clinical-diary-base:latest' found"
else
  error "Base image 'clinical-diary-base:latest' NOT FOUND"
  echo ""
  echo "  ⚠️  FIRST-TIME SETUP REQUIRED"
  echo ""
  echo "  You must run the setup script before opening in Dev Container:"
  echo ""
  echo "    1. Close VS Code"
  echo "    2. cd tools/dev-env"
  echo "    3. ./setup.sh"
  echo "    4. Wait for completion (5-15 minutes)"
  echo "    5. Reopen in VS Code Dev Container"
  echo ""
  echo "  Documentation: .devcontainer/README.md"
  echo "  Setup guide: tools/dev-env/README.md"
  echo ""
  exit 1
fi

# Check 3: Doppler authentication (warning only, not blocking)
info "Checking Doppler authentication..."
if command -v doppler &> /dev/null; then
  if doppler whoami &> /dev/null 2>&1; then
    success "Doppler is authenticated"
  else
    warning "Doppler CLI found but not authenticated"
    echo "  Run: doppler login"
    echo "  This is recommended for accessing secrets in containers."
    echo ""
  fi
else
  warning "Doppler CLI not found"
  echo "  Install: https://docs.doppler.com/docs/install-cli"
  echo "  This is recommended for secrets management."
  echo ""
fi

# Check 4: GHCR authentication (info only)
info "Checking GHCR authentication..."
if docker-credential-desktop.exe get <<< "ghcr.io" &> /dev/null 2>&1 || \
   docker-credential-secretservice get <<< "ghcr.io" &> /dev/null 2>&1 || \
   grep -q "ghcr.io" ~/.docker/config.json 2>/dev/null; then
  success "GHCR authentication found (faster builds enabled)"
else
  info "GHCR authentication not found (builds will be slower)"
  echo "  Optional: Authenticate for faster builds with cached layers"
  echo "  See: .devcontainer/README.md - Step 4"
  echo ""
fi

echo ""
success "All critical checks passed!"
echo ""
echo "  Dev Container can now start successfully."
echo ""

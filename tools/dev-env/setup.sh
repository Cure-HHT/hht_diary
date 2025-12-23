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

check_environment() {
  info "Checking environment variables..."

  # Check for HOME environment variable (needed for volume mounts)
  if [ -z "${HOME:-}" ]; then
    error "HOME environment variable is not set."
    echo "  This is required for mounting SSH keys and git config."
    echo "  Please ensure HOME is set in your environment."
    exit 1
  fi

  # Fix .gitconfig if it's a directory (Docker mount issue)
  if [ -d "${HOME}/.gitconfig" ]; then
    warning "~/.gitconfig is a directory (likely created by Docker mount)"
    echo "  Docker creates directories for missing mount targets."
    echo "  Fixing by creating proper .gitconfig file..."
    rmdir "${HOME}/.gitconfig" 2>/dev/null || {
      error "Failed to remove .gitconfig directory (not empty)"
      echo "  Please manually fix: rm -rf ~/.gitconfig && touch ~/.gitconfig"
      exit 1
    }
    # Create basic gitconfig
    cat > "${HOME}/.gitconfig" << 'EOF'
[user]
	name = Developer
	email = dev@example.com
[init]
	defaultBranch = main
[pull]
	rebase = false
[core]
	editor = vim
EOF
    success "Created ~/.gitconfig (please update name/email)"
  # Create .gitconfig if it doesn't exist
  elif [ ! -f "${HOME}/.gitconfig" ]; then
    info "Creating ~/.gitconfig (required for Docker volume mount)"
    cat > "${HOME}/.gitconfig" << 'EOF'
[user]
	name = Developer
	email = dev@example.com
[init]
	defaultBranch = main
[pull]
	rebase = false
[core]
	editor = vim
EOF
    warning "Created ~/.gitconfig with default values"
    echo "  Please update your name and email with:"
    echo "    git config --global user.name 'Your Name'"
    echo "    git config --global user.email 'your.email@example.com'"
  fi

  success "Environment variables validated"
}

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

check_doppler() {
  info "Checking Doppler CLI (required for secrets management)..."

  if ! command -v doppler &> /dev/null; then
    error "Doppler CLI not found on host system."
    echo ""
    echo "  Doppler is REQUIRED for secrets management in this project."
    echo "  The dev containers will not function properly without it."
    echo ""
    echo "  Installation instructions:"
    echo ""

    if [ "$PLATFORM" = "macOS" ]; then
      echo "  macOS (using Homebrew):"
      echo "    brew install gnupg"
      echo "    brew install dopplerhq/cli/doppler"
      echo ""
    elif [ "$PLATFORM" = "Linux" ]; then
      echo "  Linux (Ubuntu/Debian 22.04+):"
      echo "    sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg"
      echo "    curl -sLf --retry 3 --tlsv1.2 --proto \"=https\" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg"
      echo "    echo \"deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main\" | sudo tee /etc/apt/sources.list.d/doppler-cli.list"
      echo "    sudo apt-get update && sudo apt-get install doppler"
      echo ""
    elif [ "$PLATFORM" = "Windows" ]; then
      echo "  Windows WSL2 (Ubuntu):"
      echo "    # Follow Linux instructions above within WSL2"
      echo "    # Or use shell script method:"
      echo "    mkdir -p \$HOME/bin"
      echo "    curl -Ls --tlsv1.2 --proto \"=https\" --retry 3 https://cli.doppler.com/install.sh | sh -s -- --install-path \$HOME/bin"
      echo ""
    fi

    echo "  Documentation: https://docs.doppler.com/docs/install-cli"
    echo ""
    echo "  After installing, run: doppler login"
    echo ""
    exit 1
  fi

  success "Doppler CLI found: $(doppler --version)"

  # Check if doppler is configured
  if doppler whoami &> /dev/null; then
    success "Doppler is configured and authenticated"
  else
    warning "Doppler CLI found but not authenticated."
    echo "  Run 'doppler login' to authenticate before starting containers."
    echo "  See: tools/dev-env/doppler-setup.md"
    echo ""
    read -p "Continue without Doppler authentication? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      info "Setup cancelled. Please run 'doppler login' and try again."
      exit 1
    fi
    warning "Continuing without Doppler authentication - containers may fail at runtime"
  fi
}

check_ghcr_auth() {
  info "Checking GitHub Container Registry authentication..."

  # The GHCR registry and org used for caching
  local GHCR_ORG="cure-hht"
  local GHCR_TEST_IMAGE="ghcr.io/${GHCR_ORG}/clinical-diary-base:latest"

  # Step 1: Check if credentials exist at all
  local has_credentials=false
  if docker-credential-desktop.exe get <<< "ghcr.io" &> /dev/null 2>&1 || \
     docker-credential-secretservice get <<< "ghcr.io" &> /dev/null 2>&1 || \
     grep -q "ghcr.io" ~/.docker/config.json 2>/dev/null; then
    has_credentials=true
  fi

  if [ "$has_credentials" = false ]; then
    warning "GHCR credentials not found"
    show_ghcr_setup_instructions
    return
  fi

  # Step 2: Verify credentials actually work by checking registry access
  info "  Verifying GHCR credentials work..."

  # Try to inspect the manifest (lightweight check, doesn't download the image)
  if docker manifest inspect "$GHCR_TEST_IMAGE" &> /dev/null; then
    success "GHCR authentication verified (can access ${GHCR_ORG} packages)"
  else
    # Credentials exist but don't work
    warning "GHCR credentials found but NOT WORKING"
    echo ""
    echo "  Your Docker has ghcr.io credentials stored, but they failed to"
    echo "  access the ${GHCR_ORG} container registry."
    echo ""
    echo "  Possible causes:"
    echo "    • Token has expired"
    echo "    • Token doesn't have 'read:packages' scope"
    echo "    • Token is for a different GitHub account"
    echo "    • You don't have access to the ${GHCR_ORG} organization"
    echo ""
    echo "  To fix this:"
    echo ""
    echo "  1. Log out of GHCR:"
    echo "     docker logout ghcr.io"
    echo ""
    echo "  2. Create a new GitHub PAT with 'read:packages' scope:"
    echo "     https://github.com/settings/tokens/new"
    echo ""
    echo "  3. Log in again:"
    echo "     echo YOUR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin"
    echo ""
    echo "  4. Re-run this setup script"
    echo ""

    read -p "Continue without working GHCR auth? Builds will be slower. [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
      info "Setup cancelled. Please fix GHCR authentication and try again."
      exit 1
    fi
    warning "Continuing with broken GHCR auth - builds will show cache errors and be slower"
  fi
}

show_ghcr_setup_instructions() {
  echo ""
  echo "  GitHub Container Registry (GHCR) authentication is recommended for:"
  echo "    • Faster builds using cached layers from CI/CD"
  echo "    • Pulling pre-built images instead of building from scratch"
  echo ""
  echo "  To authenticate with GHCR:"
  echo ""
  echo "  1. Create GitHub Personal Access Token (PAT):"
  echo "     • Go to: https://github.com/settings/tokens/new"
  echo "     • Name: 'GHCR Access for Clinical Diary'"
  echo "     • Expiration: 90 days (or longer)"
  echo "     • Scopes: Select 'read:packages'"
  echo "     • Click 'Generate token' and copy it"
  echo ""
  echo "  2. Store token in Doppler:"
  echo "     doppler secrets set GITHUB_TOKEN"
  echo "     # Paste your token when prompted"
  echo ""
  echo "  3. Authenticate Docker with GHCR using Doppler:"
  echo "     doppler run -- bash -c 'echo \$GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin'"
  echo ""
  echo "  4. Verify authentication:"
  echo "     docker pull ghcr.io/cure-hht/clinical-diary-base:latest || echo 'Failed to pull'"
  echo ""
  echo "  Note: The GITHUB_TOKEN will be available in all Doppler-managed environments."
  echo ""

  read -p "Continue without GHCR authentication? Builds will be slower. [Y/n] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
    info "Setup cancelled. Please authenticate with GHCR and try again."
    exit 1
  fi
  warning "Continuing without GHCR - builds will take longer and use no cache"
}

check_node() {
  info "Checking Node.js installation..."

  if ! command -v node &> /dev/null; then
    error "Node.js not found on host system."
    echo ""
    echo "  Node.js is required for running development tools and scripts."
    echo ""
    echo "  Installation instructions:"
    if [ "$PLATFORM" = "macOS" ]; then
      echo "  • Homebrew: brew install node"
      echo "  • Official installer: https://nodejs.org/"
      echo "  • nvm (recommended): https://github.com/nvm-sh/nvm"
    elif [ "$PLATFORM" = "Linux" ]; then
      echo "  • Ubuntu/Debian: sudo apt-get install nodejs npm"
      echo "  • Using nvm (recommended): https://github.com/nvm-sh/nvm"
    else
      echo "  • Official installer: https://nodejs.org/"
      echo "  • nvm (recommended): https://github.com/nvm-sh/nvm"
    fi
    echo ""
    exit 1
  fi

  local node_version=$(node --version)
  local npm_version=$(npm --version 2>/dev/null || echo "not found")

  success "Node.js found: $node_version"

  if [ "$npm_version" != "not found" ]; then
    success "npm found: v$npm_version"
  else
    warning "npm not found. Node.js is installed but npm is missing."
    echo "  Install npm or use a complete Node.js installation."
  fi

  # Check minimum Node.js version (v18+)
  local major_version=$(echo "$node_version" | sed 's/v\([0-9]*\).*/\1/')
  if [ "$major_version" -lt 18 ]; then
    warning "Node.js version $node_version is older than recommended (v18+)"
    echo "  Consider upgrading for better compatibility."
  fi
}

check_gitleaks() {
  info "Checking gitleaks (required for secret scanning in pre-commit hooks)..."

  # Load pinned version from versions.env if available
  local expected_version="${GITLEAKS_VERSION:-8.29.0}"

  if ! command -v gitleaks &> /dev/null; then
    warning "gitleaks not found on host system."
    echo ""
    echo "  gitleaks is REQUIRED for secret scanning in git pre-commit hooks."
    echo "  Without it, commits will proceed without secret detection."
    echo ""

    # Offer to install automatically
    echo "  Options:"
    echo "    1) Install automatically (version $expected_version)"
    echo "    2) Show manual installation instructions"
    echo "    3) Continue without gitleaks (not recommended)"
    echo ""
    read -p "  Select [1-3]: " -r choice
    echo ""

    case $choice in
      1)
        # Automatic installation
        install_gitleaks "$expected_version"
        ;;
      2)
        # Show manual instructions
        echo "  Installation instructions (version $expected_version):"
        echo ""
        if [ "$PLATFORM" = "macOS" ]; then
          echo "  macOS (using Homebrew):"
          echo "    brew install gitleaks"
          echo ""
        elif [ "$PLATFORM" = "Linux" ]; then
          echo "  Linux (download binary):"
          echo "    GITLEAKS_VERSION=$expected_version"
          echo "    curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v\${GITLEAKS_VERSION}/gitleaks_\${GITLEAKS_VERSION}_linux_x64.tar.gz | sudo tar -xz -C /usr/local/bin gitleaks"
          echo ""
          echo "  Or using Go:"
          echo "    go install github.com/gitleaks/gitleaks/v8@v$expected_version"
          echo ""
        elif [ "$PLATFORM" = "Windows" ]; then
          echo "  Windows WSL2:"
          echo "    # Follow Linux instructions above within WSL2"
          echo "    # Or use scoop in Windows:"
          echo "    scoop install gitleaks"
          echo ""
        fi
        echo "  Documentation: https://github.com/gitleaks/gitleaks"
        echo ""
        info "Setup cancelled. Please install gitleaks and run setup again."
        exit 1
        ;;
      3)
        warning "Continuing without gitleaks - pre-commit hooks will skip secret scanning"
        ;;
      *)
        warning "Invalid choice. Continuing without gitleaks - pre-commit hooks will skip secret scanning"
        ;;
    esac
  else
    local installed_version=$(gitleaks version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    success "gitleaks found: v${installed_version:-unknown}"

    # Version comparison (warn if different from pinned)
    if [ -n "$installed_version" ] && [ "$installed_version" != "$expected_version" ]; then
      warning "Installed version ($installed_version) differs from pinned version ($expected_version)"
      echo "  This may cause inconsistent behavior with CI/CD."
      echo "  Consider updating: https://github.com/gitleaks/gitleaks/releases/tag/v$expected_version"
    fi
  fi
}

install_gitleaks() {
  local version=$1
  info "Installing gitleaks v$version..."

  if [ "$PLATFORM" = "macOS" ]; then
    if command -v brew &> /dev/null; then
      info "Installing via Homebrew..."
      if brew install gitleaks; then
        success "gitleaks installed successfully"
      else
        error "Failed to install gitleaks via Homebrew"
        exit 1
      fi
    else
      error "Homebrew not found. Please install Homebrew first: https://brew.sh"
      exit 1
    fi

  elif [ "$PLATFORM" = "Linux" ]; then
    info "Downloading gitleaks binary..."
    local tmp_dir=$(mktemp -d)
    local tar_file="$tmp_dir/gitleaks.tar.gz"
    local download_url="https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_linux_x64.tar.gz"

    if curl -sSfL "$download_url" -o "$tar_file"; then
      info "Extracting to /usr/local/bin (requires sudo)..."
      if sudo tar -xzf "$tar_file" -C /usr/local/bin gitleaks; then
        rm -rf "$tmp_dir"
        success "gitleaks installed successfully"
      else
        rm -rf "$tmp_dir"
        error "Failed to extract gitleaks"
        exit 1
      fi
    else
      rm -rf "$tmp_dir"
      error "Failed to download gitleaks from $download_url"
      exit 1
    fi

  elif [ "$PLATFORM" = "Windows" ]; then
    # In WSL2, use Linux installation
    if grep -qi microsoft /proc/version 2>/dev/null; then
      info "Detected WSL2 - using Linux installation method..."
      PLATFORM="Linux"
      install_gitleaks "$version"
      return
    else
      error "Automatic installation not supported on native Windows."
      echo "  Please use scoop: scoop install gitleaks"
      echo "  Or install manually: https://github.com/gitleaks/gitleaks"
      exit 1
    fi

  else
    error "Automatic installation not supported for platform: $PLATFORM"
    exit 1
  fi

  # Verify installation
  if command -v gitleaks &> /dev/null; then
    local installed_version=$(gitleaks version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    success "Verified: gitleaks v${installed_version:-unknown} is now available"
  else
    error "Installation completed but gitleaks not found in PATH"
    exit 1
  fi
}

# ============================================================
# Build Docker Images
# ============================================================

build_base_image() {
  info "Building base image..."
  cd "$SCRIPT_DIR"

  # On macOS, force linux/amd64 platform for Flutter compatibility
  local platform_flag=""
  if [ "$PLATFORM" = "macOS" ]; then
    platform_flag="--platform linux/amd64"
    info "Building for linux/amd64 (required for Flutter on Apple Silicon)"
  fi

  docker build \
    $platform_flag \
    -f docker/base.Dockerfile \
    -t clinical-diary-base:latest \
    docker/

  success "Base image built successfully"
}

build_role_image() {
  local role=$1
  info "Building $role image..."

  # Check if base image exists
  if ! docker images clinical-diary-base:latest --format "{{.Repository}}" | grep -q "clinical-diary-base"; then
    error "Base image 'clinical-diary-base:latest' not found!"
    echo "  Please build the base image first with:"
    echo "  ./setup.sh --build-only"
    exit 1
  fi

  # On macOS, force linux/amd64 platform for Flutter compatibility
  local platform_flag=""
  if [ "$PLATFORM" = "macOS" ]; then
    platform_flag="--platform linux/amd64"
  fi

  docker build \
    $platform_flag \
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
  # Use bash parameter expansion for cross-platform uppercase (works on macOS BSD and Linux GNU)
  role_upper="$(tr '[:lower:]' '[:upper:]' <<< ${role:0:1})${role:1}"
  echo "  3. Select: Clinical Diary - $role_upper"
}

# ============================================================
# Management Commands
# ============================================================

show_status() {
  info "Checking container status..."
  echo ""

  cd "$SCRIPT_DIR"

  # Show running containers
  echo "Running Containers:"
  docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  No containers running"
  echo ""

  # Show images
  echo "Built Images:"
  for image in clinical-diary-base clinical-diary-dev clinical-diary-qa clinical-diary-ops clinical-diary-mgmt; do
    if docker images "$image:latest" --format "{{.Repository}}:{{.Tag}} ({{.Size}})" | grep -q "$image"; then
      echo "  ✓ $(docker images "$image:latest" --format "{{.Repository}}:{{.Tag}} - {{.Size}}")"
    else
      echo "  ✗ $image:latest - Not built"
    fi
  done
  echo ""

  # Show volumes
  echo "Volumes:"
  for volume in clinical-diary-repos clinical-diary-exchange qa-reports; do
    if docker volume ls --format "{{.Name}}" | grep -q "^${volume}$"; then
      size=$(docker system df -v --format "{{.Name}} {{.Size}}" | grep "$volume" | awk '{print $2}' || echo "unknown")
      echo "  ✓ $volume ($size)"
    else
      echo "  ✗ $volume - Not created"
    fi
  done
  echo ""
}

cleanup_all() {
  warning "This will remove ALL Clinical Diary containers, images, and volumes!"
  echo ""
  echo "  • All containers (dev, qa, ops, mgmt)"
  echo "  • All images (base + role images)"
  echo "  • All volumes (repos, exchange, reports)"
  echo ""
  read -p "Are you sure? Type 'yes' to confirm: " -r
  echo ""

  if [ "$REPLY" != "yes" ]; then
    info "Cleanup cancelled."
    return 0
  fi

  cd "$SCRIPT_DIR"

  info "Stopping and removing containers..."
  docker compose down 2>/dev/null || true
  success "Containers removed"

  info "Removing images..."
  for image in clinical-diary-base clinical-diary-dev clinical-diary-qa clinical-diary-ops clinical-diary-mgmt; do
    docker rmi "${image}:latest" 2>/dev/null && success "Removed $image" || warning "$image not found"
  done

  info "Removing volumes..."
  for volume in clinical-diary-repos clinical-diary-exchange qa-reports; do
    docker volume rm "$volume" 2>/dev/null && success "Removed $volume" || warning "$volume not found"
  done

  echo ""
  success "Cleanup complete!"
}

backup_volumes() {
  local backup_dir="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_path="$backup_dir/volumes_$timestamp"

  info "Backing up volumes to: $backup_path"
  mkdir -p "$backup_path"

  for volume in clinical-diary-repos clinical-diary-exchange qa-reports; do
    if docker volume ls --format "{{.Name}}" | grep -q "^${volume}$"; then
      info "Backing up $volume..."
      docker run --rm \
        -v "$volume:/source:ro" \
        -v "$backup_path:/backup" \
        ubuntu:24.04 \
        tar czf "/backup/${volume}.tar.gz" -C /source . 2>/dev/null || true
      success "Backed up $volume"
    fi
  done

  echo ""
  success "Backup complete: $backup_path"
  echo "  To restore: docker run --rm -v <volume>:/dest -v $backup_path:/backup ubuntu:24.04 tar xzf /backup/<volume>.tar.gz -C /dest"
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
  local dry_run=${1:-false}

  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Clinical Diary Development Environment Setup"
  if [ "$dry_run" = true ]; then
    echo "  [DRY RUN MODE - No changes will be made]"
  fi
  echo "════════════════════════════════════════════════════════════"
  echo ""

  check_environment
  echo ""

  detect_platform
  echo ""

  check_docker
  echo ""

  check_docker_compose
  echo ""

  check_node
  echo ""

  check_gitleaks
  echo ""

  check_doppler
  echo ""

  check_ghcr_auth
  echo ""

  info "This will build Docker images for all roles:"
  echo "  • dev  - Developer environment (Flutter, Android SDK)"
  echo "  • qa   - QA environment (Playwright, testing tools)"
  echo "  • ops  - DevOps environment (Terraform, deployment)"
  echo "  • mgmt - Management environment (read-only)"
  echo ""

  if [ "$dry_run" = true ]; then
    info "DRY RUN: Would build images but skipping in dry-run mode"
    echo ""
    validate_setup
    echo ""
    info "Dry run complete. Run without --dry-run to actually build images."
    return 0
  fi

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
  --dry-run           Preview setup without making changes
  --status            Show status of containers, images, and volumes
  --cleanup           Remove all containers, images, and volumes
  --backup            Backup all volumes to PROJECT_ROOT/backups

Environment Variables:
  BACKUP_DIR          Custom backup directory (default: PROJECT_ROOT/backups)

Examples:
  ./setup.sh                 # Interactive setup
  ./setup.sh --dry-run       # Preview without building
  ./setup.sh --role dev      # Build and start dev container
  ./setup.sh --build-only    # Build all images
  ./setup.sh --validate      # Check installation
  ./setup.sh --status        # Show current status
  ./setup.sh --backup        # Backup volumes before rebuild
  ./setup.sh --rebuild       # Rebuild everything
  ./setup.sh --cleanup       # Clean up everything

EOF
}

main() {
  case "${1:-}" in
    --help)
      show_help
      ;;
    --role)
      check_environment
      detect_platform
      check_docker
      check_docker_compose
      check_node
      check_gitleaks
      if [ -z "${2:-}" ]; then
        error "Role not specified. Use: dev, qa, ops, or mgmt"
        exit 1
      fi
      build_base_image
      build_role_image "$2"
      start_service "$2"
      ;;
    --build-only)
      check_environment
      detect_platform
      check_docker
      check_docker_compose
      check_node
      check_gitleaks
      build_all_images
      validate_setup
      ;;
    --validate)
      check_environment
      detect_platform
      check_docker
      check_docker_compose
      check_node
      check_gitleaks
      validate_setup
      ;;
    --rebuild)
      check_environment
      detect_platform
      check_docker
      check_docker_compose
      check_node
      check_gitleaks
      info "Backing up volumes before rebuild..."
      backup_volumes
      echo ""
      info "Rebuilding all images from scratch..."
      # On macOS, force linux/amd64 platform for Flutter compatibility
      if [ "$PLATFORM" = "macOS" ]; then
        export DOCKER_DEFAULT_PLATFORM=linux/amd64
        info "Building for linux/amd64 (required for Flutter on Apple Silicon)"
      fi
      docker compose build --no-cache
      success "Rebuild complete!"
      validate_setup
      ;;
    --dry-run)
      interactive_setup true
      ;;
    --status)
      check_docker
      show_status
      ;;
    --cleanup)
      check_docker
      cleanup_all
      ;;
    --backup)
      check_docker
      backup_volumes
      ;;
    "")
      interactive_setup false
      ;;
    *)
      error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
}

main "$@"

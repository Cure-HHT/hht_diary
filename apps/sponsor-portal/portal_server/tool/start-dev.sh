#!/usr/bin/env bash
# Start all portal services for local development
#
# Usage:
#   ./tool/start-dev.sh           # Start all services
#   ./tool/start-dev.sh --stop    # Stop all services
#   ./tool/start-dev.sh --status  # Check service status
#
# This script starts:
#   - PostgreSQL database (port 5432)
#   - Firebase Auth emulator (port 9099, UI at 4000)
#   - Portal server (port 8080)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../../../.."
DEV_ENV="$REPO_ROOT/tools/dev-env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
  echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
  echo -e "${RED}Error:${NC} $1"
}

check_status() {
  echo ""
  echo "Service Status:"
  echo "==============="

  # PostgreSQL
  if docker ps --format '{{.Names}}' | grep -q 'sponsor-portal-postgres'; then
    echo -e "PostgreSQL:      ${GREEN}Running${NC} (port 5432)"
  else
    echo -e "PostgreSQL:      ${RED}Stopped${NC}"
  fi

  # Firebase Emulator
  if docker ps --format '{{.Names}}' | grep -q 'firebase-emulator'; then
    echo -e "Firebase Auth:   ${GREEN}Running${NC} (port 9099, UI: http://localhost:4000)"
  else
    echo -e "Firebase Auth:   ${RED}Stopped${NC}"
  fi

  # Portal Server (check if port 8080 is in use)
  if lsof -i :8080 -sTCP:LISTEN >/dev/null 2>&1; then
    echo -e "Portal Server:   ${GREEN}Running${NC} (http://localhost:8080)"
  else
    echo -e "Portal Server:   ${RED}Stopped${NC}"
  fi

  echo ""
  echo "Useful URLs:"
  echo "  - Portal API:     http://localhost:8080/health"
  echo "  - Firebase UI:    http://localhost:4000"
  echo "  - Portal UI:      flutter run -d chrome (from portal-ui/)"
}

stop_services() {
  print_status "Stopping services..."

  cd "$DEV_ENV"

  # Stop PostgreSQL
  if docker ps --format '{{.Names}}' | grep -q 'sponsor-portal-postgres'; then
    print_status "Stopping PostgreSQL..."
    doppler run -- docker compose -f docker-compose.db.yml down
  fi

  # Stop Firebase Emulator
  if docker ps --format '{{.Names}}' | grep -q 'firebase-emulator'; then
    print_status "Stopping Firebase Emulator..."
    docker compose -f docker-compose.firebase.yml down
  fi

  print_status "Services stopped"
}

start_services() {
  cd "$DEV_ENV"

  # Ensure network exists
  print_status "Ensuring Docker network exists..."
  docker network create clinical-diary-net 2>/dev/null || true

  # Start PostgreSQL
  print_status "Starting PostgreSQL..."
  doppler run -- docker compose -f docker-compose.db.yml up -d

  # Wait for PostgreSQL to be ready
  print_status "Waiting for PostgreSQL to be ready..."
  for i in {1..30}; do
    if docker exec sponsor-portal-postgres pg_isready -U postgres >/dev/null 2>&1; then
      echo "PostgreSQL is ready"
      break
    fi
    if [ $i -eq 30 ]; then
      print_error "PostgreSQL failed to start"
      exit 1
    fi
    sleep 1
  done

  # Start Firebase Emulator
  print_status "Starting Firebase Auth Emulator..."
  docker compose -f docker-compose.firebase.yml up -d

  # Wait for Firebase to be ready
  print_status "Waiting for Firebase Emulator..."
  for i in {1..30}; do
    if curl -s http://localhost:9099 >/dev/null 2>&1; then
      echo "Firebase Emulator is ready"
      break
    fi
    if [ $i -eq 30 ]; then
      print_warning "Firebase Emulator may still be starting..."
    fi
    sleep 1
  done

  echo ""
  print_status "Infrastructure services started!"
  echo ""
  echo "Next steps:"
  echo "  1. Start the server:  cd portal_server && ./tool/run_local.sh"
  echo "  2. Start the UI:      cd portal-ui && flutter run -d chrome"
  echo "  3. Create test user:  http://localhost:4000 (Authentication tab)"
  echo ""

  check_status
}

# Main
case "${1:-}" in
  --stop)
    stop_services
    ;;
  --status)
    check_status
    ;;
  *)
    start_services
    ;;
esac

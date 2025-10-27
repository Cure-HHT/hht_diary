#!/bin/bash

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Change to the script directory
cd "$(dirname "$0")"

echo "========================================================================"
echo "CREATING LINEAR TICKETS FOR ALL REQUIREMENTS"
echo "========================================================================"
echo ""
echo "This will create 77 Linear tickets (27 PRD, 24 Ops, 26 Dev)"
echo ""
echo "Starting with PRD level (highest priority)..."
echo ""

# Create PRD tickets first (Priority 1)
node create-requirement-tickets.js \
  --token=lin_api_ARNlHwxFV8D5C3zVKQeTByar3B2CK5aNZaegu6CB \
  --team-id=ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe \
  --level=PRD

echo ""
echo "========================================================================"
echo "PRD tickets created. Now creating Ops level tickets..."
echo "========================================================================"
echo ""

# Create Ops tickets (Priority 2)
node create-requirement-tickets.js \
  --token=lin_api_ARNlHwxFV8D5C3zVKQeTByar3B2CK5aNZaegu6CB \
  --team-id=ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe \
  --level=Ops

echo ""
echo "========================================================================"
echo "Ops tickets created. Now creating Dev level tickets..."
echo "========================================================================"
echo ""

# Create Dev tickets (Priority 3)
node create-requirement-tickets.js \
  --token=lin_api_ARNlHwxFV8D5C3zVKQeTByar3B2CK5aNZaegu6CB \
  --team-id=ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe \
  --level=Dev

echo ""
echo "========================================================================"
echo "ALL TICKETS CREATED!"
echo "========================================================================"
echo ""
echo "Next steps:"
echo "  1. Review tickets in Linear"
echo "  2. Organize into projects/milestones"
echo "  3. Assign tickets as needed"
echo ""

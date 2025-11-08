#!/bin/bash

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Change to the script directory
cd "$(dirname "$0")"

# Check for required environment variables
if [ -z "$LINEAR_API_TOKEN" ]; then
    echo "❌ ERROR: LINEAR_API_TOKEN environment variable is required"
    echo ""
    echo "Set it with:"
    echo "  export LINEAR_API_TOKEN=\"your_token_here\""
    echo ""
    echo "Or use secret management:"
    echo "  doppler run -- ./create-tickets.sh"
    exit 1
fi

if [ -z "$LINEAR_TEAM_ID" ]; then
    echo "❌ ERROR: LINEAR_TEAM_ID environment variable is required"
    echo ""
    echo "Set it with:"
    echo "  export LINEAR_TEAM_ID=\"your_team_id_here\""
    exit 1
fi

echo "========================================================================"
echo "CREATING LINEAR TICKETS FOR ALL REQUIREMENTS"
echo "========================================================================"
echo ""
echo "This will create 77 Linear tickets (27 PRD, 24 Ops, 26 Dev)"
echo ""
echo "Starting with PRD level (highest priority)..."
echo ""

# Create PRD tickets first (Priority 1)
# Note: create-requirement-tickets.js reads from environment variables
node create-requirement-tickets.js \
  --level=PRD

echo ""
echo "========================================================================"
echo "PRD tickets created. Now creating Ops level tickets..."
echo "========================================================================"
echo ""

# Create Ops tickets (Priority 2)
node create-requirement-tickets.js \
  --level=Ops

echo ""
echo "========================================================================"
echo "Ops tickets created. Now creating Dev level tickets..."
echo "========================================================================"
echo ""

# Create Dev tickets (Priority 3)
node create-requirement-tickets.js \
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

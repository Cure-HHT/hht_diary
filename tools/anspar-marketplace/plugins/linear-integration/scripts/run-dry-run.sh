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
    echo "  doppler run -- ./run-dry-run.sh"
    exit 1
fi

if [ -z "$LINEAR_TEAM_ID" ]; then
    echo "❌ ERROR: LINEAR_TEAM_ID environment variable is required"
    echo ""
    echo "Set it with:"
    echo "  export LINEAR_TEAM_ID=\"your_team_id_here\""
    exit 1
fi

# Run the create tickets script in dry-run mode
# Note: create-requirement-tickets.js reads from environment variables
node create-requirement-tickets.js \
  --dry-run \
  --level=PRD

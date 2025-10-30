#!/bin/bash

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Change to the script directory
cd "$(dirname "$0")"

echo "========================================================================"
echo "DRY RUN: Creating Linear tickets for ALL requirement levels"
echo "========================================================================"
echo ""

# Run the create tickets script in dry-run mode for all levels
node create-requirement-tickets.js \
  --token=lin_api_ARNlHwxFV8D5C3zVKQeTByar3B2CK5aNZaegu6CB \
  --team-id=ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe \
  --dry-run

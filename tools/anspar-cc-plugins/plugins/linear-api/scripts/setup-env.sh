#!/usr/bin/env bash
#
# Linear Integration Plugin - Environment Setup
#
# This script discovers your LINEAR_TEAM_ID automatically and provides
# commands to export it for use with other linear-integration scripts.
#
# Usage:
#   source tools/anspar-marketplace/plugins/linear-integration/scripts/setup-env.sh
#
# Or to just get the team ID:
#   bash tools/anspar-marketplace/plugins/linear-integration/scripts/setup-env.sh
#

set -eo pipefail

# Check if LINEAR_API_TOKEN is set
if [ -z "$LINEAR_API_TOKEN" ]; then
    echo "Error: LINEAR_API_TOKEN is not set"
    echo ""
    echo "Please set your Linear API token first:"
    echo "  export LINEAR_API_TOKEN='lin_api_...'"
    echo ""
    echo "Get your token from: https://linear.app/settings/api"
    exit 1
fi

echo "Discovering Linear team information..."

# Query Linear API for teams
RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $LINEAR_API_TOKEN" \
  -d '{"query": "query { viewer { organization { teams { nodes { id key name } } } } }"}')

# Check for errors
if echo "$RESPONSE" | grep -q '"errors"'; then
    echo "Error: Failed to query Linear API"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    exit 1
fi

# Parse team information
TEAM_COUNT=$(echo "$RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data['data']['viewer']['organization']['teams']['nodes']))" 2>/dev/null)

if [ "$TEAM_COUNT" -eq 0 ]; then
    echo "Error: No teams found for this Linear account"
    exit 1
fi

if [ "$TEAM_COUNT" -eq 1 ]; then
    # Single team - auto-select
    TEAM_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['data']['viewer']['organization']['teams']['nodes'][0]['id'])" 2>/dev/null)
    TEAM_KEY=$(echo "$RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['data']['viewer']['organization']['teams']['nodes'][0]['key'])" 2>/dev/null)
    TEAM_NAME=$(echo "$RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['data']['viewer']['organization']['teams']['nodes'][0]['name'])" 2>/dev/null)

    echo "✓ Found team: $TEAM_NAME ($TEAM_KEY)"
    echo ""
    echo "LINEAR_TEAM_ID=$TEAM_ID"
    echo ""
    echo "To use this team ID, run:"
    echo "  export LINEAR_TEAM_ID='$TEAM_ID'"
    echo ""
    echo "Or add to your ~/.bashrc or ~/.zshrc:"
    echo "  export LINEAR_TEAM_ID='$TEAM_ID'"

    # If being sourced, export it
    if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
        export LINEAR_TEAM_ID="$TEAM_ID"
        echo ""
        echo "✓ LINEAR_TEAM_ID has been exported for this session"
    fi
else
    # Multiple teams - list them
    echo "Found $TEAM_COUNT teams:"
    echo ""
    echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
teams = data['data']['viewer']['organization']['teams']['nodes']
for i, team in enumerate(teams, 1):
    print(f\"{i}. {team['name']} ({team['key']}) - ID: {team['id']}\")
"
    echo ""
    echo "Please select a team and export its ID manually:"
    echo "  export LINEAR_TEAM_ID='<team-id>'"
fi

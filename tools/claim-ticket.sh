#!/usr/bin/env bash
# User-friendly script to claim a Linear ticket.
# Usage example:
# ./tools/claim-ticket.sh CUR-123
# Can be called from any directory within the repo.

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh" "$1"
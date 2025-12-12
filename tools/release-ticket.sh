#!/usr/bin/env bash
# User-friendly script to release a Linear ticket.
# Usage example:
# ./tools/release-ticket.sh
# ./tools/release-ticket.sh "Switching to different ticket"
# ./tools/release-ticket.sh "Work complete" --pr-number 42 --pr-url https://github.com/org/repo/pull/42
# Can be called from any directory within the repo.

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/anspar-cc-plugins/plugins/workflow/scripts/release-ticket.sh" "$@"

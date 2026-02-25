#!/usr/bin/env bash
# User-friendly script to claim a Linear ticket.
# Usage example:
# ./tools/claim-ticket.sh CUR-123
# Can be called from any directory within the repo.

ANSPAR_PLUGINS="${ANSPAR_WF_PLUGINS:-$HOME/anspar-wf/plugins/plugins}"

"${ANSPAR_PLUGINS}/workflow/scripts/claim-ticket.sh" "$1"

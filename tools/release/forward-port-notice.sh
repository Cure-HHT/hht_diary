#!/usr/bin/env bash
# Announce the forward-port obligation for a hotfix. Read-only w.r.t. git:
# it prints the exact cherry-pick commands a dev should run (in their own
# worktree) and can file a Linear ticket so the obligation is not forgotten.
# It NEVER checks out, branches, or cherry-picks.
# Implements: DIARY-OPS-hotfix-source-recovery/C
set -euo pipefail

usage() { echo "usage: forward-port-notice.sh <fix-sha> <baseline-branch> [--linear]" >&2; exit 2; }
[ $# -ge 2 ] || usage
FIX="$1"; BASELINE="$2"; LINEAR="${3:-}"

git rev-parse --verify "$FIX^{commit}" >/dev/null 2>&1 || {
  echo "::error::'$FIX' is not a valid commit" >&2; exit 1; }
SHORT="$(git rev-parse --short=7 "$FIX")"
SUBJECT="$(git log -1 --format=%s "$FIX")"

read -r -d '' BODY <<EOF || true
Forward-port hotfix ${SHORT} ("${SUBJECT}") to main AND ${BASELINE}.
A hotfix not forward-ported regresses on the next normal build
(DIARY-OPS-hotfix-source-recovery/C — definition-of-done).

Do this in a fresh worktree (keeps your current checkout untouched):

  # onto main
  git worktree add "../fp-${SHORT}-main" main
  git -C "../fp-${SHORT}-main" cherry-pick -x "${FIX}"
  # ...resolve conflicts if any, then push a branch and open a PR

  # onto ${BASELINE}
  git worktree add "../fp-${SHORT}-baseline" "${BASELINE}"
  git -C "../fp-${SHORT}-baseline" cherry-pick -x "${FIX}"
  # ...resolve conflicts if any, then push a branch and open a PR

Open the two as SEPARATE PRs.
EOF

echo "=== FORWARD-PORT REQUIRED ==="
printf '%s\n' "$BODY"
echo "============================="

if [ "$LINEAR" = "--linear" ]; then
  TITLE="[CUR-1552] Forward-port hotfix ${SHORT} to main + ${BASELINE}"
  if [ -n "${LINEAR_API_KEY:-}" ] && [ -n "${LINEAR_TEAM_ID:-}" ]; then
    Q="$(jq -n --arg t "$TITLE" --arg b "$BODY" --arg team "$LINEAR_TEAM_ID" \
      '{query:"mutation($t:String!,$b:String!,$team:String!){issueCreate(input:{title:$t,description:$b,teamId:$team}){success issue{identifier url}}}",
        variables:{t:$t,b:$b,team:$team}}')"
    curl -sS -X POST https://api.linear.app/graphql \
      -H "Authorization: $LINEAR_API_KEY" -H "Content-Type: application/json" \
      -d "$Q" | jq -r '.data.issueCreate.issue | "filed \(.identifier): \(.url)"' || \
      echo "(linear filing failed; file the ticket above manually)"
  else
    echo "(LINEAR_API_KEY / LINEAR_TEAM_ID unset; file this ticket manually:)"
    echo "TITLE: $TITLE"
  fi
fi

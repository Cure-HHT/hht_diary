#!/usr/bin/env bash
# Cut a sponsor-neutral baseline branch from a given source commit.
# Implements: DIARY-OPS-neutral-baseline-branch/A+B
set -euo pipefail

usage() { echo "usage: cut-baseline.sh <version: YYYY-MM[-vN]> <source-sha> [--push]" >&2; exit 2; }
[ $# -ge 2 ] || usage
VERSION="$1"; SOURCE="$2"; PUSH="${3:-}"

# A: version must be date/version-keyed and carry NO sponsor identity.
if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]{4}-[0-9]{2}(-v[0-9]+)?$'; then
  echo "::error::version '$VERSION' must match YYYY-MM[-vN] (sponsor-neutral, date-keyed)" >&2
  exit 1
fi

BRANCH="baseline/$VERSION"
git rev-parse --verify "$SOURCE^{commit}" >/dev/null 2>&1 || {
  echo "::error::source '$SOURCE' is not a valid commit" >&2; exit 1; }

git branch "$BRANCH" "$SOURCE"
echo "created $BRANCH at $(git rev-parse --short "$SOURCE")"
if [ "$PUSH" = "--push" ]; then git push -u origin "$BRANCH"; fi

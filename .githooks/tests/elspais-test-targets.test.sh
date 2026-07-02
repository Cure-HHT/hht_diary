#!/usr/bin/env bash
# Tests for .githooks/elspais-test-targets.sh (CUR-1556).
#
# Builds a throwaway fixture tree (a .elspais.toml with target cwds + a chain of
# pubspecs with local path: deps) and exercises target discovery, the path-dep
# closure, and dependency-aware affected-target selection.
#
# Usage: ./.githooks/tests/elspais-test-targets.test.sh
# Exits 0 on all pass, 1 on any failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../elspais-test-targets.sh
source "$REPO_ROOT/.githooks/elspais-test-targets.sh"

PASS=0
FAIL=0
eq() {
    local actual="$1" expected="$2" label="$3"
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1)); printf '  ok    %s\n' "$label"
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL  %s\n        expected=%q\n        actual=%q\n' "$label" "$expected" "$actual"
    fi
}

# --- _resolve_rel (pure path math) -----------------------------------------
eq "$(_resolve_rel apps/daily-diary/clinical_diary ../../common-dart/foo)" \
   "apps/common-dart/foo" "_resolve_rel collapses .. segments"
eq "$(_resolve_rel apps/a ./b)" "apps/a/b" "_resolve_rel drops ."

# --- fixture tree ----------------------------------------------------------
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/apps/app_a" "$FIX/apps/pkg_b" "$FIX/apps/pkg_c" "$FIX/apps/lonely"

cat > "$FIX/.elspais.toml" <<'EOF'
[scanning.test]
enabled = true

[[scanning.test.targets]]
name = "apps/app_a"
cwd = "apps/app_a"
command = "flutter test"

[[scanning.test.targets]]
name = "apps/lonely"
cwd = "apps/lonely"
command = "flutter test"
EOF

# app_a -> pkg_b -> pkg_c ; lonely has no deps
cat > "$FIX/apps/app_a/pubspec.yaml" <<'EOF'
name: app_a
dependencies:
  pkg_b:
    path: ../pkg_b
EOF
cat > "$FIX/apps/pkg_b/pubspec.yaml" <<'EOF'
name: pkg_b
dependencies:
  pkg_c:
    path: ../pkg_c
EOF
cat > "$FIX/apps/pkg_c/pubspec.yaml" <<'EOF'
name: pkg_c
EOF
cat > "$FIX/apps/lonely/pubspec.yaml" <<'EOF'
name: lonely
EOF

# --- elspais_test_target_dirs ----------------------------------------------
eq "$(elspais_test_target_dirs "$FIX/.elspais.toml")" \
   "$(printf 'apps/app_a\napps/lonely')" "discovers both target cwds"

# --- pkg_path_deps (direct) -------------------------------------------------
eq "$(pkg_path_deps "$FIX" apps/app_a)" "apps/pkg_b" "direct dep of app_a is pkg_b"
eq "$(pkg_path_deps "$FIX" apps/lonely)" "" "lonely has no path deps"

# --- pkg_dep_closure (transitive) ------------------------------------------
eq "$(pkg_dep_closure "$FIX" apps/app_a)" \
   "$(printf 'apps/pkg_b\napps/pkg_c\n')" "app_a closure is pkg_b + pkg_c"

# --- affected_test_targets --------------------------------------------------
# Change deep in transitive dep pkg_c -> app_a is affected, lonely is not.
CHANGED="$(printf 'apps/pkg_c/lib/thing.dart\n')"
eq "$(affected_test_targets "$FIX" "$FIX/.elspais.toml" "$CHANGED")" \
   "apps/app_a" "transitive dep change selects app_a only"

# Change in app_a's own test -> app_a affected.
CHANGED="$(printf 'apps/app_a/test/app_a_test.dart\n')"
eq "$(affected_test_targets "$FIX" "$FIX/.elspais.toml" "$CHANGED")" \
   "apps/app_a" "own test change selects the target"

# Change only in lonely -> only lonely.
CHANGED="$(printf 'apps/lonely/lib/x.dart\n')"
eq "$(affected_test_targets "$FIX" "$FIX/.elspais.toml" "$CHANGED")" \
   "apps/lonely" "isolated change selects only that target"

# Non-dart change (e.g. a README) -> nothing affected.
CHANGED="$(printf 'apps/pkg_c/README.md\n')"
eq "$(affected_test_targets "$FIX" "$FIX/.elspais.toml" "$CHANGED")" \
   "" "non-dart change selects nothing"

echo ""
if [ "$FAIL" -eq 0 ]; then
    printf 'All %d assertions passed.\n' "$PASS"; exit 0
else
    printf '%d passed, %d failed.\n' "$PASS" "$FAIL"; exit 1
fi

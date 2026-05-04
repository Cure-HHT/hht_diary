#!/bin/bash
# Helpers for surfacing elspais output as GitHub Actions annotations.
#
# Sourced by .github/scripts/validate-pr.sh after `elspais checks`.

# emit_suppressed_warnings <elspais_stdout>
# Emits one GitHub Actions warning annotation per "info"-downgraded
# elspais finding, so each CI run reminds the team that the underlying
# repo-wide issue is still outstanding even though it's not blocking.
#
# The downgrade lives in .elspais.toml (`no_traceability_severity = "info"`
# under `[rules.format]`, and `retired = "info"` under `[rules.references]`).
# Without this reminder, the suppression becomes invisible debt.
#
# Currently watches:
#   - code.no_traceability
#   - code.retired_references
#
# Add new entries to the case statement when more checks get downgraded.
emit_suppressed_warnings() {
    local output="$1"
    local line msg
    while IFS= read -r line; do
        case "$line" in
            *"~ code.no_traceability:"*|*"~ code.retired_references:"*)
                msg=$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*~[[:space:]]*//')
                printf '::warning title=Elspais standing issue (suppressed)::%s\n' "$msg"
                ;;
        esac
    done <<< "$output"
}

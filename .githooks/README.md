# Git Hooks

## Overview

This directory contains Git hooks that enforce code quality, requirement
traceability, and version discipline before commits and pushes. The hooks are
checked into the repo and owned by it — no external hook-generator is involved.

## Installation

```bash
git config core.hooksPath .githooks
```

This tells Git to use hooks from `.githooks/` instead of the default `.git/hooks/`.
Run `tools/setup-repo.sh` to set this up automatically alongside other dev tooling.

## Hook Files

### `pre-commit`

Runs before every `git commit`.

**Checks performed:**

1. **Branch protection** — blocks direct commits to `main`/`master`.
2. **Dart code quality** — if `.dart` files changed in `apps/`:
   - Runs `dart format` (auto-formats and re-stages)
   - Runs `dart analyze --fatal-infos` (blocks on any issues)
3. **TypeScript code quality** — if `.ts`/`.tsx` files changed in `apps/`:
   - Runs `npm run lint` (ESLint) for each affected project
4. **Markdown linting** — if `.md` files changed, runs `markdownlint`
5. **Phase design spec check** — validates `docs/superpowers/specs/*-design.md`
   contains `## Requirements` and at least one REQ reference; stubs must include
   a "Requirements: deferred" line or REQ reference.
6. **Auto-bump build numbers** — increments `+N` in `pubspec.yaml` for Dart/Flutter
   projects with source changes; stages bumped files as part of the commit.

**Bypass (NOT RECOMMENDED):**

```bash
git commit --no-verify
```

### `commit-msg`

Enforces that every commit message starts with `[CUR-NNN]`.

Exempt: merge commits, revert commits, fixup/squash commits.

**Bypass (NOT RECOMMENDED):**

```bash
git commit --no-verify
```

### `pre-push`

Runs before every `git push`. Blocking behavior is PR-aware:

- Branch **with** open PR: validation failures **block** the push.
- Branch **without** PR: validation failures show warnings only (push allowed).

**Checks performed** (the version gate runs first, before the slower checks, so
a rebase under-bump is corrected and the push aborted up front):

1. **Version gate** — verifies every changed package has a build-number bump
   vs `origin/main`; auto-commits a correction and aborts so the fix is re-pushed
2. **elspais checks** — `elspais checks --spec --code --terms` (REQ format, links,
   term usage; INDEX accuracy). Version pin enforced: the hook fails fast if the
   installed elspais is older than `ELSPAIS_VERSION` in `.github/versions.env`.
3. **Markdown linting** — runs `markdownlint` on changed `.md` files
4. **Secret detection** — runs `gitleaks` on commits being pushed
5. **Dart dependency resolution** — `flutter pub get` / `dart pub get` per app
6. **Dart format check** — `dart format --output=none --set-exit-if-changed`
7. **Dart static analysis** — `dart analyze --fatal-infos`
8. **Test suites** — runs `tool/test.sh -u` for apps whose source or dependency
   trigger paths have changes (unit tests only)

**Bypass (NOT RECOMMENDED for PR branches):**

```bash
git push --no-verify
```

## Shared Helpers

The following scripts are sourced by the hooks — do not delete or rename them:

| File | Purpose |
| ---- | ------- |
| `version-utils.sh` | `is_merge_commit_in_progress`, `verify_version_bumped_for`, `compute_new_version_for` |
| `project-defs.sh` | `PROJECT_DEFS` array mapping Dart/Flutter package names to pubspec paths, code dirs, trigger paths, and version mode |
| `fetch-cache.sh` | `ensure_main_fresh`, `main_version_for` (SHA-keyed cache), `verify_short_circuit_ok`, `record_verify_pass` — TTL-limited `git fetch origin main` + verify short-circuit state |
| `version-gate.sh` | `run_version_gate` — rebase-proof bump verifier/auto-corrector |

## Opt-Outs

| Mechanism | Effect |
| --------- | ------ |
| `git commit --no-verify` | Bypass all pre-commit and commit-msg checks |
| `git push --no-verify` | Bypass all pre-push checks |

## Fetch-Cache Tunables

`fetch-cache.sh` caches `git fetch origin main` to avoid repeated network calls
during a single session:

| Tunable | Default | Effect |
| ------- | ------- | ------ |
| `HHT_MAIN_FETCH_TTL` | `90` (seconds) | Seconds before the cache is considered stale |
| `HHT_MAIN_FETCH_FORCE=1` | off | Forces a fresh fetch regardless of TTL |

To manually force a cache refresh:

```bash
.githooks/fetch-cache.sh --force
```

## Troubleshooting

### Hook not running

```bash
git config --get core.hooksPath
# Should output: .githooks
```

If not set:

```bash
git config core.hooksPath .githooks
```

### elspais version error

The pre-commit and pre-push hooks check `ELSPAIS_VERSION` from
`.github/versions.env`. If your installed version is older:

```bash
pip install --upgrade elspais
# or: pipx upgrade elspais
# or: brew upgrade elspais  (if installed via brew)
```

### Version gate auto-corrects and aborts

The pre-push version gate may detect that a rebase dropped the version bump,
create a correction commit, and abort the push with:

> Versions were under-bumped vs origin/main and have been corrected in a new
> commit. Run 'git push' again to push the corrected commit.

Simply re-run `git push`.

### Permission denied

Make sure hooks are executable:

```bash
chmod +x .githooks/pre-commit .githooks/commit-msg .githooks/pre-push
```

## Related Documentation

- **Requirement format**: `spec/README.md`, `spec/INDEX.md`
- **Project instructions**: `CLAUDE.md`
- **Version pinning**: `.github/versions.env`

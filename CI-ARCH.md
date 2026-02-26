# CI Architecture

## Principle

Every test, lint, and analysis command runs inside the CI container. Runners do not install tools. The container is the single source of truth for the CI toolchain.

## Container

`tools/dev-env/docker/ci.Dockerfile` builds a Debian 12-slim image containing all CI tools:

| Category | Tools |
| --- | --- |
| Languages | Flutter, Dart, Node.js (pnpm), Python 3.11, OpenJDK 17 |
| Mobile | Android SDK (cmdline-tools, build-tools, platform) |
| Database | PostgreSQL client, Squawk (migration linter) |
| Security | Gitleaks (secret scanning) |
| Cloud | gcloud CLI, Cloud SQL Auth Proxy, Doppler CLI |
| Testing | Playwright, Firebase CLI, lcov, xvfb, dbus, gnome-keyring |
| Reporting | pandoc, junitreport |
| Dev tools | gh CLI, git, jq, build-essential |
| Flutter build deps | libgtk-3-dev, cmake, ninja-build, libblkid-dev, liblzma-dev |
| Runtime-installed | markdownlint-cli, elspais (installed by `validate-pr.sh` at runtime, versions from `versions.env`) |

All versions are pinned in `.github/versions.env` and passed as build args.

The image is published to `ghcr.io/cure-hht/clinical-diary-ci:latest`.

## Image Lifecycle

```
Dockerfile changes?
  yes -> build image, push to GHCR, run tests
  no  -> pull cached image from GHCR, run tests
```

Rebuilds happen only when files under `tools/dev-env/docker/` or `tools/dev-env/docker-compose*` change. All other PRs pull the cached image (~30s).

## Composite Action

`.github/actions/start-ci-container/action.yml` encapsulates the pull-or-build-and-start sequence. Every workflow calls it:

```yaml
- uses: actions/checkout@v4
- uses: ./.github/actions/start-ci-container
    with:
      ghcr-token: ${{ secrets.GITHUB_TOKEN }}
      profile: db  # optional: starts PostgreSQL sidecar
```

The action handles:
1. GHCR login
2. Docker file change detection
3. Disk space cleanup (only when rebuilding)
4. Pull cached image or build + push
5. `docker compose up` with requested profile
6. Health check (Flutter responds, postgres ready if profile=db)

## Docker Compose

`tools/dev-env/docker-compose.ci.yml` overrides the base compose file for CI:

```
services:
  ci        always started, mounts repo at /workspace/src
  postgres  started only with --profile db, reachable at hostname "postgres"
```

Both services share a `ci-net` bridge network.

## Workflow Pattern

Every workflow follows this structure:

```
1. actions/checkout@v4
2. .github/actions/start-ci-container  (pull or build, compose up)
3. docker compose exec ci <commands>   (all testing happens here)
4. Copy artifacts from container to runner (coverage files, reports)
5. GHA-native uploads (artifacts, codecov, SARIF)
6. docker compose down -v             (cleanup, always runs)
```

Commands run inside the container via:
```yaml
- name: Run tests
  working-directory: tools/dev-env
  run: |
    docker compose -f docker-compose.yml -f docker-compose.ci.yml exec -T ci bash -c "
      cd /workspace/src/<package-path>
      dart pub get
      dart test
    "
```

## Workflows

| Workflow | Profile | What Runs in Container |
| --- | --- | --- |
| `trial_data_types-ci` | (none) | `dart format`, `dart analyze`, `dart test` |
| `pr-validation` | (none) | `.github/scripts/validate-pr.sh` (Python, gitleaks) |
| `database-migration` | `db` | `psql` schema deploy, migration rollback tests |
| `diary-server-ci` | `db` | `dart analyze`, `dart test`, integration tests, coverage |
| `clinical_diary-ci` | (none) | `flutter analyze`, `flutter test` under xvfb, coverage |
| `sponsor-portal-ci` | `db` | `dart`/`flutter` analyze + test, Firebase emulator, coverage |
| `qa-automation` (ci-tests) | (none) | `flutter test`, `flutter analyze`, `squawk` |
| `qa-automation` (security-scan) | -- | **Exception**: Trivy runs as GHA action (see below) |

## Scope

This document covers workflows that run tests and validation inside the CI container. The repository also contains workflows for other purposes that are **out of scope** for this document:

- **Build/publish**: `build-ghcr-containers`, `build-dart-base`, `build-flutter-base`, `build-portal-server`, `build-diary-server`
- **Deploy**: `deploy-run-service`, `reset-db-gcp`, `android-dev-deploy`
- **Compliance/Ops**: `claim-requirement-number`, `tag-production-candidate`, `maintenance-check`, `alert-workflow-changes`, `validate-bot-commits`
- **Archival**: `archive-audit-trail`, `archive-artifacts`, `archive-deployment-logs`, `verify-archive-integrity`
- **Other**: `codespaces-prebuild`, `test-gcp-auth`

These workflows run on the runner because they perform deployment, infrastructure, or GitHub API operations that do not need the CI toolchain.

### Known Exceptions — TODO

The following CI workflows currently run **outside** the CI container, violating the core principle. They are tracked for future migration:

- **`append_only_datastore-ci`** — installs Flutter on the runner via `subosito/flutter-action@v2` and uses a matrix build (`stable` + `beta` channels). Migration to the CI container will require dropping beta-channel testing or maintaining separate container tags.
- **`append_only_datastore-coverage`** — installs Flutter + lcov on the runner. Same migration path as above.
- **`android-dev-deploy`** — installs Java and Flutter on the runner to build APKs. As a deploy workflow this is lower priority, but should eventually use the CI container for the build step.

## The Trivy Exception

Trivy is the only tool that does not run inside the container. It runs as a GHA action (`aquasecurity/trivy-action`) because it needs to scan the container image from outside. It performs three scans:

1. **Filesystem** -- dependency vulnerabilities (npm, pub, pip)
2. **IaC** -- Dockerfile, Terraform, K8s misconfigurations
3. **Container image** -- OS package vulnerabilities in the CI image itself

Results upload as SARIF to GitHub Security > Code scanning.

## Version Pinning

`.github/versions.env` is the single source for all tool versions:

- Sourced by workflows for any runner-side decisions
- Passed as `--build-arg` to the Dockerfile
- Updated manually (Flutter quarterly, others as needed)

No version numbers appear in CI workflow files. No tools are installed on the runner by CI workflows. (Out-of-scope workflows listed above may install tools on the runner.)

## What Runs on the Runner (CI Workflows Only)

Within CI workflows, only GHA-native operations that cannot run inside a container:

- `actions/checkout@v4`
- `.github/actions/start-ci-container` (shell steps to orchestrate Docker)
- `aquasecurity/trivy-action` (scans the container from outside)
- `actions/upload-artifact@v4`
- `codecov/codecov-action@v4`
- `github/codeql-action/upload-sarif@v4`
- `actions/github-script@v7` (PR comments)
- `docker compose down -v` (cleanup)

## PostgreSQL

Workflows needing a database use the `db` profile, which starts `postgres:17-alpine` as a compose sidecar. The CI container reaches it at hostname `postgres`, port `5432`, user `postgres`, password `postgres`.

The database name defaults to `clinical_diary_test`. Some workflows (e.g. `diary-server-ci`, `sponsor-portal-ci`) create and use `sponsor_portal` instead via `psql` after startup.

## Local Parity

Developers can run the same container locally:

```bash
cd tools/dev-env
docker compose --profile build-only build ci                    # build image
docker compose -f docker-compose.yml -f docker-compose.ci.yml up -d ci  # start
docker compose -f docker-compose.yml -f docker-compose.ci.yml exec ci bash  # enter
```

The same image, same tools, same versions as CI.

# Versioning Strategy

## REFERENCES REQUIREMENTS

- REQ-d00006: Mobile App Build and Release Process

## Format

```
MAJOR.MINOR.PATCH+BUILD
```

**Semver** (`MAJOR.MINOR.PATCH`) signals *what changed* in the code.
**Build number** (`+BUILD`) signals *that a new artifact must be built*.

These are independent concerns that can change together or separately.

## Two Independent Concerns

| Concern | When it changes | What changes | Example |
| --- | --- | --- | --- |
| **Code changed** | Source files in the project modified | Semver (patch auto, minor/major manual) | `0.1.0+11` -> `0.1.1+12` |
| **Build trigger** | Any build-relevant file changed (infra, CI, dependency) | Build number only | `0.1.0+11` -> `0.1.0+12` |

Both can happen at once (a code change is also a build trigger). Both can happen independently (an infra change triggers a build without changing code semantics).

## Rules

1. **Code change = semver bump + build bump.** A patch bump is applied automatically. Developers can choose minor or major instead by editing the version manually before committing.

2. **Build trigger without code change = build bump only.** Infra files (Dockerfiles, CI workflows, build scripts) or dependency changes don't alter the code's semantic version, but they produce a different artifact that must be tracked.

3. **Build numbers never reset.** A manual semver bump does not reset the build counter. This ensures build numbers are globally monotonic and every artifact is uniquely identifiable.

   ```
   0.1.0+11  (current)
   0.2.0+12  (dev bumps minor, build continues from 11)
   0.2.1+13  (next auto-patch)
   ```

4. **Manual semver bumps are preserved.** If a developer sets a higher minor or major version before committing, the hook keeps their choice and only appends the build number.

## Scenarios

| Scenario | Before | After | Why |
| --- | --- | --- | --- |
| Own source code changed | `0.1.0+11` | `0.1.1+12` | Semver patch + build |
| Infra file changed (Dockerfile, CI) | `0.1.0+11` | `0.1.0+12` | Build only |
| Dependency code changed | `0.1.0+11` | `0.1.0+12` | Build only (upstream's semver changed, not ours) |
| Dev manually bumped minor | `0.2.0` | `0.2.0+12` | Preserved semver + build |
| Dev manually bumped major | `1.0.0` | `1.0.0+12` | Preserved semver + build |

## Enforcement

- **Pre-commit hook** auto-bumps versions so developers don't need to remember.
- **CI validation** verifies that version bumps are present in PRs. If the hook was bypassed, CI will reject the PR.
- **Build workflow path filters** prevent unnecessary builds when unrelated files change on main.

## What Counts as a Build Trigger

Each project defines its own trigger paths. For deployable services, triggers typically include:

- Own source directory
- Shared library dependencies
- Container configuration (Dockerfiles, entrypoint scripts)
- CI/CD workflows (build and deploy pipelines)
- Build tooling scripts

For libraries, triggers are limited to own source and dependency directories. Infra changes don't affect library artifacts.

# Integration Plan: sponsor-repos → extract-tools

**Ticket**: CUR-514
**Date**: 2026-01-03
**Status**: In Progress

## Executive Summary

This plan integrates the multi-repo sponsor architecture from `sponsor-repos` branch into `extract-tools` branch, adapting it to use the elspais-based requirements system rather than the legacy requirement scripts.

## Branch Comparison

### extract-tools (current branch) has:
- **elspais CLI integration** for requirements processing
- **trace_view package** - modular traceability generation
- Modern, refactored codebase with clean separation of concerns

### sponsor-repos branch has:
- **Multi-repo sponsor architecture** specification (REQ-p01057, REQ-o00076-77, REQ-d00086-89)
- **tools/build/** scripts: resolve-sponsors.sh, verify-sponsor-structure.sh, integrate-sponsors.sh
- **.github/config/sponsors.yml** - sponsor configuration
- **sponsor-validation.yml** workflow
- Updated CI/CD workflows with sponsor awareness
- Does NOT have elspais (uses legacy scripts we already replaced)

## Integration Strategy

**Approach**: Cherry-pick concepts, not code. Adapt sponsor-repos features to work with elspais system.

### Phase 1: Specification Files
Bring over the multi-repo spec files with hash updates:
- `spec/prd-system.md` - updates for multi-repo sponsor requirements
- `spec/dev-sponsor-repos.md` - new file
- `spec/ops-sponsor-repos.md` - new file
- Update `spec/INDEX.md` for new requirements

### Phase 2: Configuration
- Extend `.elspais.toml` with sponsor-aware configuration
- Add `.github/config/sponsors.yml` for sponsor discovery
- Add sponsor-config.yml template

### Phase 3: Build Tooling
Integrate tools/build/ scripts, adapted for elspais:
- `resolve-sponsors.sh` - sponsor discovery (works as-is)
- `verify-sponsor-structure.sh` - structure validation (works as-is)
- `integrate-sponsors.sh` - build integration (works as-is)

### Phase 4: trace_view Package Updates
Extend trace_view for multi-repo support:
- Add `--sponsor-manifest` CLI option
- Add remote sponsor cloning/scanning capability
- Integrate with resolve-sponsors.sh

### Phase 5: CI/CD Workflows
- Add `sponsor-validation.yml` workflow
- Update `build-test.yml` for sponsor awareness
- Update `pr-validation.yml` for sponsor namespace validation

### Phase 6: Testing & Validation
- Run existing test suite
- Validate elspais integration
- Test sponsor resolution with local sponsors

## Key Differences from sponsor-repos

| Feature | sponsor-repos | extract-tools (target) |
| ------- | ------------- | ---------------------- |
| Requirement validation | validate_requirements.py | `elspais validate` |
| Hash management | update-REQ-hashes.py | `elspais hash update` |
| Index generation | regenerate-index.py | `elspais index regenerate` |
| Traceability | generate_traceability.py | trace_view package + elspais |
| Sponsor config | sponsor-config.yml | sponsor-config.yml + elspais patterns |

## Files to Create/Modify

### New Files (from sponsor-repos)
```
spec/dev-sponsor-repos.md          # Adapt, update hashes
spec/ops-sponsor-repos.md          # Adapt, update hashes
.github/config/sponsors.yml        # Direct copy
tools/build/README.md              # Direct copy
tools/build/resolve-sponsors.sh    # Direct copy
tools/build/verify-sponsor-structure.sh  # Direct copy
tools/build/integrate-sponsors.sh  # Direct copy
.github/workflows/sponsor-validation.yml  # Adapt for elspais
```

### Files to Modify
```
.elspais.toml                      # Add sponsor patterns
spec/prd-system.md                 # Cherry-pick changes
spec/INDEX.md                      # Add new REQs
spec/README.md                     # Add sponsor namespace docs
tools/requirements/trace_view/cli.py     # Add --sponsor-manifest
tools/requirements/trace_view/scanning.py # Multi-repo support
.github/workflows/build-test.yml   # Sponsor awareness
.github/workflows/pr-validation.yml # Namespace validation
```

## Commit Strategy

1. **Milestone 1**: Spec files + INDEX updates
2. **Milestone 2**: Configuration + Build tools
3. **Milestone 3**: trace_view updates
4. **Milestone 4**: CI/CD workflow updates
5. **Milestone 5**: Testing + Final validation

## Risk Mitigation

- **Hash conflicts**: Regenerate all hashes using elspais after spec import
- **Namespace validation**: Keep elspais sponsor patterns disabled until tested
- **CI/CD breaking**: Test workflows locally before commit

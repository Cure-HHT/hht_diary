# Documentation Reorganization Plan

**Created**: 2025-11-11
**Status**: In Progress
**Goal**: Reorganize docs/ to use flat hierarchical naming for maximum visibility

## Context

The user requested documentation cleanup to improve day-to-day usability. After analyzing 168 markdown files across the project, we identified that docs/ should mirror the successful spec/ pattern: flat structure with hierarchical naming (topic-subtopic-details.md) instead of nested subdirectories.

**Original Request**: "Make docs/ structure better reflect day-to-day usage. Answers to questions should be easy to find based on topic. Subdirectories should not hide what they contain."

## Principles

1. **Flat is better than nested** - minimize subdirectories
2. **Topic-based prefixes** - group by what you're doing (setup-, ops-, cicd-, etc.)
3. **Self-documenting filenames** - know what it is without opening it
4. **Only 3 subdirectories allowed:**
   - `adr/` - formal ADR process with template/lifecycle
   - `validation/` - formal IQ/OQ/PQ compliance process
   - `WIP/` - temporary unfinished work (target: empty)

## Actions

### Phase 1: Setup and Quick Fixes ✓
- [x] Create `docs/WIP/` directory
- [x] Move `docs/refactoring-plans/` → `docs/WIP/`
- [x] Move 3 CI/CD analysis files → `docs/WIP/`
- [ ] Fix merge conflict in `dev-environment-setup.md` (lines 31-50)
- [ ] Delete `docs/traceability-matrix.md` (duplicate)

### Phase 2: Flatten and Rename
- [ ] Rename setup files (add `setup-` prefix, 7 files)
- [ ] Flatten `ops/` and `monitoring/` (4 files → root with `ops-` prefix)
- [ ] Rename `cicd-pipeline-specification.md` → `cicd-setup-guide.md`
- [ ] Rename architecture, database, compliance files (add prefixes)
- [ ] Delete empty `ops/` and `monitoring/` directories

### Phase 3: Documentation Updates
- [ ] Create `docs/validation/README.md` (explain IQ/OQ/PQ)
- [ ] Update `docs/README.md` (WIP process + naming conventions)
- [ ] Update main `README.md` (if needed)
- [ ] Update internal cross-references

## File Naming Convention

**Format**: `{topic}-{subtopic}-{details}.md`

**Topics**:
- `setup-*` : Onboarding, configuration, getting started
- `ops-*` : Operations, monitoring, incident response, deployment
- `cicd-*` : CI/CD pipelines, automation, validation
- `architecture-*` : System architecture (non-ADR)
- `database-*` : Database guides beyond database/ directory
- `compliance-*` : Compliance audits and verification

**Examples**:
- `setup-doppler-new-dev.md`
- `ops-monitoring-sentry.md`
- `cicd-setup-guide.md`

## Expected Outcome

```
docs/
├── README.md
├── adr/ (7 files)
├── validation/ (5 files including new README)
├── WIP/ (4 files including this plan)
└── [~25 flat files with topic prefixes]
```

**Benefits**:
- `ls docs/` shows all topics immediately
- `ls docs/setup-*` finds all setup docs
- `ls docs/ops-*` finds all ops docs
- No hidden content in subdirectories

## Notes for Future Work

- WIP/ should be empty by default - delete files after work complete
- If architectural decisions are made, convert to ADRs
- Consider creating `cicd-developer-guide.md` for daily CI/CD usage
- Keep main README.md minimal with links to organized docs/

# ADR-010: Repository and Deployment Architecture

**Date**: 2026-01-08
**Deciders**: Development Team, DevOps Team
**Compliance Impact**: High (FDA 21 CFR Part 11 traceability)
**Ticket**: CUR-572

## Status

Proposed

---

## Context

The Clinical Trial Diary platform requires a repository structure and deployment model that supports:

1. **Multi-Sponsor Isolation**: Each sponsor needs completely isolated infrastructure (GCP projects, databases) for FDA compliance
2. **Version Stability for Trials**: Active clinical trials must run stable, validated versions
3. **Audit Traceability**: All code changes must be traceable to requirements (FDA 21 CFR Part 11)
4. **Scalability**: Must support unlimited sponsors without linear growth in maintenance burden
5. **Configuration Management**: Sponsor-specific config (branding, study parameters) must be separate from core code

**Current State**:
The codebase uses a mono-repo pattern with sponsors under `sponsor/{name}/`:
```
sponsor/
├── callisto/           # Active sponsor
│   └── sponsor-config.yml
├── template/           # Template for new sponsors
│   └── sponsor-config.yml
└── README.md
```

**Key Questions Addressed**:
- How should repositories be structured for multi-sponsor support?
- What branching strategy supports FDA compliance without maintenance burden?
- How should sponsor deployments be versioned and tracked?

---

## Decision

We adopt a **trunk-based development model with unified deployment versioning**.

### Repository Architecture

**Single Core Repository** (`hht_diary` - public):
- All application code (apps, packages, database schemas)
- Infrastructure-as-code (Pulumi/Terraform)
- Sponsor templates and default configurations
- CI/CD workflows

**Private Sponsor Repositories** (`sponsor-{name}` - future):
- Sponsor-specific configuration overrides
- Branding assets (logos, themes, strings)
- Portal customizations (if needed)
- Cloned as overlays during build process

**Current Implementation** (mono-repo phase):
- Sponsors live in `sponsor/{name}/` directories
- Configuration in `sponsor/{name}/sponsor-config.yml`
- Migration to private repos when needed

### Deployment Model

**Unified Versioning**: All sponsors deploy the same release tag.

```yaml
# sponsors.yaml (or equivalent deployment config)
system:
  release_tag: v1.0.1        # ALL sponsors deploy this version

sponsors:
  callisto:
    gcp_project: hht-callisto-prod
    locked: true             # Active study - approval required

  acme-pharma:
    gcp_project: hht-acme-prod
    locked: false            # Can receive updates freely
```

**Rationale for Unified Versioning**:
- Single codebase to maintain and validate
- Hotfixes benefit all sponsors simultaneously
- Clear audit trail (one tag = one system state)
- No "sponsor left behind" on buggy versions
- Scales without N-way maintenance burden

**Locked Studies**: The `locked: true` flag creates an approval gate, not version divergence. Locked sponsors receive the same version but require explicit approval before deployment.

### Branching Strategy

**Trunk-Based Development**:
```
main                          # Single source of truth
├── feature/CUR-xxx-desc      # New features (short-lived)
├── fix/CUR-xxx-desc          # Bug fixes (short-lived)
└── release/v1.x              # Stabilization only (deleted after tagging)
```

**Key Principles**:

1. **Tags for Releases** (immutable references):
   ```
   v1.0.0          # Production release
   v1.0.1          # Hotfix release
   v1.0.0-rc.1     # Release candidate
   mobile-v2.1.0   # Mobile app release
   ```

2. **Branches Converge** (no permanent parallel branches):
   - Feature branches merge to main and are deleted
   - Release branches exist for stabilization only, then deleted
   - Tags preserve historical references

3. **Merge, Don't Cherry-Pick**:
   - Fixes merge to both main and release branches
   - No duplicate commits with different SHAs
   - Maintains traceability (`git log --ancestry-path` works)

4. **Deployment is Infrastructure, Not Git**:
   - Sponsor versions configured in deployment config
   - Not in git branches
   - Infrastructure tools (Pulumi) apply the deployment

### Branch Lifecycle

| Branch Type | Created From | Merges To | Lifetime | Deleted After |
| --- | --- | --- | --- | --- |
| `feature/*` | `main` | `main` via PR | Days-weeks | Merge |
| `fix/*` | `main` or `release/*` | `main` and `release/*` | Hours-days | Merge |
| `release/*` | `main` | N/A (tag and delete) | 1-2 weeks | Final tag |

### Sponsor Configuration Options

**Option A: Private Repos** (recommended for production):
- Build process clones sponsor repo at deploy time
- Git provides audit trail for config changes
- Developers manage config via PRs

**Option B: Portal-Based Config** (alternative for self-service):
- Config stored in portal database
- Sponsors can update branding/settings via UI
- Requires additional application development
- See `docs/branch-and-release/RECOMMENDED-ALT-portal-config.md`

---

## Consequences

### Positive

1. **Simpler Maintenance**: One codebase, one tag per release, no N-way branch maintenance
2. **Clear Audit Trail**: Tags are immutable; deployment config shows exactly what ran where
3. **Proper Git Usage**: Follows industry best practices (trunk-based, merge-based, converging branches)
4. **Scalability**: Adding sponsors doesn't increase branch maintenance
5. **FDA Compliance**: Unified versioning means all sponsors are on validated, documented versions
6. **Hotfix Efficiency**: Fix once, deploy everywhere (no cherry-picking to N branches)

### Negative

1. **Less Per-Sponsor Flexibility**: Cannot run different code versions per sponsor
   - *Mitigation*: This is actually correct for FDA compliance (all sponsors should run validated code)

2. **Coordinated Releases**: All sponsors update together
   - *Mitigation*: `locked` flag gates updates for active studies

3. **Migration Required**: Current mono-repo sponsors will need config migration when moving to private repos
   - *Mitigation*: Migration is straightforward; config files stay similar

### Neutral

- Mobile app versioning follows same pattern (tags, not branches)
- Backend/mobile compatibility documented in deployment config

---

## Alternatives Considered

### Alternative 1: Long-Lived Release Branches

**Approach**: Maintain permanent `release/v1.0`, `release/v1.1`, etc. branches

**Rejected because**:
- Git branches are designed to converge, not live forever
- Creates N-way maintenance burden (every fix applied to every branch)
- Breaks traceability when cherry-picking between branches
- Scales poorly: 5 sponsors × 3 versions = 15 branches to maintain

### Alternative 2: Sponsor Branches

**Approach**: Create `sponsor/acme-v1.0.0` branches per sponsor

**Rejected because**:
- Conflates deployment orchestration with version control
- Sponsors use same code; only config differs
- Infrastructure config (`sponsors.yaml`) accomplishes same goal without branch proliferation
- "Frozen branches" don't exist in git (tags do)

### Alternative 3: Cherry-Pick Workflow

**Approach**: Cherry-pick hotfixes from release branches back to main

**Rejected because**:
- Creates duplicate commits with different SHAs
- Breaks `git log --ancestry-path` and merge tracking
- Industry consensus: cherry-pick is for emergencies, not standard workflow
- Merge-based workflow maintains traceability

### Alternative 4: Separate Deployment Repository

**Approach**: Create `hht_diary-deploy` repo for infrastructure

**Rejected because**:
- Code and infrastructure often change together
- Tags already provide immutable deployment references
- Additional repo adds coordination overhead without benefit

---

## Implementation

### Current State (Mono-Repo)

```
hht_diary/
├── apps/                    # Flutter applications
├── packages/                # Shared Dart packages
├── database/                # PostgreSQL schemas
├── sponsor/                 # Sponsor configurations (mono-repo)
│   ├── callisto/
│   └── template/
└── .github/config/          # CI/CD configuration
    └── shared-config.yml    # Sponsor matrix
```

### Future State (Private Repos)

```
hht_diary (PUBLIC)                sponsor-{name} (PRIVATE)
├── apps/                         ├── config/
├── packages/                     ├── branding/
├── database/                     └── portal/
├── terraform/
└── sponsors.yaml  ←── references ──┘
```

### Migration Path

1. **Phase 1** (current): Sponsors in `sponsor/{name}/` directories
2. **Phase 2**: Create private `sponsor-{name}` repos for new sponsors
3. **Phase 3**: Migrate existing sponsors to private repos as needed
4. **Phase 4**: Remove `sponsor/` directory from core repo (keep template)

---

## Validation

- [ ] All releases use tags (not long-lived branches)
- [ ] Release branches deleted after final tag
- [ ] Deployment config specifies tags, not branches
- [ ] No cherry-pick in standard workflow
- [ ] Sponsor config changes trackable via git or portal audit log

---

## Related Decisions

- **ADR-007**: Multi-Sponsor Build Reports - Per-sponsor report isolation
- **ADR-009**: Pulumi for Portal Infrastructure - IaC deployment model
- **CUR-572**: Branch and release strategy ticket

## Related Documentation

- `docs/branch-and-release/RECOMMENDED-branching-strategy.md` - Detailed workflow examples
- `docs/branch-and-release/RECOMMENDED-sponsor-deployment.yaml` - Example deployment config
- `docs/branch-and-release/RECOMMENDED-ALT-portal-config.md` - Portal config alternative
- `docs/branch-and-release/CRITIQUE-of-original-strategy.md` - Analysis of rejected approach

---

## References

- [Trunk-Based Development](https://trunkbaseddevelopment.com/)
- [Google Engineering: Why Google Stores Billions of Lines in a Single Repository](https://research.google/pubs/pub45424/)
- [Pro Git: Distributed Workflows](https://git-scm.com/book/en/v2/Distributed-Git-Distributed-Workflows)
- [GitFlow Considered Harmful](https://www.endoflineblog.com/gitflow-considered-harmful)
- FDA 21 CFR Part 11: Electronic Records and Signatures

---

## Review and Approval

- **Author**: Claude Code (with Michael Bushe)
- **Technical Review**: Pending
- **DevOps Review**: Pending
- **Date**: 2026-01-08
- **Status**: Proposed

---

## Change Log

| Date | Change | Author |
| --- | --- | --- |
| 2026-01-08 | Initial ADR created | Claude Code |

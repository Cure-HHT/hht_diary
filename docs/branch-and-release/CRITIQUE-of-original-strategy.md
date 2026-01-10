# Critique: Original Branching Strategy Proposal

This document provides a formal critique of the branching strategy proposed in `branching-release-strategy.md`. While the business requirements are valid, the proposed git strategy employs multiple anti-patterns that would create unnecessary complexity and maintenance burden.

---

## Summary of Issues

| Issue | Severity | Impact |
| --- | --- | --- |
| Cherry-pick as workflow | Critical | Breaks merge tracking, causes conflicts |
| Permanent parallel branches | Critical | Unmaintainable at scale |
| "Frozen" branches | Conceptual | Misunderstands git fundamentals |
| Sponsor branches | Architectural | Conflates deployment with version control |
| Invalid Mermaid syntax | Minor | Documentation errors |

---

## Issue 1: Cherry-Pick as Primary Workflow

### What the proposal says:

```bash
# 6. IMPORTANT: Cherry-pick to main to ensure fix is not lost
git checkout main
git cherry-pick <commit-hash>
git push origin main
```

### Why this is wrong:

**Cherry-pick creates duplicate commits.** When you cherry-pick, git creates a new commit with a different SHA, even though the content is identical. This means:

1. **Git cannot track lineage.** Commands like `git log --ancestry-path`, `git merge-base`, and `git branch --contains` break because they follow commit parentage, not content.

2. **Merge conflicts are likely.** If the branches ever need to interact again (they will), git sees two different commits changing the same code and creates conflicts.

3. **"Is this fix in that branch?"** becomes unanswerable without manual inspection.

### Industry consensus:

> "Cherry-picking is a valid way to get a hotfix out quickly, but it should be followed by a proper merge when possible."
> — *Pro Git* by Scott Chacon

> "Prefer rebasing or merging over cherry-picking for anything other than one-off emergency situations."
> — Google Engineering Practices

### Correct approach:

Fixes should **merge** to both main and the release branch. If the fix originates on a release branch, merge it to main. If it originates on main, merge it to the release branch. No cherry-picking.

```bash
# Fix on main first, then merge to release (preferred)
git checkout main
git checkout -b fix/CUR-xxx
# ... fix ...
git checkout main && git merge fix/CUR-xxx
git checkout release/v1.0 && git merge fix/CUR-xxx

# OR: Fix on release, then merge to main
git checkout release/v1.0
git checkout -b fix/CUR-xxx
# ... fix ...
git checkout release/v1.0 && git merge fix/CUR-xxx
git checkout main && git merge fix/CUR-xxx  # NOT cherry-pick
```

---

## Issue 2: Permanent Parallel Branches

### What the proposal says:

```
release/v1.0 (long-lived, maintained in parallel)
release/v1.1 (long-lived, maintained in parallel)
...potentially indefinite
```

### Why this is wrong:

Git branches are designed with an implicit assumption: **they will eventually converge**. The merge operation is how git tracks history across branches. Branches that never merge are effectively forks.

**Consequences of permanent parallel branches:**

1. **Linear maintenance scaling.** If you have 5 sponsors on 5 versions, every bug fix must be applied 5 times. This is O(n) work for every fix.

2. **Divergent histories.** Over time, the branches accumulate drift. Applying the same fix to v1.0 and v1.5 may require completely different implementations.

3. **No single source of truth.** Which branch represents "the codebase"? With trunk-based development, main is always the answer.

4. **Branch proliferation.** The proposal creates branches for: releases, sponsors, and mobile. With 5 sponsors, you could have 15+ permanent branches.

### Industry practice:

**GitFlow**, despite its flaws, specifies that release branches are **deleted** after the release is tagged:

> "Release branches are created from the develop branch... Once the release is ready, it gets merged into master and tagged. It should also be merged back into develop."
> — Vincent Driessen, GitFlow creator

**Trunk-Based Development** has no long-lived branches at all:

> "A source-control branching model where developers collaborate on code in a single branch called 'trunk' (or main), resist any pressure to create other long-lived development branches."
> — trunkbaseddevelopment.com

### Correct approach:

Release branches have a **finite lifetime**. They exist for stabilization (1-2 weeks), then are deleted. Tags preserve the immutable reference.

```
Before: release/v1.0 lives forever ❌
After:  tag v1.0.0 preserves reference, branch deleted ✓
```

---

## Issue 3: "Frozen" Branches Don't Exist

### What the proposal says:

```
sponsor/acme-v1.0.0 ─────────────────────────────→ (frozen for study)
```

### Why this is conceptually confused:

**Git has no "freeze" feature.** A branch is simply a pointer to a commit. Anyone with push access can move that pointer.

What the proposal means by "frozen":
- We promise not to push to it
- We'll use branch protection rules

But then the same document says:

```bash
# 5. Update sponsor branch (if study allows updates)
git checkout sponsor/acme-v1.0.0
git merge v1.0.1 --no-ff -m "Apply hotfix v1.0.1"
```

**This contradicts the "frozen" concept.** If you're merging to it, it's not frozen.

### What they actually want:

A **tag**. Tags are designed to be immutable references:

- Tags cannot be moved (without `--force`, which is logged)
- Tags are protected by default in most git hosting
- Tags communicate "this is a release" semantically

```bash
# Instead of: sponsor/acme-v1.0.0 branch
# Use:        sponsor-acme-v1.0.0 tag

git tag -a sponsor-acme-v1.0.0 v1.0.0 \
  -m "ACME Pharma production deployment - DO NOT MODIFY"
```

---

## Issue 4: Sponsor Branches Conflate Concerns

### What the proposal says:

> "Create sponsor deployment branch (frozen snapshot)"
> ```
> git checkout -b sponsor/acme-v1.0.0
> ```

### Why this is an architectural mistake:

**Sponsor deployments are defined by three things:**
1. Which version of code to run (a tag)
2. Which configuration to apply (a config file)
3. Which infrastructure to deploy to (a GCP project)

None of these require a git branch. The proposal itself acknowledges this:

> "Each sponsor has a private repository with config and assets"
> "Clone main repo at sponsor's version... Overlay sponsor config"

If you're already specifying the version externally and overlaying config, **why do you need a sponsor branch?** The branch contains nothing that isn't already captured by the tag + config repo.

### The actual problem:

The proposal is trying to use git as a deployment orchestration tool. Git tracks code history. Deployment orchestration belongs in:

- CI/CD configuration (GitHub Actions, Cloud Build)
- Infrastructure-as-code (Terraform)
- Configuration management (sponsors.yaml)

### Correct approach:

```yaml
# sponsors.yaml - deployment config
sponsors:
  acme-pharma:
    release_tag: v1.0.1        # Points to immutable tag
    config_repo: hht-sponsor-acme
    gcp_project: hht-acme-prod
```

The deployment script reads this config and deploys. No sponsor branches needed.

---

## Issue 5: Mobile Branches Solve the Wrong Problem

### What the proposal says:

```
mobile/v2.1 (supports v1.0, v1.1 backends)
```

### Why this doesn't help:

Backend compatibility is a **code architecture** problem. You solve it with:

- API versioning (`/api/v1/`, `/api/v2/`)
- Feature detection (`if (backend.supports('feature-x'))`)
- Protocol negotiation (`Accept: application/vnd.hht.v1+json`)
- Adapter pattern (code that abstracts backend differences)

A git branch does not make your code backward-compatible. You need the compatibility code regardless of how you branch.

### What the proposal likely wants:

A way to track which mobile versions support which backends. This is documentation/metadata:

```yaml
# compatibility-matrix.yaml
mobile-v2.1.x:
  supported_backends: ["v1.0.x", "v1.1.x"]
```

This doesn't require a permanent `mobile/v2.1` branch.

---

## Issue 6: Invalid Mermaid Syntax

### What the proposal includes:

```mermaid
radar
    title Architecture Multi-Deploy Documentation
    x-axis Code Repository, Build Pipeline, Deployment Infrastructure
    y-axis 0, 20, 40, 60, 80, 100
    line1 80, 75, 85, 70, 78
```

### Why this is wrong:

Mermaid does not support radar charts. This syntax is invalid and will not render in any standard Mermaid implementation.

Additionally, even if radar charts were supported:
- The x-axis labels don't match the data points
- The line data has 5 points but 3 x-axis labels
- The y-axis specification is non-standard

### Assessment:

This suggests the document was generated without validation. If the diagrams weren't tested, what else wasn't tested?

---

## What the Proposal Gets Right

To be fair, the document does identify valid requirements:

| Correct Insight | Our Agreement |
| --- | --- |
| Physical isolation per sponsor | Yes, for FDA compliance |
| Version stability for clinical trials | Yes, studies need stable versions |
| Private sponsor config repos | Yes, reasonable pattern |
| Compatibility matrix tracking | Yes, important for mobile |
| Branch protection rules | Yes, essential for main |

The problem is the **solution**, not the **problem statement**.

---

## References

### Industry Best Practices

1. **Google Engineering Practices** - Discourages cherry-pick as workflow
2. **Trunk-Based Development** - trunkbaseddevelopment.com
3. **GitFlow** - Even GitFlow deletes release branches after tagging
4. **GitHub Flow** - Single main branch, deploy from tags
5. **Pro Git** - "Cherry-pick is for emergencies"

### Git Documentation

- `git-tag(1)`: "Tags are ref's that point to specific points in Git history. Unlike branches, tags do not change."
- `git-cherry-pick(1)`: "Apply the changes introduced by some existing commits" (creates new commits)

---

## Recommendation

Reject the proposed branching strategy and adopt the approach in `RECOMMENDED-branching-strategy.md`:

1. **Tags for releases** (immutable, scalable)
2. **Short-lived branches only** (converge via merge)
3. **Infrastructure config for deployments** (not git branches)
4. **Merge-based workflows** (no cherry-picking)

This achieves all the same business goals with:
- Less complexity
- Better scalability
- Correct git usage
- Industry-standard practices

---

*Document Version: 1.0.0*
*Last Updated: 2026-01-08*

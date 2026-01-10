# CureHHT Branch, Tag, and Release Strategy

## Executive Summary

This document defines the git branching, tagging, and release strategy for the CureHHT ePRO platform—an FDA-compliant clinical trial system with a monorepo architecture, a single patient mobile app, and isolated sponsor deployments.

**Key Constraints:**
- Clinical trials require version stability over new features
- Single mobile app serves all sponsors (App Store/Play Store)
- Each sponsor has isolated GCP deployments at potentially different versions
- Private sponsor repos contain config/assets, merged at deployment time
- Small team with preference for simplicity and low overhead
- AGPL open source monorepo with 2-3 sponsors expected in 2026

---

## Part 1: Multi-Deployment Strategy (Recommended)

### 1.1 Branch Types

```
main                          # Latest stable, always deployable
├── feature/CUR-xxx-desc      # New features (short-lived)
├── fix/CUR-xxx-desc          # Bug fixes (short-lived)
├── release/v1.0              # Release stabilization branches
├── sponsor/acme-pharma-v1.0  # Sponsor-specific deployment branches
└── mobile/v2.1               # Mobile app release branches
```

#### Branch Definitions

| Branch Type | Pattern | Lifetime | Merges To | Purpose |
|-------------|---------|----------|-----------|---------|
| `main` | `main` | Permanent | N/A | Integration branch, always deployable |
| `feature/*` | `feature/CUR-xxx-description` | Days-weeks | `main` via PR | New functionality |
| `fix/*` | `fix/CUR-xxx-description` | Hours-days | `main` via PR, possibly release branches | Bug fixes |
| `release/*` | `release/v{major}.{minor}` | Months-years | N/A (long-lived) | Stabilization for release candidates |
| `sponsor/*` | `sponsor/{sponsor-code}-v{version}` | Study lifetime | N/A (frozen) | Sponsor-specific deployment snapshot |
| `mobile/*` | `mobile/v{major}.{minor}` | Until deprecated | N/A (long-lived) | Mobile app release management |

### 1.2 Tag Naming Convention

```
v1.0.0                        # Core platform release
v1.0.0-rc.1                   # Release candidate
v1.0.0-beta.1                 # Beta release
mobile-v2.1.0                 # Mobile app release (App Store/Play Store)
mobile-v2.1.0+1234            # Mobile app with build number
sponsor-acme-v1.0.0           # Sponsor deployment tag
sponsor-acme-v1.0.1-hotfix    # Sponsor hotfix
portal-v1.2.0                 # Sponsor portal specific release
```

#### Semantic Versioning Rules

- **MAJOR**: Breaking API changes, data model changes, protocol changes
- **MINOR**: New features, backward-compatible functionality
- **PATCH**: Bug fixes, security patches, no new features

### 1.3 Release Flow Diagrams

#### Standard Feature Development

```
main ─────────●─────────●─────────●─────────●──────────●─────→
              │         ↑         │         ↑          │
              │    PR   │         │    PR   │          │
              ↓    merge│         ↓    merge│          ↓
feature/CUR-101 ●───●───┘         │                    │
                                  │                    │
feature/CUR-102 ──────────────●───┘                    │
                                                       │
fix/CUR-103 ───────────────────────────────────●───────┘
```

#### Release Branch for Sponsor Deployment

```
main ────●────●────●────●────●────●────●────●────●────●────→
         │              ↑         │         ↑
         │         cherry│        │    cherry│
         ↓         pick │        ↓    pick  │
release/v1.0 ─●────●────●────────────────────│─→ (maintained)
              │    │    │                    │
              │    │    ↓                    │
              │    │  tag: v1.0.0-rc.1       │
              │    ↓                         │
              │  tag: v1.0.0-rc.2            │
              ↓                              ↓
            tag: v1.0.0                    tag: v1.0.1 (hotfix)
              │
              ↓
sponsor/acme-v1.0.0 ─────────────────────────────→ (frozen for study)
```

#### Mobile App Parallel Releases

```
main ────●────●────●────●────●────●────●────●────●────●────→
         │                   ↑              │
         │              merge│              │
         ↓                   │              ↓
mobile/v2.0 ─●────●────●─────│──────────────│─→ (supports v1.0 backends)
             │         │                    │
           tag:      tag:                   │
        mobile-v2.0.0  mobile-v2.0.1        │
                                            ↓
mobile/v2.1 ─────────────────────────●────●─→ (supports v1.0, v1.1 backends)
                                     │    │
                                   tag: tag:
                               mobile-v2.1.0  mobile-v2.1.1
```

### 1.4 Workflow Examples

#### Example 1: New Feature Development

**Scenario**: Adding a new medication tracking feature (CUR-450)

```bash
# 1. Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/CUR-450-medication-tracking

# 2. Develop, commit frequently
git commit -m "feature/CUR-450: Add medication data model"
git commit -m "feature/CUR-450: Implement medication entry UI"
git commit -m "feature/CUR-450: Add medication sync service"

# 3. Push and create PR
git push origin feature/CUR-450-medication-tracking
# Create PR via GitHub, request reviews

# 4. After approval, squash merge to main
# Branch auto-deleted after merge
```

#### Example 2: Creating a Release for Sponsor Deployment

**Scenario**: ACME Pharma is ready to start their clinical trial

```bash
# 1. Create release branch from main
git checkout main
git pull origin main
git checkout -b release/v1.0
git push origin release/v1.0

# 2. Stabilization - only bug fixes allowed
# Feature freeze in effect
git checkout -b fix/CUR-460-validation-edge-case
# ... fix the bug ...
git push origin fix/CUR-460-validation-edge-case
# Create PR targeting release/v1.0 (not main!)

# 3. Tag release candidates
git checkout release/v1.0
git tag -a v1.0.0-rc.1 -m "Release candidate 1 for v1.0.0"
git push origin v1.0.0-rc.1

# 4. After QA approval, tag final release
git tag -a v1.0.0 -m "v1.0.0 - Initial production release"
git push origin v1.0.0

# 5. Create sponsor deployment branch (frozen snapshot)
git checkout -b sponsor/acme-v1.0.0
git push origin sponsor/acme-v1.0.0

# 6. Cherry-pick critical fix back to main
git checkout main
git cherry-pick <commit-hash>
git push origin main
```

#### Example 3: Hotfix for Active Study

**Scenario**: Critical bug found in ACME's production deployment (v1.0.0)

```bash
# 1. Create fix branch from release branch (NOT main)
git checkout release/v1.0
git pull origin release/v1.0
git checkout -b fix/CUR-475-critical-sync-bug

# 2. Fix the issue
git commit -m "fix/CUR-475: Resolve data sync race condition"
git push origin fix/CUR-475-critical-sync-bug

# 3. Create PR to release/v1.0
# After review and merge:

# 4. Tag hotfix release
git checkout release/v1.0
git pull origin release/v1.0
git tag -a v1.0.1 -m "v1.0.1 - Critical sync fix"
git push origin v1.0.1

# 5. Update sponsor branch (if study allows updates)
git checkout sponsor/acme-v1.0.0
git merge v1.0.1 --no-ff -m "Apply hotfix v1.0.1"
git push origin sponsor/acme-v1.0.0
# Or create new sponsor branch:
git checkout -b sponsor/acme-v1.0.1
git push origin sponsor/acme-v1.0.1

# 6. IMPORTANT: Cherry-pick to main to ensure fix is not lost
git checkout main
git cherry-pick <commit-hash>
git push origin main
```

#### Example 4: Mobile App Release Supporting Multiple Backend Versions

**Scenario**: New mobile app version that must work with v1.0 and v1.1 backends

```bash
# 1. Mobile app development happens on main, then branch for release
git checkout main
git checkout -b mobile/v2.1

# 2. Ensure backward compatibility with v1.0 backends
# Add feature flags, API version negotiation, etc.

# 3. Tag mobile release
git tag -a mobile-v2.1.0 -m "Mobile v2.1.0 - Supports backends v1.0, v1.1"
git tag -a mobile-v2.1.0+5678 -m "Build 5678 for store submission"
git push origin --tags

# 4. After App Store/Play Store approval, document compatibility
# mobile-v2.1.0 supports: sponsor-acme-v1.0.x, sponsor-beta-v1.1.x
```

#### Example 5: Second Sponsor at Different Version

**Scenario**: BetaCorp wants to start their trial with newer features from v1.1

```bash
# 1. Create new release branch for v1.1
git checkout main
git checkout -b release/v1.1
git push origin release/v1.1

# 2. Stabilize and tag
git tag -a v1.1.0-rc.1 -m "v1.1.0 RC1"
# ... QA ...
git tag -a v1.1.0 -m "v1.1.0 - Enhanced reporting features"
git push origin --tags

# 3. Create sponsor branch
git checkout -b sponsor/betacorp-v1.1.0
git push origin sponsor/betacorp-v1.1.0

# Now we have:
# - sponsor/acme-v1.0.0 (on v1.0.x)
# - sponsor/betacorp-v1.1.0 (on v1.1.x)
# - mobile/v2.1 supporting both
```

### 1.5 Sponsor Private Repository Integration

Each sponsor has a private repository with config and assets:

```
Cure-HHT/hht_diary (public)           # Main monorepo
Cure-HHT/hht-sponsor-acme (private)   # ACME Pharma config
Cure-HHT/hht-sponsor-betacorp (private) # BetaCorp config
```

#### Sponsor Repo Structure

```
hht-sponsor-acme/
├── config/
│   ├── sponsor.yaml           # Sponsor-specific configuration
│   ├── study-protocol.yaml    # Study parameters
│   └── feature-flags.yaml     # Feature toggles
├── assets/
│   ├── logo.png
│   ├── colors.yaml
│   └── legal/
│       ├── consent-form.pdf
│       └── privacy-policy.pdf
├── terraform/
│   └── overrides.tf           # GCP project-specific overrides
└── .hht-version               # References tag from main repo (e.g., "v1.0.0")
```

#### Deployment Process

```bash
# CI/CD pipeline pseudo-code
deploy_sponsor() {
  sponsor=$1  # e.g., "acme"
  
  # 1. Clone main repo at sponsor's version
  version=$(cat hht-sponsor-${sponsor}/.hht-version)
  git clone --branch ${version} https://github.com/Cure-HHT/hht_diary.git
  
  # 2. Overlay sponsor config
  cp -r hht-sponsor-${sponsor}/config/* hht_diary/config/
  cp -r hht-sponsor-${sponsor}/assets/* hht_diary/assets/
  
  # 3. Build and deploy to sponsor's GCP project
  gcloud config set project hht-${sponsor}-prod
  ./deploy.sh
}
```

### 1.6 Version Compatibility Matrix

Maintain a compatibility matrix in the repo:

```yaml
# docs/compatibility-matrix.yaml
mobile_versions:
  mobile-v2.0.x:
    supported_backends: ["v1.0.x"]
    min_ios: "14.0"
    min_android: "26"
    status: "deprecated"
    
  mobile-v2.1.x:
    supported_backends: ["v1.0.x", "v1.1.x"]
    min_ios: "15.0"
    min_android: "28"
    status: "current"

sponsor_deployments:
  acme-pharma:
    backend_version: "v1.0.0"
    mobile_versions: ["mobile-v2.0.x", "mobile-v2.1.x"]
    study_status: "active"
    deployment_date: "2026-03-01"
    gcp_project: "hht-acme-prod"
    
  betacorp:
    backend_version: "v1.1.0"
    mobile_versions: ["mobile-v2.1.x"]
    study_status: "preparation"
    deployment_date: "2026-06-01"
    gcp_project: "hht-betacorp-prod"
```

### 1.7 Branch Protection Rules

#### `main` Branch
- Require pull request reviews (minimum 1)
- Require status checks to pass (CI, tests)
- Require linear history (squash merges)
- No direct pushes

#### `release/*` Branches
- Require pull request reviews (minimum 2 for production releases)
- Require status checks to pass
- Allow only `fix/*` branches to merge
- No force pushes

#### `sponsor/*` Branches
- Locked after study begins (no merges without explicit approval)
- Require FDA compliance review for any changes
- Full audit trail required

#### `mobile/*` Branches
- Require pull request reviews
- Require App Store/Play Store build validation
- No force pushes

---

## Part 2: Multi-Tenant Alternative Analysis

### 2.1 Multi-Tenant Architecture Overview

Instead of separate GCP projects per sponsor, a multi-tenant architecture would deploy a single system that serves all sponsors with logical data isolation.

```
┌─────────────────────────────────────────────────────────────┐
│                    Single GCP Project                        │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   Cloud Run                          │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │         Sponsor Portal (Multi-tenant)        │    │    │
│  │  │  tenant_id = {acme, betacorp, gammamed}     │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   Firestore                          │    │
│  │  /tenants/{tenant_id}/patients/{patient_id}/...     │    │
│  │  Row-level security via tenant_id                    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Tradeoff Analysis

| Factor | Multi-Deployment (Separate GCP) | Multi-Tenant (Single GCP) |
|--------|--------------------------------|---------------------------|
| **Data Isolation** | ✅ Physical isolation (strongest) | ⚠️ Logical isolation (row-level) |
| **Regulatory Risk** | ✅ Lower - no cross-sponsor data risk | ⚠️ Higher - must prove isolation |
| **Version Independence** | ✅ Each sponsor on different version | ❌ All sponsors on same version |
| **Study Stability** | ✅ Sponsor version frozen for study | ❌ Updates affect all sponsors |
| **Operational Complexity** | ⚠️ Multiple deployments to manage | ✅ Single deployment |
| **Cost Efficiency** | ⚠️ Duplicate infrastructure | ✅ Shared infrastructure |
| **Shutdown/Archival** | ✅ Easy per-project shutdown | ⚠️ Complex data extraction |
| **Custom Auth Integration** | ✅ Each sponsor can have own IdP | ⚠️ Must support all IdPs in one system |
| **Billing Transparency** | ✅ Clean per-sponsor billing | ⚠️ Requires allocation logic |
| **Incident Blast Radius** | ✅ Issue affects one sponsor | ❌ Issue affects all sponsors |
| **Development Overhead** | ⚠️ More deployment pipelines | ✅ One deployment pipeline |
| **Audit/Compliance** | ✅ Isolated audit logs | ⚠️ Must filter audit logs |

### 2.3 Critical Risks with Multi-Tenant for FDA Clinical Trials

1. **Data Leakage Risk**: A bug in tenant filtering could expose one sponsor's data to another. This is a regulatory nightmare for clinical trials.

2. **Version Lock-in**: All sponsors must accept updates simultaneously. A sponsor mid-study cannot refuse a backend update they didn't request.

3. **Rollback Complexity**: If v1.2 introduces a bug for Sponsor A but Sponsor B depends on a v1.2 feature, you cannot roll back without affecting both.

4. **Audit Complexity**: FDA audits require clear data lineage. Proving logical isolation is harder than proving physical isolation.

5. **Study Protocol Violations**: Different studies have different data retention requirements. Multi-tenant makes per-study policies complex.

### 2.4 Multi-Tenant Branching Strategy (If Chosen)

If multi-tenant is selected despite the risks, the branching strategy simplifies significantly:

```
main                          # Development
├── feature/CUR-xxx-desc      # Features
├── fix/CUR-xxx-desc          # Fixes
└── release/v1.0              # Release stabilization
```

#### Multi-Tenant Tag Strategy

```
v1.0.0                        # Platform version
v1.0.0-rc.1                   # Release candidate
mobile-v2.1.0                 # Mobile app (still separate)
```

#### Key Differences

1. **No sponsor branches**: All sponsors run the same code version
2. **Single deployment**: One CI/CD pipeline deploys to production
3. **Feature flags replace versions**: Use feature flags for sponsor-specific functionality
4. **Canary deployments**: Roll out to one sponsor's tenant first as canary

#### Multi-Tenant Workflow

```bash
# Feature development (unchanged)
git checkout -b feature/CUR-500-new-report
# ... develop ...
# PR to main

# Release (simpler)
git checkout -b release/v1.2
git tag -a v1.2.0-rc.1 -m "RC1"
# Deploy to staging
# All sponsors test on staging
# When ALL sponsors approve:
git tag -a v1.2.0 -m "Production release"
# Single deployment to production
```

#### Feature Flags for Sponsor Customization

```yaml
# config/feature-flags.yaml
features:
  enhanced_reporting:
    enabled_tenants: ["betacorp", "gammamed"]
    disabled_tenants: ["acme"]  # ACME's study doesn't want changes
    
  custom_consent_flow:
    enabled_tenants: ["acme"]
    config:
      acme:
        consent_version: "2.1"
        require_witness: true
```

### 2.5 Hybrid Approach: Considered but Not Recommended

A hybrid approach where the mobile app is multi-tenant but backends are separate adds the worst of both worlds:
- Mobile app still needs backward compatibility with multiple backend versions
- Backend still needs separate deployments
- Adds complexity without meaningful benefit

---

## Part 3: Recommendation

### 3.1 Strong Recommendation: Multi-Deployment Architecture

For FDA-compliant clinical trials, **multi-deployment (separate GCP projects per sponsor)** is strongly recommended due to:

1. **Regulatory Confidence**: Physical isolation is easier to demonstrate to FDA auditors
2. **Study Stability**: Sponsors can remain on stable versions throughout multi-year studies
3. **Risk Isolation**: A bug or security incident in one deployment cannot affect another
4. **Clean Lifecycle Management**: Studies end, data is archived, project is shut down cleanly
5. **Version Flexibility**: Each sponsor can have customizations without feature flag complexity

### 3.2 Accepting the Overhead

The operational overhead of multiple deployments is acceptable because:

1. **Small scale**: 2-3 sponsors in 2026 is manageable
2. **Automation**: CI/CD can handle multiple deployments with parameterization
3. **Infrequent changes**: Clinical studies don't want frequent updates—this matches multi-deployment well
4. **Terraform modules**: Infrastructure can be templated and reused

### 3.3 Simplified Strategy Summary

```
main
 └── feature/*, fix/*    →  PR merge  →  main
                                           │
                                           ▼
                                     release/v1.x  →  tag v1.x.x
                                           │
                         ┌─────────────────┼─────────────────┐
                         ▼                 ▼                 ▼
               sponsor/acme-v1.0   sponsor/beta-v1.1   mobile/v2.1
                         │                 │                 │
                         ▼                 ▼                 ▼
                   GCP: acme-prod    GCP: beta-prod    App Stores
```

### 3.4 Implementation Checklist

- [ ] Configure branch protection rules per §1.7
- [ ] Set up compatibility matrix tracking
- [ ] Create CI/CD templates for sponsor deployments
- [ ] Define sponsor repo structure template
- [ ] Document hotfix procedures for active studies
- [ ] Create mobile app backward-compatibility test suite
- [ ] Establish FDA audit trail logging per sponsor project

---

## Appendix A: Quick Reference

### Branch Commands Cheat Sheet

```bash
# New feature
git checkout main && git pull && git checkout -b feature/CUR-xxx-desc

# New fix (for main)
git checkout main && git pull && git checkout -b fix/CUR-xxx-desc

# Hotfix for release
git checkout release/v1.0 && git pull && git checkout -b fix/CUR-xxx-hotfix

# Create release branch
git checkout main && git checkout -b release/v1.x

# Tag release
git tag -a v1.x.0 -m "Release description"

# Create sponsor deployment
git checkout -b sponsor/sponsor-name-v1.x.0

# Cherry-pick to main
git checkout main && git cherry-pick <hash>
```

### Tag Cheat Sheet

```bash
# Core platform
git tag -a v1.0.0 -m "v1.0.0 - Description"

# Release candidate
git tag -a v1.0.0-rc.1 -m "v1.0.0 RC1"

# Mobile app
git tag -a mobile-v2.1.0 -m "Mobile v2.1.0"

# Mobile with build number
git tag -a mobile-v2.1.0+1234 -m "Build 1234"

# Sponsor deployment
git tag -a sponsor-acme-v1.0.0 -m "ACME deployment"

# Push tags
git push origin --tags
```

---

## Appendix B: Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-07 | Multi-deployment over multi-tenant | FDA compliance, study stability |
| 2026-01-07 | Semantic versioning | Industry standard, clear communication |
| 2026-01-07 | Long-lived release branches | Support multiple versions simultaneously |
| 2026-01-07 | Sponsor branches frozen post-deployment | Clinical trial integrity |
| 2026-01-07 | Single mobile app with version negotiation | User experience, store simplicity |

---

*Document Version: 1.0.0*  
*Last Updated: 2026-01-07*  
*Author: Generated for CUR-572*

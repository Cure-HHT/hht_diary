# Multi-Deployment vs Multi-Tenant: Executive Summary

## Decision: Multi-Deployment (Separate GCP Projects) - RECOMMENDED

### Why Multi-Deployment for FDA Clinical Trials?

| Requirement | Multi-Deployment | Multi-Tenant |
|------------|------------------|--------------|
| **Data Isolation** | ✅ Physical separation | ⚠️ Logical separation only |
| **FDA Audit Confidence** | ✅ Easy to demonstrate | ⚠️ Must prove row-level security |
| **Version Independence** | ✅ Each sponsor frozen at their version | ❌ All sponsors share version |
| **Study Stability** | ✅ No forced updates mid-study | ❌ Updates affect everyone |
| **Incident Blast Radius** | ✅ Bug affects one sponsor | ❌ Bug affects all sponsors |
| **Shutdown/Archive** | ✅ Delete GCP project | ⚠️ Complex data extraction |
| **Custom OAuth/IAM** | ✅ Per-sponsor IdP integration | ⚠️ All IdPs in one system |

### Operational Overhead Trade-off

**Multi-Deployment adds:**
- Multiple CI/CD pipelines (mitigated by templating)
- Multiple GCP projects to monitor (mitigated by central dashboards)
- Cherry-pick workflow for shared fixes (acceptable for small team)

**But eliminates:**
- Feature flag complexity for per-sponsor features
- Tenant filtering bugs (regulatory risk)
- Coordination for updates (all sponsors must agree)
- Complex rollback scenarios

### Key Insight

Clinical trials are **not like typical SaaS products**:
- Studies run 2-5 years on **stable, validated versions**
- Sponsors **don't want** the latest features mid-study
- FDA requires clear data provenance and isolation
- Studies end and data must be cleanly archived

Multi-deployment naturally matches this lifecycle. Multi-tenant fights it.

---

## Branching Strategy Summary

```
main (development)
 │
 ├── feature/* ──PR──> main
 ├── fix/* ─────PR──> main OR release/*
 │
 ├── release/v1.0 (long-lived stabilization)
 │    ├── tag: v1.0.0-rc.1, v1.0.0-rc.2
 │    ├── tag: v1.0.0 (production)
 │    └── sponsor/acme-v1.0.0 (frozen for study)
 │
 ├── release/v1.1 (parallel release)
 │    ├── tag: v1.1.0
 │    └── sponsor/betacorp-v1.1.0 (frozen)
 │
 └── mobile/v2.1 (supports v1.0 + v1.1 backends)
      └── tag: mobile-v2.1.0
```

## Critical Workflows

### Hotfix for Active Study
1. Fix on `release/v1.x` branch (not main)
2. Tag hotfix: `v1.x.1`
3. Update sponsor branch if study allows
4. **Always** cherry-pick to `main`

### New Sponsor Onboarding
1. Identify version requirements
2. Create/use appropriate `release/v1.x`
3. Create `sponsor/{name}-v1.x.0` branch
4. Set up GCP project from Terraform template
5. Configure sponsor private repo
6. Deploy

### Mobile App Update
1. Ensure backward compatibility with ALL active backend versions
2. Add to compatibility matrix
3. Release to stores
4. Document supported backend versions

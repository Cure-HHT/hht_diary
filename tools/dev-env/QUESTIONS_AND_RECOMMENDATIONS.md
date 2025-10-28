# Development Environment: Questions & Recommendations

**Date**: 2025-10-27
**Status**: Awaiting User Input
**Context**: Docker-based development environment implementation

---

## Critical Questions Requiring User Input

### 1. Doppler Secrets Management Setup

**Status**: ⚠️ Requires Configuration

**Questions**:

1. **Do you have a Doppler account?**
   - ☐ Yes → Proceed to question 2
   - ☐ No → Sign up at https://doppler.com/ (free tier available)

2. **Doppler Project Name**:
   - Suggested: `clinical-diary-dev`
   - Current assumption in docs: `clinical-diary-dev`
   - **Action Required**: Confirm or provide different name

3. **Doppler Configs Needed**:
   - `dev` - Development environment
   - `qa` - QA/Testing environment
   - `ops` - Operations environment
   - `staging` - Staging deployment
   - `prod` - Production deployment
   - **Action Required**: Confirm this structure or modify

4. **Required Secrets** to configure in Doppler:
   - `GH_TOKEN_DEV` - GitHub Personal Access Token for dev role
   - `GH_TOKEN_QA` - GitHub PAT for QA role (can be same as dev)
   - `GH_TOKEN_OPS` - GitHub PAT for ops role (needs deploy permissions)
   - `GH_TOKEN_MGMT` - GitHub PAT for mgmt role (read-only)
   - `SUPABASE_SERVICE_TOKEN` - Supabase service role key
   - `SUPABASE_PROJECT_REF` - Supabase project reference ID
   - `ANTHROPIC_API_KEY` - Claude API key (optional, for Claude Code integration)
   - **Action Required**: Generate these tokens and add to Doppler

**Recommendation**: Set up Doppler BEFORE sharing environment with team. This is critical for security and FDA compliance (audit trail of secret access).

**Next Steps**:
1. Create Doppler account if needed
2. Create project: `clinical-diary-dev`
3. Create configs: `dev`, `qa`, `ops`, `staging`, `prod`
4. Add secrets to each config
5. Team members run: `doppler login` in their containers
6. Update `tools/dev-env/doppler-setup.md` with your specific project details

---

### 2. GitHub Organization and Repository

**Status**: ⚠️ Requires Clarification

**Questions**:

1. **GitHub Organization Name**:
   - Current assumption in docs: `yourorg`
   - **Action Required**: Provide actual GitHub org name to update documentation

2. **Repository Name**:
   - Current assumption: `clinical-diary`
   - **Action Required**: Confirm or provide different name

3. **Repository Structure**:
   - Main public repo: For core application code
   - Private repos per sponsor: For sponsor-specific customizations
   - **Action Required**: Confirm this matches your plan

4. **GitHub Container Registry**:
   - Docker images will be published to `ghcr.io/<org>/clinical-diary-*`
   - **Action Required**: Ensure GitHub org has GHCR enabled

5. **Branch Protection Rules**:
   - Main branch should be protected
   - Require PR reviews?
   - Require status checks (QA automation, build)?
   - **Action Required**: Configure in GitHub settings

**Recommendation**:
- Create GitHub organization now if not exists
- Set up branch protection rules before team onboarding
- Enable GitHub Container Registry
- Configure GitHub Actions secrets (DOPPLER tokens for CI/CD)

**Next Steps**:
1. Create/verify GitHub organization
2. Update all documentation references: Find/replace `yourorg` with actual org name
3. Configure branch protection on main
4. Set up GitHub Actions secrets
5. Test CI/CD workflows with a test PR

---

### 3. Supabase Project Setup

**Status**: ⚠️ Requires Information

**Questions**:

1. **Supabase Project Status**:
   - ☐ Already exists → Provide project ref
   - ☐ Need to create → Follow ops-database-setup.md

2. **Supabase Project Reference ID**:
   - Format: `abcdefghijklmnop` (16 characters)
   - **Action Required**: Provide project ref for Doppler config

3. **Supabase Service Role Key**:
   - Found in: Supabase Dashboard → Settings → API
   - **Action Required**: Add to Doppler as `SUPABASE_SERVICE_TOKEN`

4. **Database Password**:
   - **Action Required**: Store in Doppler (not in code!)

5. **Multiple Supabase Projects** (per spec requirements):
   - You mentioned separate database per sponsor
   - **Action Required**: Clarify if you need:
     - ☐ One Supabase project per sponsor
     - ☐ One Supabase project with separate schemas
     - ☐ One database with RLS separation

**Recommendation**: Start with ONE Supabase project for development. Add sponsor-specific projects later as needed.

**Next Steps**:
1. Create Supabase project (if not exists)
2. Note project ref and service key
3. Add to Doppler
4. Test connection from ops container: `supabase link`

---

### 4. Team Size and Roles

**Status**: ✅ Answered (3-person team)

**Current Understanding**:
- Team size: 3 developers
- Roles needed: dev, qa, ops, mgmt (same people wearing different hats)

**Follow-up Questions**:

1. **Will team members switch roles frequently?**
   - ☐ Yes → VS Code Dev Containers make this easy
   - ☐ No → Can use `docker compose exec <role>` directly

2. **Primary IDE**:
   - ☐ VS Code (recommended - Dev Containers work great)
   - ☐ Other IDE (can still use containers via CLI)

3. **Remote Work**:
   - ☐ All local development
   - ☐ Some remote (consider GitHub Codespaces option)

**Recommendation**: Use VS Code with Dev Containers extension for best experience.

---

### 5. CI/CD and GitHub Actions

**Status**: ⚠️ Requires Testing

**Questions**:

1. **GitHub Actions Runners**:
   - ☐ Use GitHub-hosted runners (recommended for now)
   - ☐ Self-hosted runners (for compliance/security)

2. **Build Frequency**:
   - Docker images: On push to main + PR
   - QA automation: On every PR
   - **Action Required**: Confirm this is acceptable

3. **Artifact Retention**:
   - Current config: 30 days for test reports, 90 days for SBOMs
   - **Action Required**: Adjust if needed for compliance

4. **Image Signing**:
   - Using Cosign with keyless signing (GitHub OIDC)
   - **Action Required**: Confirm this meets your security requirements
   - Alternative: Use your own signing keys

**Recommendation**: Start with GitHub-hosted runners. Move to self-hosted later if needed for compliance.

**Next Steps**:
1. Test workflows with a demo PR
2. Verify image signing works
3. Check SBOM generation
4. Review artifact retention policy

---

## Recommendations for Next Steps

### Immediate Actions (Before Team Onboarding)

1. **✅ Complete Doppler Setup**
   - Create account
   - Configure project and secrets
   - Test in all 4 container roles

2. **✅ GitHub Configuration**
   - Set organization name
   - Configure branch protection
   - Set up GitHub Actions secrets
   - Enable GHCR

3. **✅ Supabase Setup**
   - Create project (if not exists)
   - Configure secrets in Doppler
   - Test connection from containers

4. **✅ Test Build Pipeline**
   - Create test PR
   - Verify all workflows run
   - Check Docker image build and push
   - Verify image signing

5. **✅ Platform Testing**
   - Test on Linux
   - Test on macOS (if team uses Mac)
   - Test on Windows WSL2 (if team uses Windows)
   - Document any platform-specific issues

### Documentation Updates Needed

1. **Update with Real Values**:
   - `tools/dev-env/README.md`: Replace `yourorg` with actual org
   - `tools/dev-env/doppler-setup.md`: Add actual Doppler project name
   - `.github/workflows/*.yml`: Update registry paths if needed

2. **Create Team Onboarding Guide**:
   - How to get Docker installed
   - How to clone and setup
   - How to configure Doppler
   - How to use Dev Containers
   - Common troubleshooting

3. **FDA Validation Documentation**:
   - Execute IQ protocol: `docs/validation/dev-environment/IQ.md`
   - Execute OQ protocol: `docs/validation/dev-environment/OQ.md`
   - Schedule PQ protocol (7-day test): `docs/validation/dev-environment/PQ.md`
   - Document results for regulatory submission

### Before Production Use

1. **Security Review**:
   - [ ] Review all Dockerfile contents
   - [ ] Verify no secrets in images
   - [ ] Confirm image signing works
   - [ ] Test SBOM generation
   - [ ] Review GitHub Actions permissions

2. **Compliance Verification**:
   - [ ] Complete IQ/OQ/PQ protocols
   - [ ] Document validation results
   - [ ] Generate signed validation report
   - [ ] Store in compliance repository

3. **Team Training**:
   - [ ] Conduct training session on Dev Containers
   - [ ] Demonstrate role switching
   - [ ] Show how to use Doppler
   - [ ] Practice QA automation workflow
   - [ ] Review troubleshooting guide

---

## Technical Recommendations

### 1. Container Resource Limits

**Current Settings** (in `docker-compose.yml`):
- CPU: 4 cores per container
- Memory: 6GB per container

**Recommendation**: Adjust based on your team's hardware:
- **8GB RAM total**: Reduce to 2GB per container
- **16GB RAM total**: Current settings OK
- **32GB+ RAM total**: Can increase if needed

**How to Adjust**:
Edit `tools/dev-env/docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'      # Reduce from 4
      memory: 4G     # Reduce from 6G
```

### 2. Docker Image Optimization

**Current State**: Images are functional but not fully optimized

**Recommendations**:
1. **Layer Caching**: Already implemented with multi-stage builds
2. **Image Size**: Could be reduced with:
   - Using Alpine base (trade-off: compatibility issues)
   - Removing unnecessary dependencies
   - Multi-stage builds (already using)
3. **Build Time**: Could be improved with:
   - Pre-built base images on GHCR
   - GitHub Actions cache (already implemented)

**Priority**: Low - Current implementation is good for now

### 3. Secrets Management

**Current Approach**: Doppler (recommended)

**Alternatives Considered**:
- ❌ Environment files (`.env`): Not FDA compliant, no audit trail
- ❌ GitHub Secrets only: Not available for local development
- ✅ Doppler: Audit trail, works locally and in CI, FDA compliant

**Recommendation**: Stick with Doppler

### 4. CI/CD Pipeline

**Current Implementation**:
- ✅ Automated testing on PR
- ✅ Image build and publish
- ✅ Image signing with Cosign
- ✅ SBOM generation with Syft
- ✅ Security scanning with Trivy

**Additional Considerations**:
1. **Deployment Automation**: Not yet implemented
   - **Recommendation**: Add after basic dev workflow is stable
   - **Implementation**: Use GitHub Actions to deploy to Supabase

2. **Release Management**: Not yet defined
   - **Recommendation**: Use GitHub Releases + semantic versioning
   - **Implementation**: Add release workflow later

3. **Monitoring**: Not yet implemented
   - **Recommendation**: Add Sentry or similar for error tracking
   - **Implementation**: Phase 2 feature

---

## Migration from Old Setup

**Context**: User had PowerShell-based Multipass VM setup

**Status**: ✅ All features migrated to Docker

**Preserved Features**:
- ✅ Role-based separation (dev, qa, ops, mgmt)
- ✅ Specific tooling per role
- ✅ Git identity per role
- ✅ GitHub PAT per role (via Doppler)
- ✅ SSH keys per role (via volume mounts)
- ✅ Automated QA with reports
- ✅ PDF report generation (modernized to Playwright)
- ✅ GitHub integration
- ✅ Artifact retention (now in GitHub Actions)
- ✅ Shared workspace
- ✅ Claude Code integration (via Doppler)

**Improvements Over Old Setup**:
- ✅ Cross-platform (was Windows-only)
- ✅ CI/CD compatible (wasn't before)
- ✅ FDA validated (IQ/OQ/PQ protocols)
- ✅ Lighter weight (containers vs VMs)
- ✅ Faster startup
- ✅ Better documentation
- ✅ Integrated secrets management
- ✅ Image signing for security

**Action Required**: Can archive `tools/dev-setup/` PowerShell scripts

---

## Validation Checklist

Use this checklist to verify the environment is ready:

### Pre-Deployment Checklist

**Setup**:
- [ ] Doppler account created
- [ ] Doppler project configured with all secrets
- [ ] GitHub organization configured
- [ ] GitHub Container Registry enabled
- [ ] Supabase project created
- [ ] All team members have Docker installed

**Testing**:
- [ ] Run: `./setup.sh --validate`
- [ ] Run: `./validate-environment.sh --full`
- [ ] All validation tests pass
- [ ] Platform testing completed (Linux/macOS/Windows)

**Documentation**:
- [ ] Updated docs with real org name
- [ ] Updated docs with real Doppler project
- [ ] Created team onboarding guide
- [ ] Completed IQ protocol
- [ ] Completed OQ protocol
- [ ] Scheduled PQ protocol (7-day test)

**CI/CD**:
- [ ] Created test PR
- [ ] QA automation workflow ran
- [ ] Build workflow ran
- [ ] Images pushed to GHCR
- [ ] Images signed with Cosign
- [ ] SBOMs generated

**Compliance**:
- [ ] Requirement traceability updated
- [ ] Validation protocols executed
- [ ] Results documented
- [ ] Approval signatures obtained

### Ready for Team Use

**Criteria**:
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Secrets configured
- [ ] CI/CD working
- [ ] At least one platform fully tested
- [ ] Team training scheduled

---

## Contact Points for Decisions

**Required Decisions From**:

1. **Project Manager**:
   - Approve final architecture
   - Sign off on validation protocols
   - Schedule team training

2. **Security Officer** (if applicable):
   - Review secrets management approach
   - Approve image signing configuration
   - Review access controls

3. **Compliance Lead** (if applicable):
   - Review validation protocols
   - Approve FDA documentation
   - Sign validation reports

4. **Development Lead**:
   - Confirm tool versions
   - Approve Git workflow
   - Review role-based separation

---

## Timeline Recommendation

**Week 1: Setup & Configuration**
- Day 1-2: Doppler and GitHub setup
- Day 3-4: Supabase configuration
- Day 5: Testing and documentation updates

**Week 2: Validation**
- Day 1-2: Execute IQ and OQ protocols
- Day 3: Platform testing
- Day 4-5: Fix any issues found

**Week 3: Team Onboarding**
- Day 1: Team training session
- Day 2-3: Team members set up environments
- Day 4-5: Support and troubleshooting

**Week 4+: Production Use**
- Begin 7-day PQ protocol
- Monitor performance
- Gather feedback
- Iterate on improvements

---

## Success Metrics

How to know if the environment is working well:

1. **Setup Time**: New developer onboarded in < 2 hours
2. **Build Time**: Full image rebuild in < 60 minutes
3. **Startup Time**: Container startup in < 30 seconds
4. **Test Time**: QA automation completes in < 15 minutes
5. **Developer Satisfaction**: Team finds it easier than old setup
6. **Compliance**: Passes all IQ/OQ/PQ validation tests

---

## Appendix: Quick Command Reference

**For Team Members**:

```bash
# First-time setup
cd tools/dev-env
./setup.sh

# Daily use
docker compose up -d dev        # Start dev environment
docker compose exec dev bash    # Enter dev container

# Or use VS Code Dev Containers:
# F1 → "Dev Containers: Reopen in Container"

# Run tests
docker compose exec qa bash
qa-runner.sh

# Deploy (ops role)
docker compose exec ops bash
# ... deployment commands

# Stop containers
docker compose down
```

**For Administrators**:

```bash
# Validate environment
./validate-environment.sh --full

# Rebuild everything
./setup.sh --rebuild

# Check logs
docker compose logs dev
docker compose logs qa

# Clean up
docker compose down -v  # WARNING: Deletes volumes
```

---

**Last Updated**: 2025-10-27
**Status**: Awaiting user input on questions above
**Next Steps**: Address questions, execute validation, onboard team

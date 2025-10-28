# ADR-006: Docker-Based Development Environments

**Date**: 2025-10-26
**Deciders**: Development Team, Compliance Officer
**Compliance Impact**: High (FDA 21 CFR Part 11 validation)

## Status

Accepted

---

## Context

The Clinical Diary project requires development environments that support:

1. **Cross-Platform Teams**: Developers use Windows, Linux, and macOS
2. **FDA Compliance**: Validated, reproducible build environments for regulatory submissions
3. **Role-Based Access**: Separate environments for dev, QA, DevOps, and management roles
4. **CI/CD Parity**: Local development must match automated build environments exactly
5. **Small Team**: 3 developers need efficient onboarding and minimal maintenance burden
6. **Multi-Sponsor Architecture**: Single public core repo + multiple private sponsor repos
7. **Complex Toolchain**: Flutter, Android SDK, Node.js, Python, Terraform, testing frameworks
8. **Secrets Management**: Secure handling of GitHub tokens, Supabase credentials, API keys

**Previous Approach (Rejected)**:
An initial PowerShell script using Canonical Multipass created 4 Ubuntu VMs with role-specific tooling. While this achieved role separation, it had critical limitations:
- Windows-only (PowerShell)
- Incompatible with GitHub Actions
- No dev/prod parity
- No validation path for FDA compliance
- Heavy resource usage (full VMs vs containers)
- Secrets stored in environment variables
- Slow startup times (minutes for VM boot)

**Key Challenge**: How do we provide reproducible, validated, cross-platform development environments that enforce role-based access control while maintaining parity with CI/CD?

---

## Decision

We will use **Docker Compose with multi-service architecture** for development environments:

### Architecture

**Four Docker Services** (one per role):
- `dev-container`: Full development environment (Flutter, Android SDK, Node, Python)
- `qa-container`: Testing environment (Playwright, Flutter tests, report generation)
- `ops-container`: Infrastructure environment (Terraform, Supabase CLI, deployment tools)
- `mgmt-container`: Read-only environment (Git, GitHub CLI, audit log viewers)

**Base Image**: Ubuntu 24.04 LTS (official Docker image)

**Orchestration**: Docker Compose (v2.x) with:
- Named volumes for persistent data (`clinical-diary-repos`, `clinical-diary-exchange`)
- Bind mounts for source code editing
- Resource limits per service
- Health checks for validation
- Network isolation where appropriate

**Developer Experience**:
- **VS Code Dev Containers**: `.devcontainer/` configs for each role
- **Docker Desktop**: Windows/macOS developers
- **Docker Engine**: Linux developers
- **Doppler CLI**: Secrets management integrated into containers

**CI/CD Integration**:
- GitHub Actions workflows use identical Dockerfiles
- Same tool versions locally and in CI
- Same secrets management (Doppler) in both environments

### Tool Selection

**Containerization Platform**: Docker
- **Reason**: Industry standard, excellent cross-platform support, native GitHub Actions integration
- **Alternative Considered**: Podman (Docker-compatible but less Windows support)

**Secrets Management**: Doppler
- **Reason**: Excellent audit trails, zero-knowledge architecture, native Docker integration, free tier for small teams
- **Alternatives Considered**:
  - HashiCorp Vault (too complex for 3-person team)
  - AWS Secrets Manager (vendor lock-in, cost)
  - Azure Key Vault (vendor lock-in, Windows-centric)
  - Environment variables (no audit trail, insecure)

**Base OS**: Ubuntu 24.04 LTS
- **Reason**: Long-term support until 2029, wide package availability, familiar to developers
- **Alternatives Considered**:
  - Alpine Linux (smaller but compatibility issues with Android SDK)
  - Debian (similar to Ubuntu but less tooling ecosystem)

**Flutter Version**: 3.24.0 (stable)
- **Reason**: Latest stable release, production-ready, security updates
- **Update Policy**: Follow Flutter stable channel, update after 30-day observation

**Node.js Version**: 20.x LTS
- **Reason**: Active LTS support until 2026-04-30, proven stability
- **Update Policy**: Follow Node.js LTS schedule

**Android SDK**: cmdline-tools latest, API 34
- **Reason**: Latest stable Android for Play Store submissions
- **Update Policy**: Update to new API levels within 90 days of stable release

**Testing Framework**: Playwright (latest)
- **Reason**: Modern, fast, built-in PDF generation, excellent docs
- **Alternative Considered**: wkhtmltopdf (deprecated, unmaintained)

### Key Technical Decisions

**1. Named Volumes vs Bind Mounts**
- Use **named volumes** for repository storage (`clinical-diary-repos`)
- Use **bind mounts** for source code editing (IDE compatibility)
- **Reason**: Named volumes avoid Windows/Linux filesystem incompatibility

**2. Multi-Stage Dockerfiles**
- Base image with common tools
- Role-specific layers add specialized tools
- **Reason**: Reduces duplication, faster builds, easier maintenance

**3. Dev Containers vs Manual Docker**
- Provide both `.devcontainer/` configs AND docker-compose.yml
- **Reason**: VS Code users get one-click setup, command-line users have flexibility

**4. Image Signing**
- Use Docker Content Trust + Cosign for image signing
- Generate SBOMs with Syft
- **Reason**: FDA compliance requires proof of software integrity

**5. QA Automation Location**
- GitHub Actions (not cron job in VM)
- Triggered on PR events (not polling)
- **Reason**: Better GitHub integration, lower resource usage, clearer audit trail

---

## Consequences

### Positive

✅ **Cross-Platform**: Works identically on Windows, Linux, macOS
✅ **Fast Startup**: Containers start in seconds vs minutes for VMs
✅ **CI/CD Parity**: Same Dockerfiles locally and in GitHub Actions
✅ **Reproducible**: Dockerfile = environment specification (version controlled)
✅ **Lightweight**: 4 containers use far less resources than 4 VMs
✅ **Modern Tooling**: Docker is industry standard, extensive documentation
✅ **Validation Path**: Images can be signed, versioned, SBOMs generated
✅ **Secrets Security**: Doppler eliminates hardcoded credentials
✅ **Easy Onboarding**: New developers: install Docker → run compose → done
✅ **Maintainable**: Dockerfiles easier to update than VM provisioning scripts

### Negative

⚠️ **Learning Curve**: Team needs Docker knowledge (mitigated: Docker is industry standard)
⚠️ **Docker Dependency**: Requires Docker Desktop (Windows/Mac) or Docker Engine (Linux)
⚠️ **Windows Complexity**: WSL2 required on Windows (most developers already use this)
⚠️ **Resource Limits**: Containers share host resources (mitigated: resource limits configured)
⚠️ **Networking**: Container networking more complex than VMs (mitigated: Docker Compose handles this)

### Neutral

◯ **Dev Container Lock-In**: VS Code Dev Containers are VS Code-specific
- **Mitigation**: Also provide docker-compose.yml for CLI users
- **Note**: Most developers use VS Code, and CLI fallback available

◯ **Image Size**: Flutter containers are large (~5GB)
- **Mitigation**: Multi-stage builds, layer caching, clean up in Dockerfile
- **Note**: One-time download, cached locally afterward

◯ **Doppler Dependency**: Requires Doppler account and setup
- **Mitigation**: Free tier supports small teams, good documentation
- **Fallback**: Can use environment variables during initial setup

---

## Alternatives Considered

### Alternative 1: Vagrant + VirtualBox
**Pros**: Full OS isolation, works without Docker, mature tooling
**Cons**: Heavy resource usage, slow startup, not CI/CD friendly, Windows-only Vagrantfile similar to PowerShell issue
**Verdict**: Rejected - too slow, incompatible with GitHub Actions

### Alternative 2: Nix + direnv
**Pros**: Purely functional package management, excellent reproducibility
**Cons**: Steep learning curve, limited Windows support, small ecosystem for our tools (Flutter), not FDA-validated
**Verdict**: Rejected - too esoteric for small team, validation concerns

### Alternative 3: Conda Environments
**Pros**: Good for Python/data science, cross-platform
**Cons**: Not designed for full OS environments (no Flutter, Android SDK support), requires Anaconda/Miniconda
**Verdict**: Rejected - doesn't support mobile development tools

### Alternative 4: GitHub Codespaces
**Pros**: Cloud-based, nothing to install locally, uses Dev Containers
**Cons**: Cost per user per hour, internet dependency, data locality concerns for FDA compliance
**Verdict**: Considered for future - good for remote developers, but local-first preferred for now

### Alternative 5: Native Installation Scripts
**Pros**: No virtualization overhead, direct hardware access
**Cons**: Not reproducible, "works on my machine" issues, platform-specific scripts, no validation path
**Verdict**: Rejected - fails reproducibility and validation requirements

### Alternative 6: Keep Multipass (Original Approach)
**Pros**: Already written, VM isolation strong
**Cons**: Windows-only, no CI/CD compatibility, heavy resources, no dev/prod parity
**Verdict**: Rejected - fundamental incompatibility with cross-platform and CI/CD requirements

---

## Implementation Notes

### Phase 1: Core Infrastructure
- Base Dockerfile (Ubuntu 24.04 + common tools)
- Role-specific Dockerfiles (dev, qa, ops, mgmt)
- docker-compose.yml orchestration
- Doppler integration scripts

### Phase 2: Developer Experience
- `.devcontainer/` configurations for VS Code
- Setup scripts (cross-platform bootstrap)
- Documentation (README, troubleshooting)

### Phase 3: CI/CD Integration
- GitHub Actions workflows using same Dockerfiles
- QA automation workflow
- Image signing and SBOM generation

### Phase 4: Validation
- IQ/OQ/PQ protocols
- Validation test results
- Change control procedures

### Phase 5: Documentation
- Tool version rationale (in this ADR)
- Setup guides per platform
- Troubleshooting guide
- Migration path for existing developers

---

## Validation Strategy

**For FDA Compliance**:

1. **Dockerfile as System Specification**
   - Every tool version explicitly pinned
   - SHA256 checksums for downloaded packages
   - Build process documented and version controlled

2. **Image Signing** (Cosign + Docker Content Trust)
   - Prevents tampering with validated environments
   - Audit trail of who signed which image version

3. **SBOM Generation** (Syft)
   - Software Bill of Materials for supply chain security
   - Required for FDA 21 CFR Part 11 compliance

4. **Change Control**
   - Dockerfile changes require PR review + ADR update
   - Major changes trigger IQ/OQ/PQ re-execution
   - Semantic versioning for environment releases (1.0.0, 1.1.0, etc.)

5. **Validation Protocols**
   - IQ: Verify Docker installed correctly
   - OQ: Verify all tools function as documented
   - PQ: Verify builds produce identical outputs

---

## Migration Path

**From PowerShell/Multipass Script** (if anyone was using it):

1. Archive existing VM setup documentation
2. Document differences for developers
3. Provide Docker installation guides
4. One-time migration: export data from VMs to Docker volumes
5. Deprecation timeline: 30 days parallel support, then VMs retired

**Note**: Current script was never deployed, so no migration needed - clean start.

---

## Success Metrics

- ✅ Environment setup time: < 30 minutes first time, < 5 minutes subsequent
- ✅ Cross-platform parity: Identical behavior on Windows/Linux/macOS
- ✅ CI/CD parity: Local tests match GitHub Actions results 100%
- ✅ Developer satisfaction: Measured via survey after 30 days
- ✅ Onboarding time: New developer productive within 1 day
- ✅ Build reproducibility: Same source + same environment = identical binary
- ✅ Compliance: Pass IQ/OQ/PQ validation protocols

---

## References

- Docker Documentation: https://docs.docker.com/
- Dev Containers Specification: https://containers.dev/
- Doppler Documentation: https://docs.doppler.com/
- FDA 21 CFR Part 11: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application
- SBOM (NTIA): https://www.ntia.gov/SBOM

---

**Related Requirements**:
- REQ-d00027: Containerized Development Environments
- REQ-d00028: Role-Based Environment Separation
- REQ-d00029: Cross-Platform Development Support
- REQ-d00030: CI/CD Environment Parity
- REQ-d00031: Secrets Management via Doppler
- REQ-d00032: Development Tool Specifications
- REQ-d00033: VS Code Dev Containers Integration
- REQ-d00034: Automated QA Workflow
- REQ-d00035: Environment Validation & Change Control
- REQ-d00036: Shared Workspace and File Exchange

**Related Documentation**:
- spec/dev-environment.md: Development environment requirements
- tools/dev-env/README.md: Setup instructions
- docs/validation/dev-environment/: Validation protocols

---

**Decision Date**: 2025-10-26
**Review Date**: 2026-01-26 (quarterly)
**Supersedes**: Initial PowerShell/Multipass approach (never deployed)

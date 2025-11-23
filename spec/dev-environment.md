# Development Environment

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-26
**Status**: Active

> **See**: prd-app.md for application architecture
> **See**: ops-deployment.md for production environment specifications
> **See**: docs/adr/ADR-006-docker-dev-environments.md for architecture decisions

---

## Executive Summary

The Clinical Diary development environment provides role-based containerized workspaces that enforce separation of concerns, enable cross-platform development, and maintain parity between local development and CI/CD environments. The environment supports FDA 21 CFR Part 11 compliance through validated tool chains, reproducible builds, and comprehensive audit trails.

**Key Features**:
- Docker-based containerization for reproducibility
- Role-specific environments (Developer, QA, DevOps, Management)
- Cross-platform support (Windows, Linux, macOS)
- Integrated secrets management via Doppler
- Automated QA workflows with GitHub integration
- Dev/Prod parity for validation

---

## Requirements

# REQ-d00027: Containerized Development Environments

**Level**: Dev | **Implements**: - | **Status**: Active

Development environments SHALL be containerized using Docker to ensure reproducible, platform-independent workspaces that maintain parity between local development, continuous integration, and production build environments.

Containerization SHALL provide:
- Reproducible builds across all platforms (Windows, Linux, macOS)
- Version-pinned tool chains with SHA256 verification
- Isolated environments preventing dependency conflicts
- Fast startup times (< 30 seconds for container launch)
- Resource limits to prevent system resource exhaustion
- Volume mounts for source code sharing without file system incompatibilities

**Rationale**: Docker containers provide reproducible environments required for FDA validation while enabling cross-platform development. Containers can be signed, versioned, and validated as part of change control processes. This approach eliminates "works on my machine" issues and ensures local development matches CI/CD exactly.

**Acceptance Criteria**:
- Dockerfile specifications for each role-based environment
- Docker Compose orchestration for multi-container workflows
- All tool versions explicitly pinned with rationale documented
- Container images buildable on Windows, Linux, and macOS
- Container health checks verify tool availability
- Volume mounts preserve file permissions and ownership

*End* *Containerized Development Environments* | **Hash**: 13d56217
---

# REQ-d00055: Role-Based Environment Separation

**Level**: Dev | **Implements**: p00005, p00014 | **Status**: Active

Development infrastructure SHALL provide separate containerized environments for each role (Developer, QA, DevOps, Management) to enforce principle of least privilege and enable developers to practice proper separation of concerns.

Role-based environments SHALL include:
- **Developer**: Full development tools (Flutter, Android SDK, hot reload, debugging)
- **QA**: Testing frameworks (Playwright, Flutter integration tests, report generation)
- **DevOps**: Infrastructure tools (Terraform, Supabase CLI, deployment automation)
- **Management**: Read-only tools (repository viewer, report access, audit log queries)
- Distinct Git identities per role (name, email, GPG signing)
- Role-specific GitHub Personal Access Tokens with minimal scopes
- Separate SSH keys per role for repository access
- Isolated file systems preventing cross-role data leakage

**Rationale**: Role-based separation enforces security boundaries and trains developers to think about access control. By "wearing different hats," developers internalize the principle that QA should not have deployment permissions, and management should have read-only access. This practice is essential for FDA compliance where audit trails must prove separation of duties.

**Acceptance Criteria**:
- Four distinct Docker services (dev, qa, ops, mgmt)
- Each role has unique Git config (user.name, user.email)
- GitHub CLI authenticated with role-appropriate PAT scopes
- SSH keys mounted per role from host filesystem
- No shared credentials between roles
- File permissions enforce role boundaries
- Documentation explains what each role can and cannot do

*End* *Role-Based Environment Separation* | **Hash**: d3bc3ad6
---

# REQ-d00056: Cross-Platform Development Support

**Level**: Dev | **Implements**: - | **Status**: Active

Development environments SHALL function identically on Windows, Linux, and macOS without platform-specific code paths or manual configuration, enabling team members to use their preferred operating systems while maintaining environment parity.

Cross-platform support SHALL ensure:
- Docker Compose files use platform-agnostic volume paths
- Setup scripts detect host OS and adjust accordingly
- Documentation covers Windows (WSL2), Linux (native), macOS (native)
- File permission handling respects host OS differences
- No platform-specific workarounds or conditional logic in core workflows
- Terminal prompts and scripts compatible with bash/zsh

**Rationale**: Teams using mixed operating systems waste time on platform-specific issues. Docker's cross-platform nature enables identical developer experiences regardless of host OS. This is critical for small teams where each developer may use different platforms.

**Acceptance Criteria**:
- Tested on Windows 11 with WSL2 + Docker Desktop
- Tested on Ubuntu 24.04 with Docker Engine
- Tested on macOS (Intel and Apple Silicon) with Docker Desktop
- No "Windows-only" or "macOS-only" instructions
- File mounts work correctly on all platforms
- Setup documentation includes platform-specific prerequisites only

*End* *Cross-Platform Development Support* | **Hash**: 223d3f08
---

# REQ-d00057: CI/CD Environment Parity

**Level**: Dev | **Implements**: - | **Status**: Active

Local development environments SHALL use identical Docker images as CI/CD pipelines to eliminate environment drift and ensure that code tested locally behaves identically in automated builds.

CI/CD parity SHALL be achieved through:
- Shared Dockerfiles for local dev and GitHub Actions
- Identical tool versions in containers and CI runners
- Same secrets management approach (Doppler) locally and in CI
- Reproducible build commands across environments
- Artifact generation processes identical locally and in CI
- Environment variables managed consistently

**Rationale**: Environment drift between local development and CI/CD is a common source of build failures and "passes locally, fails in CI" issues. Using the same Docker images locally and in GitHub Actions guarantees parity. For FDA validation, this means the validated build environment can be tested locally before deployment.

**Acceptance Criteria**:
- GitHub Actions workflows use same Dockerfiles as local dev
- Tool version mismatches detected by automated checks
- Build commands documented and executable both locally and in CI
- Secrets accessed via Doppler in both environments
- CI logs include tool version verification
- Local development README includes "verify parity" commands

*End* *CI/CD Environment Parity* | **Hash**: e58f7423
---

# REQ-d00058: Secrets Management via Doppler

**Level**: Dev | **Implements**: p00005 | **Status**: Active

Development environments SHALL integrate Doppler secrets management to eliminate hardcoded credentials, provide audit trails of secret access, and enable secret rotation without code changes.

Doppler integration SHALL provide:
- Environment-specific secret projects (dev, staging, prod)
- Role-specific service tokens for automated access
- Personal tokens for individual developer access
- Audit logs showing who accessed secrets and when
- Secret rotation without redeploying containers
- Zero-knowledge architecture (secrets never stored in Git or environment variables)

**Rationale**: Hardcoded secrets in scripts or environment variables violate security best practices and FDA audit requirements. Doppler provides centralized secret management with comprehensive audit trails, enabling compliance with access control and traceability requirements. Secrets are injected at runtime, never persisted to disk.

**Acceptance Criteria**:
- Doppler CLI installed in all role containers
- GitHub tokens accessed via `doppler run -- gh auth login`
- Supabase tokens accessed via `doppler run -- supabase link`
- No secrets in Git history, Dockerfiles, or compose files
- Doppler audit log captures all secret access
- Documentation covers Doppler setup per role
- Secret rotation procedures documented

*End* *Secrets Management via Doppler* | **Hash**: 6119c7b8
---

# REQ-d00059: Development Tool Specifications

**Level**: Dev | **Implements**: - | **Status**: Active

Development environments SHALL include specific tool versions selected for stability, long-term support, and compatibility with FDA validation requirements, with each tool version justified and documented.

Tool specifications SHALL include:

**Mobile Development (dev, qa)**:
- Flutter 3.38.3 (stable channel, LTS release)
- Android SDK cmdline-tools latest (11076708)
- Android platform-tools (latest via sdkmanager)
- Android build-tools 34.0.0
- Android platform API 34 (Android 14)
- OpenJDK 17 (LTS release for Android builds)

**JavaScript/Node.js (all roles)**:
- Node.js 20.x LTS (active LTS, security updates through 2026-04-30)
- npm (bundled with Node)
- pnpm (optional, faster than npm)

**Python (all roles)**:
- Python 3.11+ (minimum, 3.12 preferred for performance)
- pip (latest)
- venv (for virtual environments)

**Version Control (all roles)**:
- Git 2.40+ (security fixes, performance improvements)
- GitHub CLI 2.40+ (supports GitHub Checks API)

**Testing (qa)**:
- Playwright latest (headless browser testing)
- Flutter integration test framework (bundled)

**Infrastructure (ops)**:
- Terraform 1.9+ (infrastructure as code)
- Supabase CLI latest (database management)

**Documentation (mgmt)**:
- Pandoc (document conversion)
- jq (JSON processing for audit logs)

**Rationale**: Explicit tool versions enable reproducible builds required for FDA validation. LTS (Long-Term Support) versions ensure security updates without breaking changes. Each tool version is chosen for specific reasons (stability, security, compatibility) and documented to support validation protocols.

**Acceptance Criteria**:
- All tool versions pinned in Dockerfiles (no "latest" tags except where justified)
- Tool selection rationale documented in ADR-006
- SHA256 checksums verified for downloaded installers
- SBOM (Software Bill of Materials) generated for each container image
- Tool version verification script runs on container startup
- Documentation includes tool update policy and testing procedures

*End* *Development Tool Specifications* | **Hash**: 1a59e7e8
---

# REQ-d00060: VS Code Dev Containers Integration

**Level**: Dev | **Implements**: - | **Status**: Active

Development environments SHALL provide VS Code Dev Containers configuration enabling developers to open projects directly in containerized environments with one click, with role-specific extensions and settings pre-configured.

Dev Containers SHALL provide:
- `.devcontainer/` configurations for each role (dev, qa, ops, mgmt)
- Role-appropriate VS Code extensions automatically installed
- Git configuration persisted from host
- SSH keys mounted securely
- Port forwarding for development servers
- Integrated terminal with role-specific prompt
- Docker Compose integration for multi-container debugging

**Rationale**: VS Code Dev Containers eliminate manual environment setup and ensure every developer uses identical tooling. The "Reopen in Container" feature makes switching between roles seamless, reinforcing the role-based development practice. This dramatically reduces onboarding time for new team members.

**Acceptance Criteria**:
- Four `.devcontainer/` directories (dev/, qa/, ops/, mgmt/)
- Each devcontainer.json specifies appropriate base image
- Role-specific VS Code extensions listed in devcontainer.json
- Git config inherited from host or specified per role
- SSH keys mounted read-only from host `~/.ssh/`
- Workspace folders mapped correctly
- README includes "Reopen in Container" instructions
- First-time setup takes < 5 minutes after Docker installation

*End* *VS Code Dev Containers Integration* | **Hash**: 07abf106
---

# REQ-d00061: Automated QA Workflow

**Level**: Dev | **Implements**: - | **Status**: Active

Development environments SHALL include automated quality assurance workflows that execute Flutter and Playwright tests on pull requests, generate PDF reports, integrate with GitHub Checks, and maintain artifact retention policies.

QA automation SHALL provide:
- GitHub Actions workflow triggered on PR open/update
- Execution in qa-container (same environment as local QA role)
- Flutter integration tests with JUnit XML output
- Playwright end-to-end tests with HTML reports
- Consolidated PDF summary report
- GitHub Checks status posted to PR
- PR comments with test result summary and artifact links
- Artifact retention: 90 days for PR testing, permanent for releases/tags

**Rationale**: Automated QA provides fast feedback on code changes and ensures every PR meets quality standards before merge. Running tests in the same container used locally eliminates "passes in dev, fails in CI" issues. PDF reports provide regulatory audit trail of testing evidence. GitHub integration makes results visible without leaving the PR workflow.

**Acceptance Criteria**:
- `.github/workflows/qa-automation.yml` workflow file
- Workflow uses qa-container Docker image
- Flutter tests run with `flutter test integration_test`
- Playwright tests run with `npx playwright test`
- PDF generated via Playwright's built-in PDF export
- GitHub Checks API called with test results
- PR comment includes pass/fail status and artifact link
- Artifacts uploaded to GitHub Actions (not external storage)
- Permanent archive for commits tagged as releases

*End* *Automated QA Workflow* | **Hash**: fc47d463
---

# REQ-d00062: Environment Validation & Change Control

**Level**: Dev | **Implements**: p00010 | **Status**: Active

Development environments SHALL undergo formal validation using IQ/OQ/PQ protocols to ensure FDA compliance, with changes managed through documented change control procedures.

Validation SHALL include:

**Installation Qualification (IQ)**:
- Docker installation verified on target platforms
- Container images build successfully
- Health checks pass for all services
- Required volumes and networks created
- Tool versions match specifications

**Operational Qualification (OQ)**:
- Each tool executes basic operations correctly
- Git can clone repositories
- Flutter can create and build projects
- Playwright can run sample tests
- Terraform can validate configurations
- Doppler can retrieve secrets

**Performance Qualification (PQ)**:
- Build times within acceptable ranges
- Test execution times baseline established
- Container resource usage monitored
- Identical outputs produced across platforms

**Change Control**:
- Dockerfile changes require pull request review
- Tool version changes documented in ADR
- Validation re-execution required for major changes
- Docker images tagged with semantic versions
- Deprecation policy for old environment versions

**Rationale**: FDA 21 CFR Part 11 requires validated computer systems. Development environments that produce regulatory submissions must be validated to ensure reproducible, auditable results. IQ/OQ/PQ protocols demonstrate that the environment is installed correctly, operates as intended, and performs consistently.

**Acceptance Criteria**:
- IQ protocol documented in `docs/validation/dev-environment/IQ.md`
- OQ protocol documented in `docs/validation/dev-environment/OQ.md`
- PQ protocol documented in `docs/validation/dev-environment/PQ.md`
- Test results templates provided for each protocol
- Dockerfile changes trigger validation review checklist
- Container images signed with Cosign for integrity verification
- SBOM generated and stored with each image version
- Deprecation notices provided 90 days before environment version retirement

*End* *Environment Validation & Change Control* | **Hash**: 7b290df6
---

# REQ-d00063: Shared Workspace and File Exchange

**Level**: Dev | **Implements**: - | **Status**: Active

Development environments SHALL provide shared Docker volumes for code repositories and a designated exchange volume for transferring files between roles, without exposing host file system internals or creating platform-specific path issues.

Shared workspace SHALL include:
- Named volume for repository storage (`clinical-diary-repos`)
- Named volume for role exchange (`clinical-diary-exchange`)
- Bind mounts for source code editing with host IDE
- Proper file permission handling across container boundaries
- No direct access to Windows/Linux file systems from opposite OS
- Workspace paths consistent across all containers

**Rationale**: Docker named volumes eliminate file system permission issues and enable safe sharing between containers and host. This avoids the "never access Linux filesystem from Windows" issue while maintaining proper permissions. Role separation is maintained while allowing controlled data exchange when necessary.

**Acceptance Criteria**:
- `docker-compose.yml` defines named volumes
- All containers mount `clinical-diary-repos` to `/workspace/repos`
- Exchange volume mounted to `/workspace/exchange` (world-readable within containers)
- Source code bind-mounted for editing with host IDE
- File permissions preserved correctly on all platforms
- Documentation explains volume purpose and usage patterns
- No symlinks or hard links that break cross-platform

*End* *Shared Workspace and File Exchange* | **Hash**: b407570f
---

## Tool Version Rationale

### Flutter 3.38.3
- **Status**: Stable release
- **Release Date**: 2024-08-07
- **Support**: Active stable channel
- **Reason**: Latest stable with Android/iOS production support, proven reliability
- **Security**: Regular security updates
- **Update Policy**: Update to newer stable releases after 30-day observation period

### Node.js 20.x LTS
- **Status**: Active LTS (Long-Term Support)
- **Support Until**: 2026-04-30
- **Reason**: LTS guarantees security updates without breaking changes
- **Update Policy**: Follow LTS schedule, update minor versions quarterly

### Python 3.11+
- **Status**: Stable, security support until 2027-10
- **Reason**: Performance improvements over 3.10, wide library compatibility
- **Update Policy**: Minimum 3.11, prefer latest 3.12.x for new installations

### Android API 34 (Android 14)
- **Reason**: Latest stable Android release, required for Play Store submissions
- **Update Policy**: Update to new API levels within 90 days of stable release

### Terraform 1.9+
- **Reason**: Stable infrastructure-as-code, wide provider support
- **Update Policy**: Update minor versions after validation testing

---

## Cross-References

**Related Requirements**:
- REQ-p00005: Multi-Sponsor Data Isolation (implements via role-based separation)
- REQ-p00014: Role-Based Access Control (implements via Docker service separation)
- REQ-p00010: FDA 21 CFR Part 11 Compliance (implements via validation protocols)
- REQ-o00002: Environment Configuration (same principles for dev/prod parity)

**Related Documentation**:
- docs/adr/ADR-006-docker-dev-environments.md: Architecture decisions
- tools/dev-env/README.md: Setup instructions
- docs/validation/dev-environment/: Validation protocols

---

**Created**: 2025-10-26
**Last Validated**: 2025-10-26
**Next Review**: Quarterly or when major tool updates required

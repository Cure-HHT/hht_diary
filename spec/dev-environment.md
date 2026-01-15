# Development Environment

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-11-24
**Status**: Draft

> **See**: prd-diary-app.md for application architecture
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

**Level**: Dev | **Status**: Draft | **Implements**: o00050

## Rationale

Docker containers provide reproducible environments required for FDA validation while enabling cross-platform development. Containers can be signed, versioned, and validated as part of change control processes. This approach eliminates 'works on my machine' issues and ensures local development matches CI/CD exactly. Containerization provides isolation, reproducibility, and platform independence essential for maintaining validated development environments in compliance with 21 CFR Part 11.

## Assertions

A. Development environments SHALL be containerized using Docker.
B. Containerized environments SHALL ensure reproducible builds across Windows, Linux, and macOS platforms.
C. All tool chain versions SHALL be explicitly pinned in container specifications.
D. Pinned tool versions SHALL include SHA256 verification.
E. Containers SHALL provide isolated environments that prevent dependency conflicts between projects.
F. Container launch time SHALL be less than 30 seconds.
G. Containers SHALL enforce resource limits to prevent system resource exhaustion.
H. Containers SHALL support volume mounts for source code sharing.
I. Volume mounts SHALL preserve file permissions and ownership.
J. The system SHALL provide Dockerfile specifications for each role-based environment.
K. The system SHALL provide Docker Compose orchestration for multi-container workflows.
L. All pinned tool versions SHALL have documented rationale for version selection.
M. Container images SHALL be buildable on Windows operating systems.
N. Container images SHALL be buildable on Linux operating systems.
O. Container images SHALL be buildable on macOS operating systems.
P. Containers SHALL include health checks that verify tool availability.

*End* *Containerized Development Environments* | **Hash**: 12d637c5
---

# REQ-d00055: Role-Based Environment Separation

**Level**: Dev | **Status**: Draft | **Implements**: p00005, p00014

## Rationale

Role-based separation enforces security boundaries and trains developers to think about access control. By "wearing different hats," developers internalize the principle that QA should not have deployment permissions, and management should have read-only access. This practice is essential for FDA compliance where audit trails must prove separation of duties. The containerized approach provides isolated environments that prevent cross-role data leakage while enabling developers to practice proper separation of concerns throughout the development lifecycle.

## Assertions

A. The development infrastructure SHALL provide separate containerized environments for each role: Developer, QA, DevOps, and Management.
B. The development infrastructure SHALL enforce the principle of least privilege through role-based environment separation.
C. The Developer environment SHALL include full development tools including Flutter, Android SDK, hot reload, and debugging capabilities.
D. The QA environment SHALL include testing frameworks including Playwright, Flutter integration tests, and report generation tools.
E. The DevOps environment SHALL include infrastructure tools including Terraform, gcloud CLI, Cloud SQL Proxy, and deployment automation.
F. The Management environment SHALL include read-only tools including repository viewer, report access, and audit log queries.
G. Each role environment SHALL have distinct Git identities including unique name and email configurations.
H. Each role environment SHALL use role-specific GPG signing for Git commits.
I. Each role environment SHALL use role-specific GitHub Personal Access Tokens with minimal required scopes.
J. Each role environment SHALL use separate SSH keys for repository access.
K. Role environments SHALL have isolated file systems that prevent cross-role data leakage.
L. The system SHALL provide four distinct Docker services: dev, qa, ops, and mgmt.
M. Each role environment SHALL have a unique Git user.name configuration.
N. Each role environment SHALL have a unique Git user.email configuration.
O. The GitHub CLI SHALL be authenticated with role-appropriate Personal Access Token scopes for each role.
P. SSH keys SHALL be mounted per role from the host filesystem.
Q. Credentials SHALL NOT be shared between different role environments.
R. File permissions SHALL enforce role boundaries between environments.
S. Documentation SHALL explain what each role can do within its environment.
T. Documentation SHALL explain what each role cannot do outside its designated permissions.

*End* *Role-Based Environment Separation* | **Hash**: 03138c47
---

# REQ-d00056: Cross-Platform Development Support

**Level**: Dev | **Status**: Draft | **Implements**: o00050

## Rationale

Teams using mixed operating systems waste time on platform-specific issues. Docker's cross-platform nature enables identical developer experiences regardless of host OS. This requirement ensures that development environments function identically across Windows (with WSL2), Linux, and macOS, which is critical for small teams where each developer may use different platforms. By enforcing platform-agnostic configurations and testing, the system eliminates the need for manual platform-specific workarounds.

## Assertions

A. Development environments SHALL function identically on Windows, Linux, and macOS.
B. The system SHALL NOT require platform-specific code paths in core workflows.
C. The system SHALL NOT require manual configuration based on platform.
D. Docker Compose files SHALL use platform-agnostic volume paths.
E. Setup scripts SHALL detect the host OS and adjust automatically.
F. Documentation SHALL cover Windows with WSL2 installation and usage.
G. Documentation SHALL cover Linux native installation and usage.
H. Documentation SHALL cover macOS native installation and usage.
I. File permission handling SHALL respect host OS differences automatically.
J. Core workflows SHALL NOT contain platform-specific workarounds.
K. Core workflows SHALL NOT contain conditional logic based on platform.
L. Terminal prompts SHALL be compatible with bash shell.
M. Terminal prompts SHALL be compatible with zsh shell.
N. Scripts SHALL be compatible with bash shell.
O. Scripts SHALL be compatible with zsh shell.
P. The development environment SHALL be tested on Windows 11 with WSL2 and Docker Desktop.
Q. The development environment SHALL be tested on Ubuntu 24.04 with Docker Engine.
R. The development environment SHALL be tested on macOS Intel with Docker Desktop.
S. The development environment SHALL be tested on macOS Apple Silicon with Docker Desktop.
T. Documentation SHALL NOT contain Windows-only instructions except for platform-specific prerequisites.
U. Documentation SHALL NOT contain macOS-only instructions except for platform-specific prerequisites.
V. Documentation SHALL NOT contain Linux-only instructions except for platform-specific prerequisites.
W. File mounts SHALL work correctly on Windows with WSL2.
X. File mounts SHALL work correctly on Linux.
Y. File mounts SHALL work correctly on macOS.
Z. Setup documentation SHALL include platform-specific prerequisites when required.

*End* *Cross-Platform Development Support* | **Hash**: 6e05c815
---

# REQ-d00057: CI/CD Environment Parity

**Level**: Dev | **Status**: Draft | **Implements**: o00052

## Rationale

This requirement establishes environment parity between local development and CI/CD pipelines to prevent the common problem of "works on my machine" failures. Environment drift—where local and CI environments differ in tool versions, configurations, or dependencies—causes builds that pass locally to fail in CI, wasting developer time and delaying releases. By mandating identical Docker images and configurations across both environments, this requirement ensures reproducible builds and predictable behavior. For FDA-regulated software, this parity is critical because the validated build environment must be testable and verifiable in local development before deployment to production. This requirement implements the operational requirement REQ-o00052 for CI/CD environment consistency.

## Assertions

A. Local development environments SHALL use identical Docker images as CI/CD pipelines.
B. The system SHALL use shared Dockerfiles for both local development and GitHub Actions.
C. Tool versions SHALL be identical in local development containers and CI runners.
D. The system SHALL use the same secrets management approach (Doppler) in both local and CI environments.
E. Build commands SHALL be reproducible and identical across local and CI environments.
F. Artifact generation processes SHALL be identical in local development and CI pipelines.
G. Environment variables SHALL be managed consistently across local and CI environments.
H. GitHub Actions workflows SHALL use the same Dockerfiles as local development.
I. The system SHALL include automated checks to detect tool version mismatches between environments.
J. Build commands SHALL be documented and executable in both local and CI environments.
K. Secrets SHALL be accessed via Doppler in both local development and CI environments.
L. CI logs SHALL include tool version verification output.
M. Local development documentation SHALL include commands to verify environment parity.

*End* *CI/CD Environment Parity* | **Hash**: 1b1aaea0
---

# REQ-d00058: Secrets Management via Doppler

**Level**: Dev | **Status**: Draft | **Implements**: p00005

## Rationale

Hardcoded secrets in scripts or environment variables violate security best practices and FDA audit requirements. Doppler provides centralized secret management with comprehensive audit trails, enabling compliance with access control and traceability requirements for FDA 21 CFR Part 11. Secrets are injected at runtime and never persisted to disk, Git repositories, or container images, ensuring that credential exposure is minimized and all access is traceable. This approach supports secret rotation without code changes or redeployment, reducing downtime and security risk during credential updates.

## Assertions

A. Development environments SHALL integrate Doppler secrets management for all credential access.
B. The system SHALL eliminate hardcoded credentials from all code and configuration files.
C. Doppler integration SHALL provide audit trails of all secret access events.
D. The system SHALL enable secret rotation without requiring code changes.
E. Doppler integration SHALL provide environment-specific secret projects for dev, staging, and prod environments.
F. Doppler integration SHALL provide role-specific service tokens for automated access.
G. Doppler integration SHALL provide personal tokens for individual developer access.
H. Doppler SHALL maintain audit logs showing who accessed secrets and when.
I. The system SHALL support secret rotation without redeploying containers.
J. The system SHALL implement zero-knowledge architecture where secrets are never stored in Git.
K. The system SHALL implement zero-knowledge architecture where secrets are never stored in environment variables.
L. The Doppler CLI SHALL be installed in all role containers.
M. GitHub tokens SHALL be accessed via doppler run -- gh auth login command.
N. GCP credentials SHALL be accessed via doppler run -- gcloud auth login command.
O. Git history SHALL NOT contain any secrets.
P. Dockerfiles SHALL NOT contain any secrets.
Q. Compose files SHALL NOT contain any secrets.
R. Doppler audit log SHALL capture all secret access events.
S. Documentation SHALL cover Doppler setup procedures for each role.
T. Documentation SHALL include secret rotation procedures.

*End* *Secrets Management via Doppler* | **Hash**: cd79209a
---

# REQ-d00059: Development Tool Specifications

**Level**: Dev | **Status**: Draft | **Implements**: o00041

## Rationale

FDA 21 CFR Part 11 validation requires reproducible software builds with documented tool versions and justifications. This requirement establishes specific tool versions selected for stability, long-term support, and regulatory compliance. LTS (Long-Term Support) versions provide security updates without breaking changes, while explicit version pinning enables validation protocols and audit trail requirements. The requirement supports Infrastructure Operations Requirements (REQ-o00041) by defining the standardized toolchain across development, QA, operations, and management roles.

## Assertions

A. The development environment SHALL include Flutter 3.38.7 from the stable channel.
B. The development environment SHALL include Android SDK cmdline-tools version 11076708.
C. The development environment SHALL include Android build-tools version 34.0.0.
D. The development environment SHALL include Android platform API 34.
E. The development environment SHALL include OpenJDK 17 for Android builds.
F. The development environment SHALL include Node.js 20.x LTS series.
G. The development environment SHALL include Python 3.11 or higher, with 3.12 preferred.
H. The development environment SHALL include Git version 2.40 or higher.
I. The development environment SHALL include GitHub CLI version 2.40 or higher.
J. The QA environment SHALL include Playwright latest version for headless browser testing.
K. The QA environment SHALL include Flutter integration test framework.
L. The operations environment SHALL include Terraform version 1.9 or higher.
M. The operations environment SHALL include gcloud CLI latest version.
N. The operations environment SHALL include Cloud SQL Proxy latest version.
O. The management environment SHALL include Pandoc for document conversion.
P. The management environment SHALL include jq for JSON processing.
Q. All tool versions SHALL be pinned in Dockerfiles with explicit version numbers.
R. The system SHALL NOT use 'latest' tags in Dockerfiles except where explicitly justified in documentation.
S. The system SHALL verify SHA256 checksums for all downloaded tool installers.
T. The system SHALL generate a Software Bill of Materials (SBOM) for each container image.
U. The system SHALL execute a tool version verification script on container startup.
V. Each tool version selection SHALL include documented rationale for stability, security, or compatibility requirements.
W. Tool selection rationale SHALL be documented in ADR-006.
X. Documentation SHALL include a tool update policy defining version upgrade procedures.
Y. Documentation SHALL include testing procedures for tool version updates.

*End* *Development Tool Specifications* | **Hash**: 67a92cff
---

# REQ-d00060: VS Code Dev Containers Integration

**Level**: Dev | **Status**: Draft | **Implements**: d00027

## Rationale

VS Code Dev Containers eliminate manual environment setup and ensure every developer uses identical tooling. The 'Reopen in Container' feature makes switching between roles seamless, reinforcing the role-based development practice required by REQ-d00027. This dramatically reduces onboarding time for new team members by providing pre-configured, containerized development environments with role-appropriate tooling.

## Assertions

A. The system SHALL provide VS Code Dev Containers configuration enabling developers to open projects directly in containerized environments.
B. The system SHALL provide four distinct `.devcontainer/` configurations corresponding to dev, qa, ops, and mgmt roles.
C. Each devcontainer.json SHALL specify the appropriate base image for its role.
D. Each devcontainer.json SHALL list role-specific VS Code extensions for automatic installation.
E. Dev Containers SHALL persist Git configuration from the host system or specify configuration per role.
F. Dev Containers SHALL mount SSH keys securely and read-only from the host `~/.ssh/` directory.
G. Dev Containers SHALL map workspace folders correctly for each role.
H. Dev Containers SHALL provide port forwarding for development servers.
I. Dev Containers SHALL provide an integrated terminal with role-specific prompt configuration.
J. Dev Containers SHALL integrate with Docker Compose for multi-container debugging scenarios.
K. Documentation SHALL include instructions for using the 'Reopen in Container' feature.
L. First-time Dev Container setup SHALL complete in less than 5 minutes after Docker installation.

*End* *VS Code Dev Containers Integration* | **Hash**: d8498586
---

# REQ-d00061: Automated QA Workflow

**Level**: Dev | **Status**: Draft | **Implements**: o00052

## Rationale

Automated QA workflows provide fast feedback on code changes and ensure every pull request meets quality standards before merge. Running tests in the same container used locally eliminates environment inconsistencies. PDF reports provide regulatory audit trail of testing evidence required for FDA 21 CFR Part 11 compliance. GitHub integration makes results visible without leaving the PR workflow, streamlining the review process.

## Assertions

A. The system SHALL provide a GitHub Actions workflow file at `.github/workflows/qa-automation.yml`.
B. The workflow SHALL trigger automatically when a pull request is opened or updated.
C. The workflow SHALL execute all tests within the qa-container Docker image.
D. The system SHALL execute Flutter integration tests using the command `flutter test integration_test`.
E. Flutter tests SHALL produce JUnit XML output format.
F. The system SHALL execute Playwright end-to-end tests using the command `npx playwright test`.
G. Playwright tests SHALL produce HTML reports.
H. The system SHALL generate a consolidated PDF summary report of all test results.
I. The PDF report SHALL be generated using Playwright's built-in PDF export functionality.
J. The system SHALL post test result status to the pull request using the GitHub Checks API.
K. The system SHALL post a comment on the pull request containing test pass/fail status and links to test artifacts.
L. The system SHALL upload all test artifacts to GitHub Actions artifact storage.
M. The system SHALL NOT upload test artifacts to external storage systems.
N. Test artifacts for pull request testing SHALL be retained for 90 days.
O. Test artifacts for commits tagged as releases SHALL be retained permanently.
P. The qa-container environment used in CI SHALL be identical to the qa-container used for local QA role testing.

*End* *Automated QA Workflow* | **Hash**: 50c6e242
---

# REQ-d00062: Environment Validation & Change Control

**Level**: Dev | **Status**: Draft | **Implements**: p00010

## Rationale

FDA 21 CFR Part 11 requires validated computer systems. Development environments that produce regulatory submissions must be validated to ensure reproducible, auditable results. IQ/OQ/PQ protocols demonstrate that the environment is installed correctly, operates as intended, and performs consistently. This compositional requirement encompasses installation qualification, operational qualification, performance qualification, and change control procedures for the development environment.

## Assertions

A. Development environments SHALL undergo formal validation using IQ/OQ/PQ protocols to ensure FDA compliance.
B. Changes to development environments SHALL be managed through documented change control procedures.
C. This requirement SHALL be implemented through REQ-d00090, REQ-d00091, REQ-d00092, and REQ-d00093.

*End* *Environment Validation & Change Control* | **Hash**: 9a5588aa

---

# REQ-d00090: Development Environment Installation Qualification

**Level**: Dev | **Status**: Draft | **Implements**: d00062

## Rationale

Installation Qualification (IQ) verifies that development environment components are installed correctly according to specifications. This includes verifying Docker installation, container image builds, service health checks, required infrastructure, and tool version compliance. IQ provides documented evidence that the environment was installed as designed, forming the foundation for FDA 21 CFR Part 11 compliance.

## Assertions

A. Docker installation SHALL be verified on all target platforms.
B. Container images SHALL build successfully on all target platforms.
C. Health checks SHALL pass for all services in the development environment.
D. Required Docker volumes SHALL be created as specified.
E. Required Docker networks SHALL be created as specified.
F. Tool versions SHALL match specifications defined in environment documentation.
G. IQ protocol SHALL be documented in `docs/validation/dev-environment/IQ.md`.
H. Test results templates SHALL be provided for IQ protocol execution.

*End* *Development Environment Installation Qualification* | **Hash**: 554f4e07

---

# REQ-d00091: Development Environment Operational Qualification

**Level**: Dev | **Status**: Draft | **Implements**: d00062

## Rationale

Operational Qualification (OQ) demonstrates that development environment tools function correctly under normal operating conditions. This includes verifying that core development tools execute their intended operations successfully. OQ provides documented evidence that the environment operates as intended, supporting FDA 21 CFR Part 11 compliance for validated computer systems.

## Assertions

A. Each development tool SHALL execute basic operations correctly.
B. Git SHALL be able to clone repositories from remote sources.
C. Flutter SHALL be able to create new projects.
D. Flutter SHALL be able to build projects for target platforms.
E. Playwright SHALL be able to run sample browser automation tests.
F. Terraform SHALL be able to validate infrastructure configurations.
G. Doppler SHALL be able to retrieve secrets from the secrets manager.
H. The gcloud CLI SHALL be able to authenticate with Google Cloud Platform.
I. OQ protocol SHALL be documented in `docs/validation/dev-environment/OQ.md`.
J. Test results templates SHALL be provided for OQ protocol execution.

*End* *Development Environment Operational Qualification* | **Hash**: fe899a74

---

# REQ-d00092: Development Environment Performance Qualification

**Level**: Dev | **Status**: Draft | **Implements**: d00062

## Rationale

Performance Qualification (PQ) establishes baseline performance metrics and verifies that the development environment produces consistent results across platforms. This includes monitoring build times, test execution times, resource usage, and output reproducibility. PQ provides documented evidence that the environment performs consistently, supporting FDA 21 CFR Part 11 requirements for reproducible results.

## Assertions

A. Build times SHALL be measured and verified to be within acceptable ranges.
B. Test execution times SHALL be baselined and monitored.
C. Container resource usage SHALL be monitored during development operations.
D. The development environment SHALL produce identical outputs across supported platforms.
E. PQ protocol SHALL be documented in `docs/validation/dev-environment/PQ.md`.
F. Test results templates SHALL be provided for PQ protocol execution.

*End* *Development Environment Performance Qualification* | **Hash**: 5185eb02

---

# REQ-d00093: Development Environment Change Control

**Level**: Dev | **Status**: Draft | **Implements**: d00062

## Rationale

Change control procedures ensure that modifications to the development environment are reviewed, documented, and validated before deployment. This protects the validated state of the environment and maintains FDA 21 CFR Part 11 compliance. Proper change control includes review processes, version documentation, re-validation requirements, image integrity verification, and deprecation policies.

## Assertions

A. Dockerfile changes SHALL require pull request review before merge.
B. Tool version changes SHALL be documented in an Architecture Decision Record (ADR).
C. Major environment changes SHALL require re-execution of applicable IQ/OQ/PQ protocols.
D. Docker images SHALL be tagged with semantic versions.
E. Old environment versions SHALL be subject to a documented deprecation policy.
F. Dockerfile changes SHALL trigger a validation review checklist.
G. Container images SHALL be signed with Cosign for integrity verification.
H. A Software Bill of Materials (SBOM) SHALL be generated and stored with each image version.
I. Deprecation notices SHALL be provided at least 90 days before environment version retirement.

*End* *Development Environment Change Control* | **Hash**: 25b6fc05
---

# REQ-d00063: Shared Workspace and File Exchange

**Level**: Dev | **Status**: Draft | **Implements**: d00027

## Rationale

Development environments require isolated yet accessible workspaces that function consistently across Windows and Linux host systems. Docker named volumes provide platform-agnostic storage that eliminates file system permission conflicts and prevents cross-platform access issues (such as accessing Linux filesystems from Windows, which causes corruption). This approach maintains role separation while enabling controlled file exchange between containers when collaboration is needed. The design supports both containerized execution and host-based IDE editing workflows.

## Assertions

A. The system SHALL provide a named Docker volume 'clinical-diary-repos' for repository storage.
B. The system SHALL provide a named Docker volume 'clinical-diary-exchange' for inter-role file transfer.
C. All development containers SHALL mount the 'clinical-diary-repos' volume to '/workspace/repos'.
D. All development containers SHALL mount the 'clinical-diary-exchange' volume to '/workspace/exchange'.
E. The exchange volume SHALL be configured with world-readable permissions within containers.
F. The system SHALL support bind mounts for source code to enable host IDE editing.
G. The system SHALL preserve file permissions correctly across container boundaries on all supported platforms.
H. Workspace paths SHALL be consistent across all container instances.
I. The system SHALL NOT expose host file system internals to containers running on opposite operating systems.
J. The system SHALL NOT allow direct access to Linux filesystems from Windows host systems.
K. The system SHALL NOT allow direct access to Windows filesystems from Linux containers in ways that create platform-specific path issues.
L. The system SHALL NOT use symlinks or hard links that break cross-platform compatibility.
M. The docker-compose.yml configuration SHALL define all required named volumes.
N. Documentation SHALL explain the purpose of each volume type.
O. Documentation SHALL describe usage patterns for workspace volumes and exchange volumes.

*End* *Shared Workspace and File Exchange* | **Hash**: c3be06e7
---

## Tool Version Rationale

### Flutter 3.38.7
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

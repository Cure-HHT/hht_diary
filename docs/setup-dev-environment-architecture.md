# Development Environment Architecture

**Version**: 2.0
**Date**: 2026-02-23
**Related**: docs/adr/ADR-006-docker-dev-environments.md

## IMPLEMENTS REQUIREMENTS

- REQ-d00027: Containerized Development Environments
- REQ-d00055: Role-Based Environment Separation
- REQ-d00056: Cross-Platform Development Support
- REQ-d00057: CI/CD Environment Parity
- REQ-d00058: Secrets Management via Doppler
- REQ-d00060: VS Code Dev Containers Integration
- REQ-d00063: Shared Workspace and File Exchange

This document provides architectural diagrams and technical details for the Clinical Diary development environment infrastructure.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Host Machine                             │
│                   (Windows / Linux / macOS)                      │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Docker Engine                         │   │
│  │                                                           │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │   devops     │  │   devops     │  │    audit     │  │   │
│  │  │   -main      │  │   -sponsor   │  │  container   │  │   │
│  │  │              │  │              │  │              │  │   │
│  │  │  Terraform   │  │  Terraform   │  │  psql, gcloud│  │   │
│  │  │  gcloud      │  │  gcloud      │  │  OTS, Doppler│  │   │
│  │  │  Doppler     │  │  Doppler     │  │  (read-only) │  │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │   │
│  │         │                  │                  │          │   │
│  │         └──────────────────┼──────────────────┘          │   │
│  │                            │                             │   │
│  │  ┌────────────────────────┴─────────────────────────┐  │   │
│  │  │              ci container (build-only)             │  │   │
│  │  │  Flutter, Android SDK, Node, Python, Playwright   │  │   │
│  │  │  (Used by GitHub Actions; not run locally)        │  │   │
│  │  └──────────────────────────────────────────────────┘  │   │
│  │                                                           │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │              Named Volumes                          │ │   │
│  │  │  - clinical-diary-repos  (code storage)            │ │   │
│  │  │  - clinical-diary-exchange  (file sharing)         │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   VS Code + Dev Containers              │   │
│  │    "Reopen in Container" → Select: DevOps or Audit      │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Docker Compose Service Architecture

```
docker-compose.yml
├── services:
│   ├── ci:
│   │   ├── build: ./docker/ci.Dockerfile
│   │   ├── profiles: [build-only]  (not started locally)
│   │   └── resources:
│   │       ├── cpus: 2
│   │       └── memory: 6G
│   │
│   ├── devops-main:
│   │   ├── build: ./docker/devops.Dockerfile
│   │   ├── environment:
│   │   │   ├── ROLE=devops-main
│   │   │   ├── TF_WORKSPACE=admin
│   │   │   └── (injected via Doppler)
│   │   ├── volumes:
│   │   │   ├── ../../infrastructure/terraform:/workspace/terraform
│   │   │   ├── ../../:/workspace/src:ro
│   │   │   ├── ~/.ssh:/home/devuser/.ssh:ro
│   │   │   └── ~/.gitconfig:/home/devuser/.gitconfig.host:ro
│   │   └── resources:
│   │       ├── cpus: 2
│   │       └── memory: 4G
│   │
│   ├── devops-sponsor:
│   │   ├── build: ./docker/devops.Dockerfile
│   │   ├── environment:
│   │   │   ├── ROLE=devops-sponsor
│   │   │   └── SPONSOR_NAME=${SPONSOR_NAME:-}
│   │   ├── volumes:
│   │   │   ├── ../../infrastructure/terraform:/workspace/terraform
│   │   │   ├── ../../sponsor/${SPONSOR_NAME}:/workspace/sponsor:ro
│   │   │   ├── ../../:/workspace/src:ro
│   │   │   ├── ~/.ssh:/home/devuser/.ssh:ro
│   │   │   └── ~/.gitconfig:/home/devuser/.gitconfig.host:ro
│   │   └── resources:
│   │       ├── cpus: 2
│   │       └── memory: 4G
│   │
│   └── audit:
│       ├── build: ./docker/audit.Dockerfile
│       ├── volumes:
│       │   ├── ../../:/workspace/src:ro  (read-only!)
│       │   ├── ../../infrastructure/terraform:/workspace/terraform:ro
│       │   └── ~/.ssh:/home/devuser/.ssh:ro
│       └── resources:
│           ├── cpus: 2
│           └── memory: 2G
│
├── volumes:
│   ├── clinical-diary-repos:  (persistent, named)
│   └── clinical-diary-exchange:  (persistent, named)
│
└── networks:
    └── clinical-diary-net:  (bridge, default)
```

---

## Dockerfile Hierarchy

```
┌──────────────────────────────────────┐
│      debian:12-slim (base image)     │
│      (matches production runtime)    │
└──────────────┬───────────────────────┘
               │
       ┌───────┼────────┬──────────────┐
       │       │        │              │
       ▼       │        ▼              ▼
┌──────────────┐│ ┌──────────┐  ┌──────────┐
│ ci           ││ │ devops   │  │ audit    │
│.Dockerfile   ││ │.Docker-  │  │.Docker-  │
│              ││ │ file     │  │ file     │
│+ Flutter     ││ │+ Terra-  │  │+ psql    │
│+ Android SDK ││ │  form    │  │+ gcloud  │
│+ Node/Python ││ │+ gcloud  │  │+ OTS     │
│+ Playwright  ││ │+ Doppler │  │+ Doppler │
│+ Gitleaks    ││ │+ psql    │  │(minimal) │
│+ Squawk      ││ └──────────┘  └──────────┘
│+ gcloud      ││
│+ psql        ││
│(all-in-one)  ││
└──────────────┘│
                │
  All images build independently
  from debian:12-slim (no chaining)
```

---

## Role-Based Tool Matrix

| Tool / Feature | ci | devops | audit |
| --- | --- | --- | --- |
| **Git** | ✅ | ✅ | ✅ |
| **Doppler CLI** | ✅ | ✅ | ✅ |
| **gcloud CLI** | ✅ | ✅ | ✅ |
| **Cloud SQL Proxy** | ✅ | ✅ | ✅ |
| **PostgreSQL client (psql)** | ✅ | ✅ | ✅ |
| **Python 3.11** | ✅ | ✅ | ✅ |
| **Node.js 20** | ✅ | ❌ | ❌ |
| **Flutter 3.38** | ✅ | ❌ | ❌ |
| **Android SDK** | ✅ | ❌ | ❌ |
| **Playwright** | ✅ | ❌ | ❌ |
| **Gitleaks** | ✅ | ❌ | ❌ |
| **Squawk** | ✅ | ❌ | ❌ |
| **GitHub CLI (gh)** | ✅ | ❌ | ❌ |
| **Claude Code CLI** | ✅ | ❌ | ❌ |
| **OpenJDK 17** | ✅ | ❌ | ❌ |
| **Terraform** | ❌ | ✅ | ❌ |
| **opentimestamps (ots)** | ❌ | ❌ | ✅ |
| **Write Access** | ✅ | ✅ | ❌ |
| **Used in CI** | ✅ | ❌ | ❌ |

---

## Secrets Management Flow (Doppler)

```
┌──────────────────────────────────────────────────────────────┐
│                     Doppler Cloud                             │
│                  (Zero-knowledge vault)                       │
│                                                                │
│  Projects:                                                    │
│  ├── clinical-diary-dev    (development secrets)             │
│  ├── clinical-diary-staging (staging secrets)                │
│  └── clinical-diary-prod   (production secrets)              │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 │ API Request (authenticated)
                 │
    ┌────────────┴──────────────┬──────────────────────────────┐
    │                           │                              │
    ▼                           ▼                              ▼
┌─────────────┐          ┌─────────────┐              ┌─────────────┐
│ devops-main │          │   devops-   │              │    audit    │
│  container  │          │   sponsor   │              │  container  │
│             │          │  container  │              │             │
│  Doppler    │          │  Doppler    │              │  Doppler    │
│   CLI       │          │   CLI       │              │   CLI       │
│             │          │             │              │             │
│  Secrets    │          │  Secrets    │              │  Secrets    │
│  injected   │          │  injected   │              │  injected   │
│  at runtime │          │  at runtime │              │  at runtime │
└─────────────┘          └─────────────┘              └─────────────┘

Flow:
1. Developer runs: doppler run -- gh auth login
2. Doppler CLI fetches secrets from cloud
3. Secrets injected into command environment
4. Command executes with secrets
5. Secrets never persisted to disk
6. Audit log records access
```

---

## VS Code Dev Containers Integration

```
.devcontainer/
├── devcontainer.json           (default: devops-main)
│   {
│     "name": "Clinical Diary - DevOps",
│     "dockerComposeFile": [
│       "../tools/dev-env/docker-compose.yml"
│     ],
│     "service": "devops-main",
│     "workspaceFolder": "/workspace/terraform",
│     "remoteUser": "devuser",
│     "customizations": {
│       "vscode": {
│         "extensions": [
│           "hashicorp.terraform",
│           "googlecloudtools.cloudcode"
│         ]
│       }
│     }
│   }
│
└── audit/
    └── devcontainer.json
        {
          "name": "Clinical Diary - Audit (Read-Only)",
          "service": "audit",
          "workspaceFolder": "/workspace",
          "remoteUser": "devuser",
          "customizations": {
            "vscode": {
              "extensions": [
                "ckolkman.vscode-postgres"
              ]
            }
          }
        }

User Experience:
1. Open VS Code
2. Command Palette → "Dev Containers: Reopen in Container"
3. Select: DevOps (default) or Audit
4. VS Code reopens inside container with role-specific tools
5. Extensions auto-installed per role
```

---

## CI/CD Integration (GitHub Actions)

```
GitHub Repository
│
├── Pull Request Created/Updated
│   │
│   ▼
│   .github/workflows/qa-automation.yml
│   │
│   ├── Build ci container from ci.Dockerfile
│   │   (same Dockerfile as CI image builds!)
│   │
│   ├── Run Flutter Tests
│   │   flutter test integration_test
│   │
│   ├── Run Playwright Tests
│   │   npx playwright test
│   │
│   ├── Generate PDF Report
│   │   (Playwright built-in PDF)
│   │
│   ├── Post GitHub Check
│   │   gh api repos/.../check-runs
│   │
│   ├── Post PR Comment
│   │   gh pr comment --body "Results..."
│   │
│   └── Upload Artifacts
│       (GitHub Actions artifacts, 90 days retention)
│
└── Tag/Release Created
    │
    ▼
    .github/workflows/build-publish-images.yml
    │
    ├── Build 3 images IN PARALLEL (all from debian:12-slim):
    │   ├── ci.Dockerfile      → clinical-diary-ci
    │   ├── devops.Dockerfile  → clinical-diary-devops
    │   └── audit.Dockerfile   → clinical-diary-audit
    │
    ├── Sign ALL images (Cosign keyless via GitHub OIDC)
    │
    ├── Generate SBOMs (Syft) for ALL images
    │
    ├── Attach SBOM attestations
    │
    ├── Verify ALL image signatures
    │
    └── Push to GHCR (GitHub Container Registry)
        ghcr.io/cure-hht/clinical-diary-{ci,devops,audit}
```

---

## Data Flow: QA Automation

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Pull Request                       │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │ Webhook Trigger
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│             GitHub Actions Runner                                │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Step 1: Build ci container                            │    │
│  │    docker build -f tools/dev-env/docker/ci.Dockerfile  │    │
│  └────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Step 2: Checkout PR code                              │    │
│  │    gh pr checkout $PR_NUMBER                           │    │
│  └────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Step 3: Run Tests in Container                        │    │
│  │    docker compose exec ci bash                         │    │
│  │      - flutter test integration_test                   │    │
│  │      - npx playwright test                             │    │
│  └────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Step 4: Generate Reports                              │    │
│  │    - JUnit XML from Flutter                            │    │
│  │    - HTML report from Playwright                       │    │
│  │    - Consolidated PDF via Playwright PDF export        │    │
│  └────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Step 5: Upload Artifacts                              │    │
│  │    - Upload to GitHub Actions artifacts                │    │
│  │    - Retention: 90 days (ephemeral)                    │    │
│  │    - Permanent for release tags                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Step 6: GitHub Integration                            │    │
│  │    - Post Check Run (pass/fail status)                 │    │
│  │    - Comment on PR with results link                   │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Pull Request Updated                         │
│                                                                   │
│  ✅ Checks: QA Automation (passed)                              │
│  💬 Comment: QA passed - Flutter: 24/24, Playwright: 12/12     │
│  📄 Artifacts: summary.pdf, playwright-report.zip               │
└─────────────────────────────────────────────────────────────────┘
```

---

## File System Layout

```
Host Machine:
~/projects/clinical-diary/
├── .devcontainer/
│   ├── devcontainer.json        (default → devops-main)
│   └── audit/
│       └── devcontainer.json    (audit service)
│
├── apps/                        ← Application source code
│   ├── daily-diary/
│   └── common-dart/
│
├── packages/                    ← Shared Flutter packages
│
├── sponsor/                     ← Per-sponsor customization
│   └── {sponsor-name}/
│
├── tools/
│   └── dev-env/
│       ├── docker/
│       │   ├── ci.Dockerfile
│       │   ├── devops.Dockerfile
│       │   └── audit.Dockerfile
│       ├── docker-compose.yml
│       ├── docker-compose.ci.yml
│       ├── setup.sh
│       └── README.md
│
├── infrastructure/
│   └── terraform/               ← Mounted into devops containers
│
└── database/                    ← Schema, migrations, triggers


Inside Containers (devops-main):
/workspace/
├── terraform/                   ← Bind mount from host
│   ├── main.tf
│   ├── variables.tf
│   └── modules/
└── src/                         ← Bind mount (read-only)
    └── (full repo)

Inside Containers (audit):
/workspace/
├── src/                         ← Bind mount (read-only)
└── terraform/                   ← Bind mount (read-only)


Container User Home:
/home/devuser/                   ← Container user home (uid 1000)
├── .gitconfig.host              ← Mounted from host (read-only)
├── .ssh/                        ← Mounted from host (read-only)
│   ├── id_ed25519
│   └── authorized_keys
└── .config/
    └── doppler/                 ← Doppler config
```

---

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Docker Bridge Network                    │
│                      (clinical-diary-net)                        │
│                                                                   │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐       │
│   │ devops-main  │   │devops-sponsor│   │    audit     │       │
│   │ 172.18.0.2   │   │ 172.18.0.3   │   │ 172.18.0.4   │       │
│   └──────────────┘   └──────────────┘   └──────────────┘       │
│                                                                   │
│   All containers can communicate with each other                │
│   (May add network segmentation later if needed)                │
│                                                                   │
│   Note: ci container runs only in CI (build-only profile),      │
│   not on the local Docker network.                              │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ Bridge to Host
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Host Network                                │
│  - Internet access                                               │
│  - GitHub API (api.github.com)                                  │
│  - Doppler API (api.doppler.com)                                │
│  - Google Cloud APIs                                             │
│  - Package registries (npm, pub.dev, etc.)                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Security Boundaries

```
┌────────────────────────────────────────────────────────────────┐
│                    Host File System                             │
│                  (User owns everything)                         │
└─────────┬──────────────────────────────────────────────────────┘
          │
          │ Docker Daemon (runs as root)
          ▼
┌────────────────────────────────────────────────────────────────┐
│              Container User: devuser (uid 1000, non-root)      │
│                                                                  │
│  Permissions:                                                   │
│  - devops: Read/Write /workspace/terraform                     │
│  - devops: Read-Only /workspace/src                            │
│  - audit: Read-Only all workspace volumes                      │
│  - No access: Host system files outside mounts                 │
│                                                                  │
│  Network:                                                       │
│  - Outbound: Internet access (GitHub, Doppler, GCP)            │
│  - Inbound: None (no ports exposed by default)                 │
│  - Container-to-Container: Allowed within Docker network       │
│                                                                  │
│  Secrets:                                                       │
│  - Injected at runtime via Doppler                             │
│  - Never written to disk                                       │
│  - Environment variables cleared after command execution       │
└────────────────────────────────────────────────────────────────┘
```

---

## Validation Checkpoints

```
Environment Build:
│
├─ IQ (Installation Qualification)
│   ├─ Docker Desktop installed?
│   ├─ Docker Compose available?
│   ├─ Images build successfully?
│   ├─ Containers start without errors?
│   ├─ Health checks pass?
│   └─ Volumes created correctly?
│
├─ OQ (Operational Qualification)
│   ├─ Git works (clone, commit, push)?
│   ├─ Terraform validates config? (devops)
│   ├─ gcloud authenticated? (devops, audit)
│   ├─ psql connects to database? (devops, audit)
│   ├─ Doppler retrieves secrets?
│   ├─ ots verify works? (audit)
│   └─ All tools report correct versions?
│
└─ PQ (Performance Qualification)
    ├─ Container startup < 30 sec?
    ├─ CI image builds in < 20 min?
    ├─ Cross-platform builds produce identical binaries?
    └─ Resource usage within limits?
```

---

## Maintenance & Updates

```
Quarterly Review Cycle:

Month 1:
├─ Check for security updates
│   ├─ Base OS (Debian 12-slim)
│   ├─ Flutter stable channel
│   ├─ Node.js LTS
│   └─ Tool dependencies
│
├─ Review tool versions (.github/versions.env)
│   ├─ Any deprecation notices?
│   ├─ New LTS releases available?
│   └─ Security advisories?
│
└─ Update ADR-006 with decisions

Month 2:
├─ Create feature branch
├─ Update Dockerfiles + versions.env
├─ Run IQ/OQ/PQ validation
├─ Document changes
└─ Merge if validation passes

Month 3:
├─ Monitor for issues
├─ Gather developer feedback
└─ Plan next quarter's updates
```

---

## Disaster Recovery

**Backup Strategy**:
- Source code: Git (remote backups)
- Container images: GitHub Container Registry
- Secrets: Doppler (encrypted cloud backup)
- Validation artifacts: GitHub Actions artifacts + permanent archive

**Recovery Procedures**:
1. Fresh developer machine
2. Install Docker Desktop
3. Clone repository
4. Run `tools/dev-env/setup.sh`
5. Developer authenticated via Doppler
6. Environment ready in < 30 minutes

**No local state lost**:
- Code in Git
- Secrets in Doppler
- Container config in repository
- Everything reproducible

---

## Performance Metrics

| Metric | Target | Actual | Notes |
| --- | --- | --- | --- |
| First-time setup | < 30 min | TBD | Includes Docker install + image pull |
| Subsequent startup | < 30 sec | TBD | Container start from stopped state |
| Container size (ci) | < 10 GB | TBD | All-in-one: Flutter + Android + Playwright |
| Container size (devops) | < 2 GB | TBD | Terraform + gcloud |
| Container size (audit) | < 1 GB | TBD | Minimal tools |
| Memory usage (devops) | < 4 GB | TBD | During active operations |
| Memory usage (audit) | < 2 GB | TBD | Read-only queries |
| CPU usage (idle) | < 5% | TBD | Background processes |

---

**References**:
- docs/adr/ADR-006-docker-dev-environments.md
- spec/dev-environment.md
- tools/dev-env/README.md

**Last Updated**: 2026-02-23
**Next Review**: 2026-05-23 (quarterly)

# Development Environment Architecture

**Version**: 1.0
**Date**: 2025-10-26
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
│  │  │     dev      │  │      qa      │  │     ops      │  │   │
│  │  │  container   │  │  container   │  │  container   │  │   │
│  │  │              │  │              │  │              │  │   │
│  │  │  Flutter     │  │  Playwright  │  │  Terraform   │  │   │
│  │  │  Android SDK │  │  Testing     │  │  Supabase    │  │   │
│  │  │  Node/Python │  │  Reports     │  │  Deploy      │  │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │   │
│  │         │                  │                  │          │   │
│  │         └──────────────────┼──────────────────┘          │   │
│  │                            │                             │   │
│  │  ┌────────────────────────┴─────────────────────────┐  │   │
│  │  │              mgmt container                       │  │   │
│  │  │         (Read-only management tools)              │  │   │
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
│  │        "Reopen in Container" → Select Role              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Docker Compose Service Architecture

```
docker-compose.yml
├── services:
│   ├── dev:
│   │   ├── build: ./docker/dev.Dockerfile
│   │   ├── volumes:
│   │   │   ├── clinical-diary-repos:/workspace/repos
│   │   │   ├── clinical-diary-exchange:/workspace/exchange
│   │   │   └── ./src:/workspace/src  (bind mount for editing)
│   │   ├── environment:
│   │   │   └── (injected via Doppler)
│   │   └── resources:
│   │       ├── cpus: 4
│   │       └── memory: 6G
│   │
│   ├── qa:
│   │   ├── build: ./docker/qa.Dockerfile
│   │   ├── volumes:
│   │   │   ├── clinical-diary-repos:/workspace/repos
│   │   │   ├── clinical-diary-exchange:/workspace/exchange
│   │   │   └── ./qa_reports:/workspace/reports (artifacts)
│   │   ├── resources:
│   │       ├── cpus: 4
│   │       └── memory: 6G
│   │
│   ├── ops:
│   │   ├── build: ./docker/ops.Dockerfile
│   │   ├── volumes:
│   │   │   ├── clinical-diary-repos:/workspace/repos
│   │   │   └── clinical-diary-exchange:/workspace/exchange
│   │   ├── resources:
│   │       ├── cpus: 2
│   │       └── memory: 4G
│   │
│   └── mgmt:
│       ├── build: ./docker/mgmt.Dockerfile
│       ├── volumes:
│       │   ├── clinical-diary-repos:/workspace/repos:ro  (read-only!)
│       │   └── clinical-diary-exchange:/workspace/exchange:ro
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

## Dockerfile Inheritance Hierarchy

```
┌──────────────────────────────────────┐
│    ubuntu:24.04 (base image)         │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│      base.Dockerfile                  │
│  - Git, GitHub CLI, curl, jq         │
│  - Node.js 20 LTS                    │
│  - Python 3.11+                      │
│  - Doppler CLI                       │
│  - Claude Code CLI                   │
│  - Common utilities                  │
└──────────────┬───────────────────────┘
               │
       ┌───────┴────────┬──────────┬──────────┐
       │                │          │          │
       ▼                ▼          ▼          ▼
┌──────────────┐ ┌──────────┐ ┌─────────┐ ┌──────────┐
│ dev          │ │ qa       │ │ ops     │ │ mgmt     │
│.Dockerfile   │ │.Docker-  │ │.Docker- │ │.Docker-  │
│              │ │ file     │ │ file    │ │ file     │
│+ Flutter     │ │+ Play-   │ │+ Terra- │ │(minimal) │
│+ Android SDK │ │  wright  │ │  form   │ │          │
│+ Hot reload  │ │+ Testing │ │+ Supa-  │ │          │
│+ Debug tools │ │  tools   │ │  base   │ │          │
└──────────────┘ └──────────┘ └─────────┘ └──────────┘
```

---

## Role-Based Tool Matrix

| Tool / Feature         | dev | qa | ops | mgmt |
|------------------------|-----|----|----|------|
| **Git**                | ✅  | ✅ | ✅ | ✅ (read-only) |
| **GitHub CLI**         | ✅  | ✅ | ✅ | ✅ (read-only) |
| **Doppler CLI**        | ✅  | ✅ | ✅ | ✅ |
| **Node.js 20**         | ✅  | ✅ | ✅ | ❌ |
| **Python 3.11+**       | ✅  | ✅ | ✅ | ❌ |
| **Flutter 3.24**       | ✅  | ✅ | ❌ | ❌ |
| **Android SDK**        | ✅  | ✅ | ❌ | ❌ |
| **Playwright**         | ❌  | ✅ | ❌ | ❌ |
| **Terraform**          | ❌  | ❌ | ✅ | ❌ |
| **Supabase CLI**       | ✅  | ✅ | ✅ | ❌ |
| **Claude Code CLI**    | ✅  | ✅ | ✅ | ❌ |
| **jq (JSON processor)**| ✅  | ✅ | ✅ | ✅ |
| **Write Access**       | ✅  | ✅ | ✅ | ❌ |

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
    ┌────────────┴────────────┬──────────────┬────────────────┐
    │                         │              │                │
    ▼                         ▼              ▼                ▼
┌─────────┐             ┌─────────┐     ┌─────────┐     ┌─────────┐
│   dev   │             │   qa    │     │   ops   │     │  mgmt   │
│container│             │container│     │container│     │container│
│         │             │         │     │         │     │         │
│ Doppler │             │ Doppler │     │ Doppler │     │ Doppler │
│  CLI    │             │  CLI    │     │  CLI    │     │  CLI    │
│         │             │         │     │         │     │         │
│ Secrets │             │ Secrets │     │ Secrets │     │ Secrets │
│ injected│             │ injected│     │ injected│     │ injected│
│ at      │             │ at      │     │ at      │     │ at      │
│ runtime │             │ runtime │     │ runtime │     │ runtime │
└─────────┘             └─────────┘     └─────────┘     └─────────┘

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
├── dev/
│   ├── devcontainer.json
│   │   {
│   │     "name": "Clinical Diary - Developer",
│   │     "dockerComposeFile": "../../tools/dev-env/docker-compose.yml",
│   │     "service": "dev",
│   │     "workspaceFolder": "/workspace/src",
│   │     "customizations": {
│   │       "vscode": {
│   │         "extensions": [
│   │           "dart-code.flutter",
│   │           "dart-code.dart-code",
│   │           "ms-python.python",
│   │           "github.copilot"
│   │         ]
│   │       }
│   │     }
│   │   }
│   └── ...
│
├── qa/
│   ├── devcontainer.json
│   │   {
│   │     "name": "Clinical Diary - QA",
│   │     "service": "qa",
│   │     "extensions": [
│   │       "ms-playwright.playwright",
│   │       "github.copilot"
│   │     ]
│   │   }
│   └── ...
│
├── ops/
│   ├── devcontainer.json
│   │   {
│   │     "name": "Clinical Diary - DevOps",
│   │     "service": "ops",
│   │     "extensions": [
│   │       "hashicorp.terraform",
│   │       "supabase.supabase"
│   │     ]
│   │   }
│   └── ...
│
└── mgmt/
    └── devcontainer.json
        {
          "name": "Clinical Diary - Management (Read-Only)",
          "service": "mgmt",
          "extensions": [
            "github.vscode-pull-request-github"
          ]
        }

User Experience:
1. Open VS Code
2. Command Palette → "Dev Containers: Reopen in Container"
3. Select role: dev / qa / ops / mgmt
4. VS Code reopens inside container with role-specific tools
5. Integrated terminal has role-specific prompt
6. Extensions auto-installed per role
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
│   ├── Build qa-container from Dockerfile
│   │   (same Dockerfile as local dev!)
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
    .github/workflows/build-and-sign.yml
    │
    ├── Build ALL containers (dev, qa, ops, mgmt)
    │
    ├── Run Validation Tests (IQ/OQ checks)
    │
    ├── Generate SBOMs (Syft)
    │   syft packages docker:dev-container
    │
    ├── Sign Images (Cosign)
    │   cosign sign docker:dev-container:1.0.0
    │
    └── Push to GHCR (GitHub Container Registry)
        docker push ghcr.io/org/dev-container:1.0.0
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
│  │  Step 1: Build qa-container                            │    │
│  │    docker build -f tools/dev-env/docker/qa.Dockerfile  │    │
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
│  │    docker run qa-container:latest                      │    │
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
│   ├── dev/
│   ├── qa/
│   ├── ops/
│   └── mgmt/
│
├── src/                      ← Bind mounted to containers
│   ├── flutter_app/
│   ├── web_portal/
│   └── shared_lib/
│
├── tools/
│   └── dev-env/
│       ├── docker/
│       │   ├── base.Dockerfile
│       │   ├── dev.Dockerfile
│       │   ├── qa.Dockerfile
│       │   ├── ops.Dockerfile
│       │   └── mgmt.Dockerfile
│       ├── docker-compose.yml
│       ├── setup.sh
│       └── README.md
│
└── database/                 ← Available in all containers via volume


Inside Containers:
/workspace/
├── repos/                    ← Named volume (persistent)
│   ├── clinical-diary-core/
│   └── sponsor-repos/
│
├── exchange/                 ← Named volume (file sharing between roles)
│   └── (temporary files)
│
└── src/                      ← Bind mount from host (for IDE editing)
    ├── flutter_app/
    ├── web_portal/
    └── shared_lib/


Container-Specific:
/home/ubuntu/               ← Container user home
├── .gitconfig              ← Role-specific (Dev: "Developer")
├── .ssh/                   ← Mounted from host
│   ├── id_ed25519          ← Read-only
│   └── authorized_keys
├── .config/
│   ├── gh/                 ← GitHub CLI auth (via Doppler)
│   └── doppler/            ← Doppler config
└── .profile                ← Role-specific prompt
```

---

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Docker Bridge Network                    │
│                      (clinical-diary-net)                        │
│                                                                   │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │
│   │     dev     │   │     qa      │   │     ops     │          │
│   │ 172.18.0.2  │   │ 172.18.0.3  │   │ 172.18.0.4  │          │
│   └─────────────┘   └─────────────┘   └─────────────┘          │
│                                                                   │
│   ┌─────────────┐                                               │
│   │    mgmt     │                                               │
│   │ 172.18.0.5  │                                               │
│   └─────────────┘                                               │
│                                                                   │
│   All containers can communicate with each other                │
│   (May add network segmentation later if needed)                │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ Bridge to Host
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Host Network                                │
│  - Internet access                                               │
│  - GitHub API (api.github.com)                                  │
│  - Doppler API (api.doppler.com)                                │
│  - Supabase API (project.supabase.co)                           │
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
│              Container User: ubuntu (non-root)                  │
│                                                                  │
│  Permissions:                                                   │
│  - Read/Write: /workspace/repos, /workspace/exchange           │
│  - Read/Write: /workspace/src (bind mount)                     │
│  - Read-Only (mgmt role): All workspace volumes                │
│  - No access: Host system files outside mounts                 │
│                                                                  │
│  Network:                                                       │
│  - Outbound: Internet access (GitHub, Doppler, Supabase)       │
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
│   ├─ GitHub CLI authenticated?
│   ├─ Flutter builds sample app?
│   ├─ Playwright runs sample test?
│   ├─ Terraform validates config?
│   ├─ Doppler retrieves secrets?
│   └─ All tools report correct versions?
│
└─ PQ (Performance Qualification)
    ├─ Flutter build time < 5 min?
    ├─ Container startup < 30 sec?
    ├─ Test suite runs in reasonable time?
    ├─ Cross-platform builds produce identical binaries?
    └─ Resource usage within limits?
```

---

## Maintenance & Updates

```
Quarterly Review Cycle:

Month 1:
├─ Check for security updates
│   ├─ Base OS (Ubuntu)
│   ├─ Flutter stable channel
│   ├─ Node.js LTS
│   └─ Tool dependencies
│
├─ Review tool versions
│   ├─ Any deprecation notices?
│   ├─ New LTS releases available?
│   └─ Security advisories?
│
└─ Update ADR-006 with decisions

Month 2:
├─ Create feature branch
├─ Update Dockerfiles
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
|--------|--------|--------|-------|
| First-time setup | < 30 min | TBD | Includes Docker install + image pull |
| Subsequent startup | < 30 sec | TBD | Container start from stopped state |
| Flutter hot reload | < 1 sec | TBD | Within dev container |
| Test suite (Flutter) | < 5 min | TBD | Integration tests |
| Test suite (Playwright) | < 3 min | TBD | E2E tests |
| Container size (dev) | < 8 GB | TBD | Includes all tools |
| Container size (qa) | < 6 GB | TBD | Testing tools |
| Container size (ops) | < 2 GB | TBD | Infrastructure tools |
| Container size (mgmt) | < 1 GB | TBD | Minimal tools |
| Memory usage (dev) | < 6 GB | TBD | During active development |
| CPU usage (idle) | < 5% | TBD | Background processes |

---

**References**:
- docs/adr/ADR-006-docker-dev-environments.md
- spec/dev-environment.md
- tools/dev-env/README.md

**Last Updated**: 2025-10-26
**Next Review**: 2026-01-26 (quarterly)

# Doppler Configuration Setup

**Overview and Quick Links**

This document provides an overview of Doppler secrets management for the HHT Diary platform. For detailed setup instructions, see the audience-specific guides below.

## IMPLEMENTS REQUIREMENTS
- REQ-d00069: Doppler manifest system
- REQ-o00015: Secrets management

## Documentation Structure

Doppler setup is organized by audience and use case:

| Document | Audience | When to Use |
| --- | --- | --- |
| **[doppler-setup-project.md](./doppler-setup-project.md)** | DevOps / Project Admin | **Once per project** - Initial Doppler infrastructure setup |
| **[doppler-setup-new-sponsor.md](./doppler-setup-new-sponsor.md)** | DevOps / Project Admin | **Each new sponsor** - Onboard pharmaceutical sponsors |
| **[doppler-setup-new-dev.md](./doppler-setup-new-dev.md)** | Software Developers | **Each new developer** - Configure local development environment |

## Quick Start

**Are you...**

- 🏗️ **Setting up Doppler for the first time?** → [doppler-setup-project.md](./doppler-setup-project.md)
- 🏢 **Adding a new pharmaceutical sponsor?** → [doppler-setup-new-sponsor.md](./doppler-setup-new-sponsor.md)
- 👨‍💻 **A new developer joining the team?** → [doppler-setup-new-dev.md](./doppler-setup-new-dev.md)

## Architecture Overview

The HHT Diary platform uses Doppler for centralized secrets management with a nested project structure:

- **hht-diary-core**: Core application secrets and sponsor manifest
  - Configs: `dev`, `staging`, `production`
- **hht-diary-{sponsor}**: Per-sponsor secrets (e.g., `hht-diary-callisto`)
  - Configs: `staging`, `production`

This structure supports the multi-sponsor architecture described in `spec/prd-architecture-multi-sponsor.md`, ensuring complete sponsor isolation per REQ-p00001.

## Doppler Project Structure

### Core Project: hht-diary-core

Contains shared application secrets and the sponsor manifest that controls which sponsors are enabled.

**Configs**: `dev`, `staging`, `production`

**Key Secrets**:
- `SPONSOR_MANIFEST` - YAML manifest of enabled sponsors (see schema below)
- `SPONSOR_REPO_TOKEN` - GitHub PAT for cloning sponsor repos (future multi-repo)
- `APP_STORE_CREDENTIALS` - Apple/Google store credentials
- `CORE_AWS_ACCESS_KEY_ID`, `CORE_AWS_SECRET_ACCESS_KEY` - Core infrastructure AWS credentials

### Sponsor Projects: hht-diary-{sponsor}

Each sponsor has an isolated Doppler project containing sponsor-specific secrets.

**Example**: `hht-diary-callisto`

**Configs**: `staging`, `production`

**Key Secrets**:
- `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_ID` - Sponsor's Supabase database credentials
- `SPONSOR_AWS_ACCESS_KEY_ID`, `SPONSOR_AWS_SECRET_ACCESS_KEY` - Sponsor-specific AWS infrastructure
- `MOBILE_MODULE_SECRETS` - Sponsor-specific API keys and configuration

## Sponsor Manifest Schema

The `SPONSOR_MANIFEST` secret in `hht-diary-core` controls which sponsors are active. It follows the schema defined in `.github/config/sponsor-manifest-schema.yml`.

**Mono-Repo Example** (current):
```yaml
sponsors:
  - name: callisto
    code: CAL
    enabled: true
    repo: local      # Points to sponsor/callisto/
    tag: main
    mobile_module: true
    portal: true
    region: eu-west-1
```

**Multi-Repo Example** (future):
```yaml
sponsors:
  - name: callisto
    code: CAL
    enabled: true
    repo: cure-hht/sponsor-callisto
    tag: v1.2.3      # Locked version
    mobile_module: true
    portal: true
    region: eu-west-1
```

## Common Commands Reference

### For Developers

```bash
# Setup local environment
doppler login
doppler setup

# Run with secrets
doppler run -- flutter run
doppler run -- npm start

# View secrets
doppler secrets list
doppler secrets get SUPABASE_PROJECT_ID --plain
```

### For DevOps/Admins

```bash
# Create project
doppler projects create hht-diary-<name>

# Create configs
doppler configs create <config> --project <project>

# Set secrets
doppler secrets set KEY="value" --project <project> --config <config>

# Generate service token
doppler configs tokens create github-actions --project <project> --config <config>

# List projects and configs
doppler projects list
doppler configs list --project <project>
```

## Detailed Setup Guides

For step-by-step instructions, see the audience-specific guides:

- **[doppler-setup-project.md](./doppler-setup-project.md)** - Initial project infrastructure setup
- **[doppler-setup-new-sponsor.md](./doppler-setup-new-sponsor.md)** - Adding new sponsors
- **[doppler-setup-new-dev.md](./doppler-setup-new-dev.md)** - Developer local environment setup

## References

### Internal Documentation
- **Setup Guides**:
  - [doppler-setup-project.md](./doppler-setup-project.md) - Project infrastructure setup
  - [doppler-setup-new-sponsor.md](./doppler-setup-new-sponsor.md) - Sponsor onboarding
  - [doppler-setup-new-dev.md](./doppler-setup-new-dev.md) - Developer setup
- **Architecture**: `spec/prd-architecture-multi-sponsor.md` - Multi-sponsor system design
- **Security**: `spec/ops-security.md` - Security policies and practices
- **Schema**: `.github/config/sponsor-manifest-schema.yml` - Sponsor manifest validation

### External Resources
- Doppler CLI Documentation: https://docs.doppler.com/docs/cli
- Doppler Dashboard: https://dashboard.doppler.com/
- GitHub Actions Integration: https://docs.doppler.com/docs/github-actions

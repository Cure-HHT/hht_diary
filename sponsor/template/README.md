# Sponsor Template

This template provides the structure for creating a new sponsor module.

## Directory Structure

- `mobile-module/`: Required mobile app integration code
- `portal/`: Optional portal application
- `infrastructure/`: Sponsor-specific infrastructure definitions
- `.github/workflows/`: CI/CD workflows

## Creating a New Sponsor

1. Copy this template to `sponsor/<sponsor-name>/`
2. Update `sponsor-config.yml` with sponsor details
3. Implement mobile module in `mobile-module/lib/`
4. (Optional) Create portal app in `portal/`
5. Configure infrastructure in `infrastructure/`

## REQ Namespace

Each sponsor has their own REQ namespace:
- Core: `REQ-{type}{number}` (e.g., `REQ-d00001`)
- Sponsor: `REQ-{code}-{type}{number}` (e.g., `REQ-CAL-d00001`)

Where:
- `{code}` is the 3-letter sponsor code (e.g., CAL for Callisto)
- `{type}` is `d` (dev), `p` (PRD), or `o` (ops)
- `{number}` is a 5-digit number

## Future: Separate Repository

When ready to move to separate repositories, this directory will become a
standalone repository at `cure-hht/sponsor-<name>`.

**Important**: When migrating a sponsor to a separate repository:
1. Remove the sponsor from the `.gitignore` whitelist (remove `!sponsor/{name}/` line)
2. This ensures the sponsor directory won't accidentally be committed to core if cloned locally

## IMPLEMENTS REQUIREMENTS

- REQ-d00068: Sponsor template structure

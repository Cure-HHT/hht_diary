# Shared Validators

This directory contains JSON schema validators and other validation utilities used across plugins.

## Purpose

- Validate plugin manifests (plugin.json, marketplace.json)
- Validate configuration files
- Provide reusable validation patterns for plugin-specific data

## Planned Validators

- `plugin-manifest-schema.json`: JSON Schema for plugin.json files
- `marketplace-manifest-schema.json`: JSON Schema for marketplace.json files
- `validate-manifest.py`: Python script to validate JSON against schemas
- `agent-frontmatter-schema.json`: JSON Schema for agent YAML frontmatter

## Usage Pattern

```bash
# From a plugin or CI/CD pipeline
python3 "${MARKETPLACE_ROOT}/shared/validators/validate-manifest.py" \
  --schema=plugin-manifest \
  --file=./plugin.json
```

## Integration with CI/CD

These validators will be used in:
- Pre-commit hooks (validate before commit)
- GitHub Actions (validate on PR)
- Plugin installation (validate before loading)

## Current Status

**EMPTY** - This directory is part of the marketplace scaffold. Validators will be added as we define standard schemas and validation requirements.

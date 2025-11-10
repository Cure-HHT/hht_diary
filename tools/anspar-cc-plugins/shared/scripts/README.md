# Shared Scripts

This directory contains common bash and Python utilities used across multiple plugins in the anspar-cc-plugins marketplace.

## Purpose

- Reduce code duplication across plugins
- Provide standardized implementations of common operations
- Enable consistent behavior across the marketplace

## Usage Pattern

Plugins reference these scripts using relative paths:

```bash
# From a plugin script
MARKETPLACE_ROOT="${CLAUDE_PLUGIN_ROOT}/../.."
source "${MARKETPLACE_ROOT}/shared/scripts/common-functions.sh"
```

## Planned Utilities

- `common-functions.sh`: Bash utility functions (logging, error handling, path manipulation)
- `json-helpers.py`: JSON parsing and manipulation utilities
- `git-helpers.sh`: Git operation wrappers with error handling
- `env-validation.sh`: Environment variable validation patterns

## Design Principles

1. **No dependencies on specific plugins**: Scripts must be general-purpose
2. **Clear error messages**: All failures must provide actionable error messages
3. **Idempotent operations**: Scripts should be safe to run multiple times
4. **Environment variable usage**: No hardcoded paths or configuration

## Current Status

**EMPTY** - This directory is part of the marketplace scaffold. Scripts will be added as common patterns emerge from plugin development.

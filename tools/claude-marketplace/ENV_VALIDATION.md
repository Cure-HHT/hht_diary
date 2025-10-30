# Environment Validation System

**Version**: 1.0.0
**Last Updated**: 2025-10-30
**Status**: Active

## Overview

All Claude Code Marketplace plugins implement a standardized environment validation system that checks for required environment variables at startup. This system provides:

- ✅ Clear reporting of which environment variables are being used (without exposing values)
- ✅ Auto-discovery of configuration when possible (e.g., LINEAR_TEAM_ID)
- ✅ Consistent error messages with actionable instructions
- ✅ Future-ready infrastructure for Doppler/secret management integration

## Current Implementation

### Plugins with Environment Requirements

#### linear-integration

**Required**: `LINEAR_API_TOKEN`
**Optional**: `LINEAR_TEAM_ID` (auto-discovers if missing)

**Module**: `scripts/lib/env-validation.js`

**Features**:
- Validates LINEAR_API_TOKEN exists
- Auto-discovers LINEAR_TEAM_ID from Linear API if not set
- Reports which variables are active (not their values)
- Provides instructions for setting missing variables

**Example Output**:
```
🔧 Checking environment variables...

✓ Using LINEAR_API_TOKEN from environment
⚡ LINEAR_TEAM_ID not set, auto-discovering...
  Found team: Cure HHT Diary (CUR)
✓ Successfully discovered LINEAR_TEAM_ID

  To avoid auto-discovery in the future, add to ~/.bashrc:
  export LINEAR_TEAM_ID="ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Plugins with Placeholder Validation

These plugins don't currently require environment variables but have validation infrastructure ready for future use:

- **spec-compliance**: `scripts/lib/env-validation.sh`
- **requirement-validation**: (future)
- **traceability-matrix**: (future)

**Example Output** (silent mode by default):
```
🔧 Checking environment variables...

✓ No environment variables required for this plugin

  FUTURE: Secrets will be fetched from Doppler or similar
          secret management system automatically.
```

## Future: Doppler Integration

**Target Release**: TBD

All plugins will be enhanced to fetch secrets from Doppler (https://www.doppler.com/) or similar secret management systems instead of relying on environment variables.

### Planned Architecture

```typescript
// Future implementation example
async function validateEnvironment() {
    // 1. Check if Doppler CLI is available
    if (await isDopplerAvailable()) {
        // 2. Fetch secrets from Doppler
        const secrets = await fetchFromDoppler({
            project: 'diary',
            config: process.env.DOPPLER_CONFIG || 'dev'
        });

        return {
            token: secrets.LINEAR_API_TOKEN,
            teamId: secrets.LINEAR_TEAM_ID
        };
    }

    // 3. Fall back to environment variables
    return getFromEnvironment();
}
```

### Benefits of Doppler Integration

1. **Centralized Secret Management**: All secrets in one place
2. **Automatic Rotation**: Secrets can be rotated without code changes
3. **Access Control**: Fine-grained permissions for secrets
4. **Audit Trail**: Track who accessed which secrets when
5. **Environment Parity**: Consistent secrets across dev/staging/prod
6. **No .env Files**: No risk of committing secrets to git

## Implementation Guide

### For New Plugins

#### Node.js Plugins

1. Copy `linear-integration/scripts/lib/env-validation.js` as template
2. Modify `validateEnvironment()` to check your required variables
3. Add auto-discovery logic if applicable
4. Import and call in your main script:

```javascript
const { validateEnvironment } = require('./lib/env-validation');

async function main() {
    const env = await validateEnvironment({
        requireToken: true,
        requireOtherVar: false,
        autoDiscover: true
    });

    // Use env.token, env.otherVar, etc.
}
```

#### Bash Plugins

1. Copy `spec-compliance/scripts/lib/env-validation.sh` as template
2. Modify `validate_environment()` to check your required variables
3. Source and call in your main script:

```bash
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/env-validation.sh"
validate_environment

# Your script logic here
```

### Best Practices

1. **Never Log Secret Values**: Only report that variables are set
2. **Provide Actionable Instructions**: Tell users how to fix missing variables
3. **Support Command-Line Override**: Allow --token, --key flags
4. **Auto-Discovery When Possible**: Reduce user burden
5. **Silent Mode**: Add --silent flag for CI/CD
6. **Fail Fast**: Validate environment before expensive operations
7. **Document Future Plans**: Add Doppler comments to all validation code

## Security Considerations

### Current (Environment Variables)

✅ **Safe**:
- Store in shell config (`~/.bashrc`, `~/.zshrc`)
- Pass inline temporarily: `TOKEN=xyz node script.js`
- Never log values, only presence

❌ **Unsafe**:
- Hardcoding in scripts
- Committing `.env` files
- Logging to console/files
- Storing in git history

### Future (Doppler)

✅ **Advantages**:
- Encrypted at rest
- Access logs
- Automatic rotation
- Team-wide consistency
- No local storage

## Testing

### Manual Testing

```bash
# Test with variables set
export LINEAR_API_TOKEN="test"
export LINEAR_TEAM_ID="test"
node script.js

# Test without variables (should error or auto-discover)
unset LINEAR_API_TOKEN
unset LINEAR_TEAM_ID
node script.js

# Test with command-line override
node script.js --token=test --team-id=test
```

### Automated Testing

```javascript
describe('Environment Validation', () => {
    it('should report when variables are set', async () => {
        process.env.LINEAR_API_TOKEN = 'test';
        const env = await validateEnvironment({ silent: true });
        expect(env.token).toBe('test');
    });

    it('should auto-discover team ID', async () => {
        delete process.env.LINEAR_TEAM_ID;
        const env = await validateEnvironment({ autoDiscover: true });
        expect(env.teamId).toBeTruthy();
        expect(env.discovered).toBe(true);
    });
});
```

## Troubleshooting

### "Environment variable not set" Error

**Solution**: Set the required variable:
```bash
export LINEAR_API_TOKEN="lin_api_..."
```

Or add to `~/.bashrc`:
```bash
echo 'export LINEAR_API_TOKEN="lin_api_..."' >> ~/.bashrc
source ~/.bashrc
```

### Auto-Discovery Fails

**Causes**:
- Invalid API token
- Network connectivity issues
- Multiple teams (requires manual selection)

**Solution**: Set `LINEAR_TEAM_ID` manually:
```bash
# Run setup-env.sh to discover
source tools/claude-marketplace/linear-integration/scripts/setup-env.sh

# Or set manually
export LINEAR_TEAM_ID="team-uuid"
```

### "Silent" Mode Not Working

**Check**: Ensure you pass `silent: true` in Node.js or `"silent"` as first arg in Bash:

```javascript
// Node.js
await validateEnvironment({ silent: true });

// Bash
validate_environment "silent"
```

## Migration Path to Doppler

### Phase 1: Current (Complete)
- ✅ Environment validation infrastructure
- ✅ Consistent error handling
- ✅ Documentation and examples

### Phase 2: Doppler Integration (Future)
- Install Doppler CLI
- Configure Doppler projects
- Update validation modules
- Test in development
- Roll out to team

### Phase 3: Deprecate Environment Variables (Future)
- Remove environment variable support
- Update documentation
- Enforce Doppler usage

## Related Documentation

- **Plugin Development**: `tools/claude-marketplace/README.md`
- **Linear Integration**: `tools/claude-marketplace/linear-integration/README.md`
- **Secret Management**: (future Doppler docs)
- **Security Guidelines**: `docs/security/secret-management.md` (future)

## Changelog

### v1.0.0 (2025-10-30)
- Initial environment validation system
- Node.js validation module for linear-integration
- Bash validation template for other plugins
- Auto-discovery for LINEAR_TEAM_ID
- Documentation and examples
- Doppler integration comments added

## License

Part of the diary project. See project LICENSE for details.

## Credits

**Developed by**: Anspar Foundation
**Integrated with**: Claude Code Plugin System

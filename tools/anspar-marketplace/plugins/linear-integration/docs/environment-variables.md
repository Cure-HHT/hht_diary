# Environment Variables

**Plugin**: linear-integration
**Version**: 1.0.0
**Last Updated**: 2025-10-30

## Overview

The Anspar Linear Integration plugin implements environment variable validation with auto-discovery capabilities. This document describes the required and optional environment variables, how to set them up, and the future integration with secret management systems.

## Required Variables

### LINEAR_API_TOKEN

**Required**: Yes
**Format**: `lin_api_*`
**Purpose**: Authenticates with Linear API

**How to get**:
1. Go to [Linear Settings > API](https://linear.app/settings/api)
2. Create a new Personal API Key
3. Copy the token (starts with `lin_api_`)

**Setup**:
```bash
# Temporary (current session)
export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"

# Persistent (add to ~/.bashrc or ~/.zshrc)
echo 'export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"' >> ~/.bashrc
source ~/.bashrc
```

**Command-line override**:
```bash
node scripts/fetch-tickets.js --token=YOUR_LINEAR_TOKEN
```

## Optional Variables

### LINEAR_TEAM_ID

**Required**: No (auto-discovered if missing)
**Format**: UUID (e.g., `ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe`)
**Purpose**: Filters tickets by team

**Auto-discovery**:
The plugin can automatically discover your team ID if you have a single team:

```bash
# Auto-discover and export LINEAR_TEAM_ID
source scripts/setup-env.sh
```

**Manual setup**:
```bash
# Find your team ID using setup-env.sh or from Linear URL
export LINEAR_TEAM_ID="ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe"
```

**When is it required?**:
- Creating tickets (`create-requirement-tickets.js`)
- Most scripts auto-discover if missing

## Environment Validation

All scripts validate environment variables at startup using `scripts/lib/env-validation.js`.

### Validation Output

**When all variables are set**:
```
🔧 Checking environment variables...

✓ Using LINEAR_API_TOKEN from environment
✓ Using LINEAR_TEAM_ID from environment

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**When LINEAR_TEAM_ID needs auto-discovery**:
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

**When LINEAR_API_TOKEN is missing**:
```
🔧 Checking environment variables...

✗ LINEAR_API_TOKEN is required but not set

  To fix this:
  1. Get your Linear API token from: https://linear.app/settings/api
  2. Set it as an environment variable:
     export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"
  3. Or pass it via command line:
     node script.js --token=YOUR_LINEAR_TOKEN

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Security Best Practices

### Safe Token Storage

✅ **Safe**:
- Environment variables: `export LINEAR_API_TOKEN=...`
- Shell config files: `~/.bashrc`, `~/.zshrc` (with proper permissions)
- Pass inline via command-line flags

❌ **Unsafe**:
- Hardcoded in scripts
- `.env` files committed to git
- Shared in plain text (Slack, email, etc.)
- Stored in unencrypted notes

### Token Permissions

Linear Personal API tokens have **full account access**. This means:
- Can read all tickets, projects, and data
- Can create, update, and delete tickets
- Can manage team settings (depending on your role)

**Best practices**:
1. Store securely (see above)
2. Rotate regularly (every 90 days recommended)
3. Revoke immediately if compromised
4. Don't share tokens between users

### Principle of Least Privilege

Currently, Linear only offers Personal API tokens with full access. In the future, when Linear supports more granular permissions:
- Use read-only tokens for analysis scripts
- Use write tokens only for automation that needs to create/update

## Auto-Discovery Details

### How AUTO_DISCOVERY Works

When `LINEAR_TEAM_ID` is not set, the validation module:

1. **Queries Linear API** for all teams you have access to
2. **Single team**: Automatically exports `LINEAR_TEAM_ID` for the session
3. **Multiple teams**: Lists all teams and prompts you to choose

**Query used**:
```graphql
query {
  viewer {
    organization {
      teams {
        nodes {
          id
          key
          name
        }
      }
    }
  }
}
```

### When to Use Auto-Discovery

**Use auto-discovery when**:
- You have a single team
- You're testing/experimenting
- You don't want to configure permanently

**Set manually when**:
- You have multiple teams (avoids API call every time)
- You're running scripts frequently (faster startup)
- You're in CI/CD (no interactive discovery)

### Disabling Auto-Discovery

To skip auto-discovery in scripts, set `autoDiscover: false`:

```javascript
const env = await validateEnvironment({
    requireToken: true,
    requireTeamId: true,  // Will fail if not set
    autoDiscover: false,   // Don't try to discover
    silent: false
});
```

## Future: Doppler Integration

**Target Release**: TBD
**Status**: Prepared (comments in code)

This plugin is prepared for future integration with Doppler (https://www.doppler.com/) or similar secret management systems.

### Planned Architecture

```javascript
// Future implementation
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

### Benefits of Doppler

1. **Centralized Management**: All secrets in one place
2. **Automatic Rotation**: Rotate secrets without code changes
3. **Access Control**: Fine-grained permissions
4. **Audit Trail**: Track secret access
5. **Environment Parity**: Consistent across dev/staging/prod
6. **No .env Files**: No risk of git commits

### Migration Path

When Doppler is integrated:

1. **Backward compatible**: Environment variables still work
2. **Automatic fallback**: If Doppler unavailable, use env vars
3. **Gradual adoption**: Migrate secrets one at a time
4. **Zero code changes**: Scripts work exactly the same

**You won't need to change your scripts - just configure Doppler.**

## Troubleshooting

### "LINEAR_API_TOKEN is required but not set"

**Solutions**:
```bash
# 1. Check if it's actually set
echo $LINEAR_API_TOKEN

# 2. If empty, set it
export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"

# 3. Verify it's set
echo $LINEAR_API_TOKEN  # Should show lin_api_...

# 4. Try running script again
node scripts/fetch-tickets.js
```

### "Linear API error: Unauthorized"

**Causes**:
- Token is incorrect or expired
- Token doesn't have access to the workspace
- Token was revoked

**Solutions**:
1. Go to https://linear.app/settings/api
2. Verify your token is listed and active
3. Create a new token if needed
4. Update your environment variable

### Auto-discovery fails with multiple teams

**Symptom**:
```
⚠️  Multiple teams found. Please set LINEAR_TEAM_ID manually:
  - Team A (TEAM-A) - ce8e0f87-...
  - Team B (TEAM-B) - 12345678-...
```

**Solution**:
```bash
# Choose the team you want and set it manually
export LINEAR_TEAM_ID="ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe"

# Or pass via command line
node script.js --team-id=ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe
```

### Environment variables not persisting

**Symptom**: Variable works in current terminal but disappears when opening new terminal

**Cause**: Variable only set for current session

**Solution**:
```bash
# Add to shell config file
echo 'export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"' >> ~/.bashrc
echo 'export LINEAR_TEAM_ID="your-team-id"' >> ~/.bashrc

# Reload config
source ~/.bashrc

# Verify it persists
echo $LINEAR_API_TOKEN  # Should show token in new terminals
```

## API Reference

### env-validation.js

**Location**: `scripts/lib/env-validation.js`

**Main function**:
```javascript
async function validateEnvironment(options = {})
```

**Options**:
```javascript
{
  requireToken: boolean,     // Fail if LINEAR_API_TOKEN missing (default: true)
  requireTeamId: boolean,    // Fail if LINEAR_TEAM_ID missing (default: false)
  autoDiscover: boolean,     // Try to discover LINEAR_TEAM_ID (default: true)
  silent: boolean           // Suppress output messages (default: false)
}
```

**Returns**:
```javascript
{
  token: string,            // LINEAR_API_TOKEN value
  teamId: string,           // LINEAR_TEAM_ID value (or discovered)
  discovered: boolean       // True if teamId was auto-discovered
}
```

**Example usage**:
```javascript
const { validateEnvironment } = require('./lib/env-validation');

async function main() {
    const env = await validateEnvironment({
        requireToken: true,
        requireTeamId: false,
        autoDiscover: true,
        silent: false
    });

    console.log('Token set:', !!env.token);
    console.log('Team ID:', env.teamId);
    console.log('Was discovered:', env.discovered);
}
```

## Related Documentation

- **Plugin README**: [../README.md](../README.md)
- **Changelog**: [../CHANGELOG.md](../CHANGELOG.md)
- **Linear API Docs**: https://developers.linear.app/docs
- **Claude Code Plugins**: https://docs.claude.com/en/docs/claude-code/plugins-reference

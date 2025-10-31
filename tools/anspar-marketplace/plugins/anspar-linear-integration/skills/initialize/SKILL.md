# Linear Plugin Initialization

Automatically runs on startup to verify configuration and establish Linear connectivity.

## Auto-Run Behavior

This skill runs automatically when the Linear plugin loads to:
1. Check for Linear API token configuration
2. Verify token validity
3. Auto-discover team ID if not configured
4. Report any configuration issues
5. Cache configuration for other skills

## Manual Usage

Force re-initialization:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/test-config.js
```

## Initialization Checks

### 1. API Token Validation
- ✅ Searches multiple sources for LINEAR_API_TOKEN
- ❌ Reports if no token found with setup instructions
- ⚠️ Warns if token format is invalid

### 2. Team Discovery
- ✅ Uses configured LINEAR_TEAM_ID if available
- 🔍 Auto-discovers team if single team exists
- ⚠️ Lists multiple teams if manual selection needed

### 3. Connectivity Test
- ✅ Verifies API endpoint is reachable
- ❌ Reports network or authentication errors
- 📊 Shows API response time

## Configuration Sources

Searches in priority order:
1. Command line arguments
2. Environment variables
3. `.env.local` in plugin directory
4. `~/.config/linear/config` (JSON)
5. `~/.config/linear-api-token` (legacy)

## Error Messages

### Missing Token
```
❌ Linear API token not found!

To use Linear integration, provide your token:
1. Set environment variable: export LINEAR_API_TOKEN="lin_api_..."
2. Or create: ${PLUGIN_ROOT}/.env.local with LINEAR_API_TOKEN=...
3. Or save to: ~/.config/linear/config

Get your token from: https://linear.app/settings/api
```

### Multiple Teams
```
⚠️ Multiple teams found. Please specify:
  1. Team Alpha (ALPHA) - ID: xxx
  2. Team Beta (BETA) - ID: yyy

Set: export LINEAR_TEAM_ID="xxx"
```

## Success Output
```
✅ Linear Plugin Initialized
   API Token: Valid
   Team: Engineering (ENG)
   Endpoint: https://api.linear.app/graphql

Ready to use Linear skills!
```

## Notes
- Non-blocking: Other skills work even if initialization has warnings
- Caches successful configuration for session
- Re-runs if configuration files change
- Silent when everything is configured correctly
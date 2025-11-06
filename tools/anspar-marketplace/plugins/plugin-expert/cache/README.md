# Plugin-Expert Documentation Cache

This directory caches Claude Code documentation for offline reference and improved plugin development guidance.

## Purpose

The PluginExpert agent references official Claude Code documentation when providing guidance. To ensure:
- **Fresh content**: Documentation is refreshed daily
- **Offline access**: Docs available even without internet
- **Performance**: No repeated fetches during session

Documentation is cached locally and refreshed automatically.

## Cache Strategy

**Refresh Interval**: 24 hours
**Trigger**: SessionStart hook checks cache age
**Fallback**: Uses stale cache if fetch fails
**Non-blocking**: Session continues even if cache update fails

## Cached Documents

1. **agent-sdk-overview.md**: Agent SDK overview and patterns
   - Source: https://docs.claude.com/en/api/agent-sdk/overview

2. **hooks.md**: Hook types, schemas, and examples
   - Source: https://code.claude.com/docs/en/hooks

3. **plugins-reference.md**: Plugin structure and best practices
   - Source: https://code.claude.com/docs/en/plugins-reference

4. **cli-reference.md**: Claude Code CLI commands (optional)
   - Source: https://code.claude.com/docs/en/cli-reference

## Metadata

`.cache-metadata.json` tracks:
- Last fetch timestamp per document
- Fetch success/failure status
- Document version/etag if available

## Cache Management

**Manual refresh**:
```bash
cd tools/anspar-marketplace/plugins/plugin-expert
./scripts/cache-docs.sh --force
```

**Check cache status**:
```bash
./scripts/cache-docs.sh --status
```

**Clear cache**:
```bash
rm -rf cache/docs/*
```

## Integration

The SessionStart hook automatically:
1. Checks cache age
2. Refreshes if >24 hours old
3. Provides fresh docs to PluginExpert agent
4. Continues gracefully if cache unavailable

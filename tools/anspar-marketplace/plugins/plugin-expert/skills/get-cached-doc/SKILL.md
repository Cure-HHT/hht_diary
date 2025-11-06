# Get Cached Documentation

Direct access to cached Claude Code documentation files.

## Purpose

Provides fast, direct access to cached documentation when you know exactly which document you need. For intelligent documentation lookups, use the DocumentationAgent sub-agent instead.

## Usage

```bash
# Get specific cached document
cat ${CLAUDE_PLUGIN_ROOT}/cache/docs/<document-name>.md
```

## Available Documents

- **agent-sdk-overview.md** - Agent SDK patterns, architecture, examples
- **hooks.md** - Hook types, schemas, lifecycle, examples
- **plugins-reference.md** - Plugin structure, best practices, configuration
- **cli-reference.md** - Claude Code CLI commands and usage

## Parameters

| Parameter | Type | Description | Required |
|-----------|------|-------------|----------|
| document | string | Document name (without .md extension) | Yes |

Valid values: `agent-sdk-overview`, `hooks`, `plugins-reference`, `cli-reference`

## Examples

### Get hooks documentation

```bash
cat ${CLAUDE_PLUGIN_ROOT}/cache/docs/hooks.md
```

### Get plugin reference

```bash
cat ${CLAUDE_PLUGIN_ROOT}/cache/docs/plugins-reference.md
```

### Check if document exists

```bash
if [ -f "${CLAUDE_PLUGIN_ROOT}/cache/docs/hooks.md" ]; then
    cat "${CLAUDE_PLUGIN_ROOT}/cache/docs/hooks.md"
else
    echo "Document not cached. Run cache-docs.sh to fetch."
fi
```

## Cache Freshness

Check cache status before reading:

```bash
# View cache status
${CLAUDE_PLUGIN_ROOT}/scripts/cache-docs.sh --status
```

If cache is stale (>24 hours), consider refreshing:

```bash
# Refresh stale cache only
${CLAUDE_PLUGIN_ROOT}/scripts/cache-docs.sh

# Force refresh all
${CLAUDE_PLUGIN_ROOT}/scripts/cache-docs.sh --force
```

## When to Use This Skill vs DocumentationAgent

**Use this skill when:**
- ✅ You know the exact document name
- ✅ You want the full document content
- ✅ You're building tooling that needs specific docs
- ✅ Speed is critical (no interpretation needed)

**Use DocumentationAgent when:**
- ✅ You have a question, not a document name
- ✅ You need relevant excerpts, not full docs
- ✅ You want cache-first with web fallback
- ✅ You need intelligent matching to doc sources

## Error Handling

### Document not found

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"
DOC_FILE="${PLUGIN_ROOT}/cache/docs/hooks.md"

if [ ! -f "$DOC_FILE" ]; then
    echo "❌ Document not cached"
    echo "Run: ${PLUGIN_ROOT}/scripts/cache-docs.sh"
    exit 1
fi
```

### Cache directory doesn't exist

```bash
# Install plugin properly
${CLAUDE_PLUGIN_ROOT}/scripts/install.sh

# Fetch documentation
${CLAUDE_PLUGIN_ROOT}/scripts/cache-docs.sh
```

## Integration

This skill is part of the plugin-expert documentation system:

```
plugin-expert/
├── agents/
│   ├── PluginExpert.md          # Main expert agent
│   └── DocumentationAgent.md     # Intelligent doc lookups
├── skills/
│   └── get-cached-doc/          # Direct cache access (this skill)
├── cache/
│   └── docs/                     # Cached documentation
└── scripts/
    ├── cache-docs.sh             # Fetch/refresh cache
    └── check-doc-cache.sh        # Check freshness
```

## Performance

- **Speed**: Instant (just reads local file)
- **Size**: Documents range from 321KB to 1.5MB
- **Freshness**: Check metadata for last update timestamp

## Notes

- Documents are plain markdown
- Cache is gitignored (not committed)
- Cache automatically refreshes if stale
- Safe to read concurrently (no locks needed)

# Commit Message Helper

Automated commit message generation with ticket ID and requirement references from Linear.

## Architecture

The commit message helper uses a modular, separation-of-concerns architecture:

```
┌─────────────────────────────────────────────────────────┐
│          generate-commit-msg.sh (Orchestrator)          │
│  Generates commit message with ticket ID and REQ refs   │
└────────────────┬────────────────────────────────────────┘
                 │
        ┌────────┴─────────┐
        │                  │
        ▼                  ▼
┌──────────────┐    ┌──────────────────┐
│   Linear     │    │   parse-req-     │
│ Integration  │    │    refs.sh       │
│   Plugin     │    │                  │
│              │    │ (Reusable REQ    │
│  Fetches     │    │  parser)         │
│  ticket data │    │                  │
└──────────────┘    └──────────────────┘
        │                  │
        └────────┬─────────┘
                 ▼
      ┌──────────────────┐
      │ WORKFLOW_STATE   │
      │                  │
      │ Caches REQ refs  │
      │ for efficiency   │
      └──────────────────┘
```

### Components

1. **generate-commit-msg.sh** - Main orchestrator
   - Reads active ticket from WORKFLOW_STATE
   - Fetches cached REQ references
   - Generates formatted commit message template

2. **fetch-ticket-reqs.sh** - REQ fetcher and cacher
   - Uses Linear Integration plugin to fetch ticket data
   - Uses parse-req-refs.sh to extract REQ references
   - Caches results in WORKFLOW_STATE

3. **parse-req-refs.sh** - Reusable REQ parser
   - Extracts REQ-* references from any text
   - Supports multiple output formats (JSON, CSV, lines, human)
   - Can be used independently for other purposes

4. **Linear Integration Plugin** - Ticket data source
   - Fetches ticket data from Linear API
   - Provides ticket description and metadata

5. **WORKFLOW_STATE** - Cache layer
   - Stores active ticket information
   - Caches REQ references for efficiency
   - Avoids repeated API calls

## Usage

### Basic Usage

```bash
# Generate commit message for active ticket
./generate-commit-msg.sh
```

Output:
```
[CUR-240] Brief summary of changes

Detailed description of changes:
-

Implements: REQ-p00042, REQ-d00027

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### With Custom Summary

```bash
./generate-commit-msg.sh --summary "Add commit message helper"
```

### Fetch Requirements First

```bash
# Fetch and cache requirements from Linear
./generate-commit-msg.sh --fetch
```

### Open in Editor

```bash
# Generate and open in $EDITOR
./generate-commit-msg.sh --editor
```

### Combined Options

```bash
# Fetch requirements, add summary, and open in editor
./generate-commit-msg.sh --fetch --summary "My changes" --editor
```

## Git Alias Setup

Add a convenient git alias for easy access:

```bash
# Add to your git config
git config alias.cm '!bash tools/anspar-marketplace/plugins/workflow/scripts/generate-commit-msg.sh'

# Or add with options
git config alias.cmf '!bash tools/anspar-marketplace/plugins/workflow/scripts/generate-commit-msg.sh --fetch'
```

Then use:

```bash
# Generate commit message
git cm

# Fetch requirements and generate
git cmf

# With custom summary
git cm --summary "My commit message"

# Open in editor
git cm --editor
```

## Workflow Integration

### 1. Claim a Ticket

```bash
# Claim a ticket (creates WORKFLOW_STATE)
./claim-ticket.sh CUR-240
```

### 2. Fetch Requirements (Optional)

```bash
# Fetch and cache REQ references from Linear ticket
./fetch-ticket-reqs.sh

# Or let generate-commit-msg.sh do it automatically:
./generate-commit-msg.sh --fetch
```

### 3. Make Changes

```bash
# Make your code changes
git add .
```

### 4. Generate Commit Message

```bash
# Generate commit message
./generate-commit-msg.sh --summary "My changes"

# Copy the output and commit
git commit -m "$(./generate-commit-msg.sh --summary 'My changes')"
```

## Manual Usage of Components

### Parse REQ References from Text

```bash
# From stdin
echo "This implements REQ-p00042" | ./parse-req-refs.sh

# From file
./parse-req-refs.sh < ticket-description.txt

# From command line
./parse-req-refs.sh --text "Implements REQ-p00042 and REQ-d00027"

# Different formats
./parse-req-refs.sh --format=csv < file.txt
./parse-req-refs.sh --format=human < file.txt
```

### Fetch Ticket Requirements

```bash
# Fetch for active ticket
./fetch-ticket-reqs.sh

# Fetch for specific ticket
./fetch-ticket-reqs.sh CUR-240
```

## REQ Reference Format

The system recognizes requirement references in this format:

```
REQ-{type}{number}
```

Where:
- `type`: `p` (PRD), `o` (Ops), `d` (Dev)
- `number`: 5 digits (e.g., `00042`)

Examples:
- `REQ-p00042` - PRD requirement #42
- `REQ-o00015` - Ops requirement #15
- `REQ-d00027` - Dev requirement #27

## Benefits

1. **Consistency** - All commits follow the same format
2. **Traceability** - Automatic linking to requirements
3. **Efficiency** - Caching avoids repeated API calls
4. **Modularity** - Each component can be used independently
5. **Flexibility** - Multiple output formats and options
6. **Compliance** - Enforced requirement references

## Files

| File | Purpose |
|------|---------|
| `generate-commit-msg.sh` | Main commit message generator |
| `fetch-ticket-reqs.sh` | Fetches and caches REQ references |
| `parse-req-refs.sh` | Reusable REQ reference parser |
| `WORKFLOW_STATE` | Cache file (in `.git/` directory) |

## Examples

### Example 1: Quick Commit

```bash
# Generate and commit in one line
git commit -m "$(tools/anspar-marketplace/plugins/workflow/scripts/generate-commit-msg.sh --summary 'Fix bug in parser')"
```

### Example 2: Interactive Editing

```bash
# Generate template and edit before committing
tools/anspar-marketplace/plugins/workflow/scripts/generate-commit-msg.sh --editor
# Edit the message, save and close
git commit -F /tmp/commit-msg.XXXXXX
```

### Example 3: Fetch Fresh Requirements

```bash
# Fetch latest requirements from Linear
tools/anspar-marketplace/plugins/workflow/scripts/fetch-ticket-reqs.sh

# Then generate commit message
tools/anspar-marketplace/plugins/workflow/scripts/generate-commit-msg.sh
```

## Troubleshooting

### No active ticket error

```bash
❌ ERROR: No active ticket found
   Run: claim-ticket.sh <TICKET-ID>
```

**Solution**: Claim a ticket first:
```bash
./claim-ticket.sh CUR-240
```

### Requirements show as REQ-xxxxx

This means no requirements were found or cached. Options:

1. Fetch from Linear:
   ```bash
   ./fetch-ticket-reqs.sh
   ```

2. Manually add to WORKFLOW_STATE:
   ```bash
   # Edit .git/WORKFLOW_STATE and add requirements array
   ```

3. Add manually to commit message

### Linear fetch fails

```bash
⚠️  WARNING: Could not fetch ticket from Linear
```

**Causes**:
- No Linear API token configured
- linear-integration plugin not installed
- Network issues
- Ticket doesn't exist

**Solution**: Configure Linear integration (see linear-integration plugin README)

## See Also

- [Workflow Plugin README](README.md)
- [Linear Integration Plugin](../linear-integration/README.md)
- [Requirements System](../../../../spec/README.md)

# Requirement Change Tracking Workflow

This document describes the automated requirement change tracking system introduced in Phase 3 of the simple-requirements plugin.

## Overview

The tracking system automatically detects when requirements change and helps ensure implementations stay synchronized with requirement specifications. It provides:

- **Automatic change detection** via post-commit hooks
- **Persistent tracking** of outdated implementations
- **Session notifications** when starting work
- **Linear integration** for verification tickets (optional)
- **Simple verification workflow** to mark requirements as updated

## System Components

### 1. Scripts

#### `get-requirement.py`
Fetch and display any requirement by ID.

```bash
# Markdown output (default):
python3 scripts/get-requirement.py REQ-d00027
python3 scripts/get-requirement.py d00027

# JSON output (for automation):
python3 scripts/get-requirement.py d00027 --format json
```

**Output**:
- Full requirement text with all metadata
- Implementation context (level, implements, status)
- Source file location
- Current hash value

#### `detect-changes.py`
Compare current requirements against INDEX.md to find changes.

```bash
# Human-readable summary:
python3 scripts/detect-changes.py --format summary

# JSON for automation:
python3 scripts/detect-changes.py --format json
```

**Detects**:
- **Changed requirements**: Hash mismatch with INDEX.md
- **New requirements**: Hash marked as TBD in INDEX.md
- **Missing requirements**: Not yet added to INDEX.md

#### `update-tracking.py`
Add changed requirements to the tracking file.

```bash
# From detect-changes.py output:
python3 scripts/detect-changes.py --format json > /tmp/changes.json
python3 scripts/update-tracking.py --input /tmp/changes.json

# Dry run (preview without writing):
python3 scripts/update-tracking.py --input /tmp/changes.json --dry-run

# Single requirement:
python3 scripts/update-tracking.py \
  --req-id d00027 \
  --old-hash abc12345 \
  --new-hash def67890
```

**Features**:
- Thread-safe file locking
- Prevents duplicate entries
- Updates existing entries if hash changes again
- Maintains chronological order

#### `mark-verified.py`
Remove a requirement from tracking after verification.

```bash
# Mark single requirement as verified:
python3 scripts/mark-verified.py REQ-d00027
python3 scripts/mark-verified.py d00027

# Dry run:
python3 scripts/mark-verified.py d00027 --dry-run

# Clear all (use with caution!):
python3 scripts/mark-verified.py --all --dry-run  # Preview first
python3 scripts/mark-verified.py --all
```

### 2. Hooks

#### Post-Commit Hook
**Trigger**: After every git commit that modifies `spec/*.md` files

**Actions**:
1. Detects changed requirements
2. Updates `outdated-implementations.json`
3. Shows summary of changes
4. Optionally creates Linear verification tickets

**Output Example**:
```
🔍 Detecting requirement changes from commit...

📝 Found 2 changed requirement(s)

⚠️  IMPORTANT: Requirements have changed!

   Modified requirements: 2
   • REQ-d00042: Database Connection Pooling
   • REQ-p00008: User Authentication Flow

   Tracking file updated: untracked-notes/outdated-implementations.json

Next steps:
  1. Review changed requirements
  2. Update implementations to match new requirements
  3. Mark as verified: python3 scripts/mark-verified.py REQ-{id}
```

#### Session-Start Hook
**Trigger**: When Claude Code session starts

**Action**: Notifies about any outdated requirements

**Output Example**:
```
📋 REQUIREMENTS CHANGED

The following requirements have been modified and may need implementation updates:

• REQ-d00042: Database Connection Pooling
  File: dev-database.md | Hash: a1b2c3d4 → e5f6g7h8

• REQ-p00008: User Authentication Flow
  File: prd-auth.md | Hash: 11223344 → 55667788

Actions:
  • View requirement: python3 scripts/get-requirement.py REQ-{id}
  • Mark as verified: python3 scripts/mark-verified.py REQ-{id}
  • See all changes: python3 scripts/detect-changes.py --format summary
```

### 3. Tracking File

**Location**: `untracked-notes/outdated-implementations.json`

**Structure**:
```json
{
  "version": "1.0",
  "last_updated": "2025-11-06T12:34:56.789012+00:00",
  "outdated_requirements": [
    {
      "req_id": "d00042",
      "old_hash": "a1b2c3d4",
      "new_hash": "e5f6g7h8",
      "detected_at": "2025-11-06T12:00:00.000000+00:00",
      "file": "dev-database.md",
      "title": "Database Connection Pooling",
      "linear_ticket": "CUR-123",
      "verified_at": null
    }
  ]
}
```

**Fields**:
- `req_id`: Requirement ID (without REQ- prefix)
- `old_hash`: Hash value from INDEX.md
- `new_hash`: Current hash value
- `detected_at`: When change was first detected
- `file`: Source file in spec/
- `title`: Requirement title
- `linear_ticket`: Linear ticket identifier (if created)
- `verified_at`: Timestamp when verified (currently unused)

### 4. Requirements Agent

**Invocation**: Claude can use the Requirements sub-agent for requirement operations

**Capabilities**:
- Fetch and explain requirements
- Detect changes
- Manage tracking status
- Guide implementation updates

**Example Usage**:
```
User: "What does REQ-d00042 say?"
Claude: [Uses Requirements agent to fetch and explain the requirement]

User: "Have any requirements changed?"
Claude: [Uses Requirements agent to detect and report changes]
```

## Workflow Examples

### Example 1: Normal Development Flow

```bash
# 1. User modifies a requirement in spec/dev-database.md
vim spec/dev-database.md  # Change REQ-d00042

# 2. User commits the change
git add spec/dev-database.md
git commit -m "Update REQ-d00042: Improve connection pooling spec"

# 3. Post-commit hook runs automatically:
🔍 Detecting requirement changes from commit...
📝 Found 1 changed requirement(s)
   • REQ-d00042: Database Connection Pooling

# 4. Next session, user sees notification:
📋 REQUIREMENTS CHANGED
   • REQ-d00042: Database Connection Pooling

# 5. User reviews the requirement:
python3 scripts/get-requirement.py d00042

# 6. User finds and updates implementations:
git grep -n "REQ-d00042"  # Find all implementations
# Update code to match new requirement

# 7. User marks as verified:
python3 scripts/mark-verified.py d00042
✅ Marked as verified and removed from tracking
```

### Example 2: Bulk Change Detection

```bash
# Check for all changes without committing:
python3 scripts/detect-changes.py --format summary

# Output:
⚠️  3 Changed Requirement(s):
  • REQ-d00042: Database Connection Pooling
  • REQ-o00015: Deployment Health Checks
  • REQ-p00008: User Authentication Flow

# Review each one:
python3 scripts/get-requirement.py d00042
python3 scripts/get-requirement.py o00015
python3 scripts/get-requirement.py p00008

# Update implementations, then verify:
python3 scripts/mark-verified.py d00042
python3 scripts/mark-verified.py o00015
python3 scripts/mark-verified.py p00008
```

### Example 3: Linear Integration

Enable automatic ticket creation:

```bash
# Set environment variable:
export LINEAR_CREATE_TICKETS=true

# Now commits will auto-create verification tickets:
git commit -m "Update requirements"

# Output includes:
🎫 Creating Linear verification tickets...
   ✅ Created CUR-245 for REQ-d00042
   ✅ Created CUR-246 for REQ-o00015

# Tickets include:
# - Full requirement context
# - Verification checklist
# - Commands to run
# - Links to source files
```

## Integration Points

### With INDEX.md
- `detect-changes.py` compares against INDEX.md hashes
- Relies on INDEX.md being up-to-date
- Run `python3 tools/requirements/update-REQ-hashes.py` to sync hashes

### With Linear Integration Plugin
- Optional ticket creation via `create-verification-ticket.js`
- Enabled with `LINEAR_CREATE_TICKETS=true`
- Tickets auto-linked in tracking file

### With Workflow Plugin
- Session notifications integrate with workflow status
- Requirement changes shown alongside active tickets

## Best Practices

### 1. Review Before Committing
```bash
# Check what will be detected:
python3 scripts/detect-changes.py --format summary
```

### 2. Use Dry-Run for Safety
```bash
# Preview operations:
python3 scripts/update-tracking.py --input changes.json --dry-run
python3 scripts/mark-verified.py --all --dry-run
```

### 3. Keep INDEX.md Updated
```bash
# After verifying implementations, update hashes:
python3 tools/requirements/update-REQ-hashes.py
git add spec/INDEX.md
git commit -m "Update requirement hashes after verification"
```

### 4. Verify One at a Time
```bash
# Don't mark all as verified without checking each:
# WRONG:
python3 scripts/mark-verified.py --all

# RIGHT:
python3 scripts/get-requirement.py d00042
# Review implementation...
python3 scripts/mark-verified.py d00042
# Repeat for each requirement
```

### 5. Link Commits to Requirements
```bash
# Include REQ references in commit messages:
git commit -m "[CUR-245] Update connection pooling

Implements updated REQ-d00042 specification.
- Add max_connections parameter
- Improve timeout handling

Implements: REQ-d00042"
```

## Troubleshooting

### Changes Not Detected

**Problem**: Post-commit hook doesn't detect changes

**Solutions**:
1. Check if spec/*.md files were actually committed:
   ```bash
   git diff-tree --no-commit-id --name-only -r HEAD | grep '^spec/'
   ```

2. Manually run detection:
   ```bash
   python3 scripts/detect-changes.py --format summary
   ```

3. Verify INDEX.md exists and has hashes:
   ```bash
   cat spec/INDEX.md | head -20
   ```

### Tracking File Corruption

**Problem**: JSON parsing error in tracking file

**Solution**:
```bash
# Validate JSON:
jq . untracked-notes/outdated-implementations.json

# If corrupted, rebuild from changes:
python3 scripts/detect-changes.py --format json > /tmp/changes.json
rm untracked-notes/outdated-implementations.json
python3 scripts/update-tracking.py --input /tmp/changes.json
```

### Duplicate Tracking Entries

**Problem**: Same requirement appears multiple times

**Solution**:
The system prevents duplicates automatically. If duplicates exist:
```bash
# Clear and rebuild:
python3 scripts/mark-verified.py --all --dry-run  # Review first
python3 scripts/mark-verified.py --all  # Clear all
python3 scripts/detect-changes.py --format json | \
  python3 scripts/update-tracking.py --input /dev/stdin
```

### Linear Tickets Not Creating

**Problem**: LINEAR_CREATE_TICKETS=true but no tickets created

**Solutions**:
1. Check Linear API token:
   ```bash
   echo $LINEAR_API_TOKEN
   ```

2. Test Linear integration:
   ```bash
   node tools/anspar-cc-plugins/plugins/linear-api/scripts/test-config.js
   ```

3. Manual ticket creation:
   ```bash
   python3 scripts/detect-changes.py --format json | jq '.changed_requirements[0]' | \
     node tools/anspar-cc-plugins/plugins/linear-api/scripts/create-verification-ticket.js
   ```

## Advanced Usage

### Custom Priority for Tickets

```bash
# Create ticket with custom priority:
echo '{"req_id":"d00042",...}' | \
  node scripts/create-verification-ticket.js --priority urgent
```

### Filter Changes by Type

```bash
# Only Dev requirements:
python3 scripts/detect-changes.py --format json | \
  jq '.changed_requirements[] | select(.req_id | startswith("d"))'

# Only PRD requirements:
python3 scripts/detect-changes.py --format json | \
  jq '.changed_requirements[] | select(.req_id | startswith("p"))'
```

### Export for Reporting

```bash
# Generate change report:
python3 scripts/detect-changes.py --format json | \
  jq -r '.changed_requirements[] | "\(.req_id)\t\(.title)\t\(.file)"' > changes-report.tsv
```

## References

- **Plugin README**: `README.md`
- **Requirements Format**: `spec/README.md`
- **Validation System**: `tools/requirements/validate_requirements.py`
- **INDEX.md Management**: `tools/requirements/update-REQ-hashes.py`
- **Linear Integration**: `tools/anspar-cc-plugins/plugins/linear-api/`

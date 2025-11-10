# compliance-verification Plugin

FDA 21 CFR Part 11 compliance verification workflows for the diary clinical trial platform.

## Overview

This plugin automates the creation and management of compliance verification tickets when requirements change. It ensures that all implementations continue to satisfy FDA 21 CFR Part 11 requirements through systematic verification across all 11 platform subsystems.

## Purpose

In FDA-regulated clinical trial systems, when a requirement changes, all implementations referencing that requirement must be re-verified to ensure continued compliance. This plugin:

1. Creates Linear verification tickets automatically when requirements are modified
2. Analyzes requirement impact across 11 platform subsystems
3. Generates subsystem-specific verification checklists
4. Maintains traceability between requirements, implementations, and verification activities

## FDA Compliance Context

**FDA 21 CFR Part 11** establishes requirements for electronic records and electronic signatures in clinical trials. Key principles:

- **Validation**: Systems must be validated to ensure accuracy, reliability, and consistent performance (11.10(a))
- **Audit Trails**: Secure, computer-generated, time-stamped audit trails are required (11.10(e))
- **Change Control**: All changes must be documented and verified
- **ALCOA+ Principles**: Data must be Attributable, Legible, Contemporaneous, Original, Accurate, Complete, Consistent, Enduring, Available

This plugin supports these requirements by ensuring systematic verification of all implementation changes.

## Features

### Verification Ticket Creation

When a requirement is modified:

```bash
# Automatically creates Linear ticket with:
# - Requirement change details (old hash → new hash)
# - GitHub link to requirement
# - Step-by-step verification instructions
# - Tracking metadata for traceability

node scripts/create-verification.js '{"req_id":"d00027","old_hash":"abc123","new_hash":"def456","title":"Event Sourcing","file":"dev-database.md"}'
```

**Output**:
- Linear ticket with `verification` and `requirement-change` labels
- High priority by default (changed requirements need immediate attention)
- JSON output for integration with requirement tracking system

### Subsystem Impact Analysis

Analyzes tickets and adds checklists of affected subsystems:

```bash
# Add subsystem checklists to tickets
node scripts/add-subsystem-checklist.js --token=$LINEAR_API_TOKEN [--dry-run]
```

**Features**:
- Keyword-based subsystem detection
- Special handling for cross-cutting concerns (security/RBAC)
- Conservative inclusion (better false positive than miss critical verification)
- Dry-run mode for preview before updating tickets

## Platform Subsystems (11 Total)

The diary platform consists of 11 subsystems that may require verification when requirements change:

1. **Supabase (Database & Auth)**
   - PostgreSQL database schema, RLS policies
   - Event sourcing, audit trails
   - Authentication, authorization, role management

2. **Mobile App (Flutter)**
   - Patient-facing diary application
   - Offline-first architecture, local storage
   - Data synchronization with backend

3. **Web Portal**
   - Sponsor and investigator dashboards
   - Data analytics and reporting
   - Browser-based access

4. **Development Environment**
   - Docker dev containers (role-based)
   - IDE configuration (VS Code, Claude Code)
   - Local tooling and scripts

5. **CI/CD Pipeline (GitHub Actions)**
   - Automated testing, validation
   - Deployment workflows
   - PR validation checks

6. **Google Workspace**
   - Email (Gmail)
   - SSO, MFA, identity management
   - User provisioning and access control

7. **GitHub**
   - Version control, code review
   - Package registry (private npm packages)
   - Repository access control, branch protection

8. **Doppler (Secrets Management)**
   - API keys, credentials, tokens
   - Environment variable management
   - Secret rotation and access control

9. **Netlify (Web Hosting)**
   - Web portal hosting
   - CDN, edge functions
   - Deployment automation

10. **Linear (Project Management)**
    - Ticket tracking, workflows
    - Requirement-ticket mapping
    - Automation and integrations

11. **Compliance & Documentation**
    - FDA validation documentation
    - Traceability matrices
    - Architecture Decision Records (ADRs)
    - Audit trail documentation

### Subsystem Detection Logic

Each subsystem has associated keywords that trigger inclusion:

```javascript
// Example: Supabase subsystem
'Supabase (Database & Auth)': [
  'database', 'supabase', 'schema', 'rls', 'row level security', 'postgres',
  'auth', 'authentication', 'user', 'role', 'permission', 'access', 'data',
  'table', 'query', 'sql', 'event sourcing', 'audit'
]
```

**Cross-cutting Concerns**: Requirements containing RBAC/security keywords automatically include all 7 access-controlled subsystems:
- Supabase, Google Workspace, GitHub, Doppler, Development Environment, Netlify, Linear

## Verification Workflow

### Standard Workflow

```
1. Requirement Modified
   ↓
2. simple-requirements plugin detects change
   ↓
3. Create verification ticket (create-verification.js)
   ↓
4. Add subsystem checklist (add-subsystem-checklist.js)
   ↓
5. Assign to developer/QA
   ↓
6. Review each subsystem checklist item
   ↓
7. Update implementations as needed
   ↓
8. Mark ticket as verified
   ↓
9. Remove from outdated-implementations tracking
```

### Example: Requirement Change Detected

```bash
# 1. Requirement change detected (by simple-requirements plugin)
# Output: changed-requirement.json

# 2. Create verification ticket
node tools/anspar-cc-plugins/plugins/compliance-verification/scripts/create-verification.js \
  '{"req_id":"d00027","old_hash":"a1b2c3","new_hash":"d4e5f6","title":"Event sourcing with audit trail","file":"dev-database.md"}'

# Output:
# ✅ Verification ticket created successfully!
#    Ticket: CUR-123
#    URL: https://linear.app/diary/issue/CUR-123
#
# 📤 JSON output (for tracking system):
# {
#   "req_id": "d00027",
#   "ticket_id": "abc-def-ghi",
#   "ticket_identifier": "CUR-123",
#   "ticket_url": "https://linear.app/diary/issue/CUR-123",
#   "created_at": "2025-11-08T12:00:00Z"
# }

# 3. Fetch tickets needing subsystem checklists
bash tools/anspar-cc-plugins/plugins/linear-api/skills/search-tickets.skill \
  --query="label:ai:new" > /tmp/ai_new_tickets.json

# 4. Add subsystem checklists (dry run first)
node tools/anspar-cc-plugins/plugins/compliance-verification/scripts/add-subsystem-checklist.js \
  --token=$LINEAR_API_TOKEN --dry-run

# 5. Execute for real
node tools/anspar-cc-plugins/plugins/compliance-verification/scripts/add-subsystem-checklist.js \
  --token=$LINEAR_API_TOKEN

# Output:
# ✅ CUR-123: [Verification] REQ-d00027: Event sourcing with audit trail
#    Added 4 sub-systems: Supabase (Database & Auth), CI/CD Pipeline (GitHub Actions), Compliance & Documentation, Development Environment
```

## Installation

This plugin is part of the diary project's Claude Code marketplace plugins. No separate installation required.

### Dependencies

- **linear-api**: Provides Linear API access and utilities
- **simple-requirements**: Provides requirement tracking and change detection

### Environment Variables

Required:
- `LINEAR_API_TOKEN`: Linear API token (provided by linear-integration plugin)

## Usage

### Create Verification Ticket

**From JSON (recommended for automation)**:
```bash
node scripts/create-verification.js '{"req_id":"d00027","old_hash":"abc123","new_hash":"def456","title":"Requirement Title","file":"dev-database.md"}'
```

**From file**:
```bash
node scripts/create-verification.js --input /tmp/changed-req.json
```

**Interactive (manual)**:
```bash
node scripts/create-verification.js --req-id d00027 --old-hash abc123 --new-hash def456
```

**Options**:
- `--input=FILE`: JSON file with requirement change data
- `--req-id=ID`: Requirement ID (e.g., d00027)
- `--old-hash=HASH`: Previous requirement hash
- `--new-hash=HASH`: Current requirement hash
- `--priority=VALUE`: Priority (default: high)
- `--assignee=EMAIL`: Assignee email or ID

### Add Subsystem Checklists

**Basic usage**:
```bash
node scripts/add-subsystem-checklist.js --token=$LINEAR_API_TOKEN
```

**Dry run (preview changes)**:
```bash
node scripts/add-subsystem-checklist.js --token=$LINEAR_API_TOKEN --dry-run
```

**Prerequisites**:
- Tickets must be in `/tmp/ai_new_tickets.json`
- Fetch using: `bash ../linear-api/skills/search-tickets.skill --query="label:ai:new" > /tmp/ai_new_tickets.json`

## Plugin Structure

```
compliance-verification/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── agents/
│   └── compliance-agent.md      # Agent documentation and knowledge
├── scripts/
│   ├── create-verification.js   # Create verification tickets
│   └── add-subsystem-checklist.js  # Add subsystem checklists to tickets
├── skills/
│   ├── create-verification.skill       # Skill wrapper for create-verification
│   └── add-subsystem-checklist.skill   # Skill wrapper for add-subsystem-checklist
└── README.md                    # This file
```

## Skills Reference

### create-verification

Creates a Linear verification ticket for a changed requirement.

**Usage**:
```bash
# From JSON string
create-verification.skill '{"req_id":"d00027",...}'

# From file
create-verification.skill --input changed-req.json

# Interactive
create-verification.skill --req-id d00027 --old-hash abc123 --new-hash def456
```

**Output**: Linear ticket URL and JSON metadata for tracking

### add-subsystem-checklist

Adds subsystem checklists to Linear tickets.

**Usage**:
```bash
# Production
add-subsystem-checklist.skill --token=$LINEAR_API_TOKEN

# Dry run (preview only)
add-subsystem-checklist.skill --token=$LINEAR_API_TOKEN --dry-run
```

**Output**: Summary of tickets updated with subsystem counts

## Integration with Other Plugins

### workflow Plugin

Claim verification tickets before starting work:

```bash
# Claim verification ticket
tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh CUR-123

# Do verification work...

# Release ticket when complete
tools/anspar-cc-plugins/plugins/workflow/scripts/release-ticket.sh "Verification complete"
```

### linear-api Plugin

Leverages shared Linear API utilities:

- `ticket-creator.js`: Used by create-verification.js for ticket creation
- Skills for ticket operations and searches

### simple-requirements Plugin

Consumes requirement change events:

- Integration with `detect-changes.py` output
- Uses requirement hash tracking
- Coordinates with `outdated-implementations.json`

### traceability-matrix Plugin

Verification tickets contribute to traceability:

- Verification tickets link requirements to validation activities
- Supports FDA compliance documentation
- Feeds into traceability matrix generation

## Configuration

### Subsystem Definitions

Subsystem keywords are defined inline in `scripts/add-subsystem-checklist.js`:

```javascript
const SUBSYSTEMS = {
  'Supabase (Database & Auth)': [
    'database', 'supabase', 'schema', 'rls', ...
  ],
  'Mobile App (Flutter)': [
    'mobile', 'app', 'flutter', 'dart', ...
  ],
  // ... 9 more subsystems
};
```

**To modify**: Edit the SUBSYSTEMS object in `add-subsystem-checklist.js`. Keep keywords inline (no separate lib/ file) for simplicity.

### Ticket Labels

Verification tickets are automatically labeled:

- `verification`: Indicates this is a verification task
- `requirement-change`: Triggered by requirement modification
- `REQ-{id}`: Specific requirement being verified (e.g., `REQ-d00027`)

### Priority Settings

- Default priority: `high` (changed requirements need immediate attention)
- Override via `--priority` flag when creating tickets
- Priorities: `urgent`, `high`, `medium`, `low`

## Error Handling

### Common Errors

**Missing LINEAR_API_TOKEN**:
```
Error: Missing LINEAR_API_TOKEN environment variable
Solution: Ensure token is set via linear-integration plugin
```

**Requirement not found**:
```
Error: Requirement REQ-d00027 not found in spec/ files
Solution: Verify requirement exists and ID is correct
```

**No subsystems detected**:
```
Warning: No sub-systems identified for ticket CUR-123
Possible causes:
- Requirement too abstract or infrastructure-only
- Keywords need updating in SUBSYSTEMS definition
- Manual subsystem selection needed
```

**Ticket creation fails**:
```
Error: Linear API error: 401 Unauthorized
Solution: Verify LINEAR_API_TOKEN is valid
         Run: node tools/anspar-cc-plugins/plugins/linear-integration/scripts/test-config.js
```

### Rate Limiting

- Scripts include 100ms delays between Linear API calls
- Bulk operations are safe and respect Linear's rate limits
- No manual throttling needed

## Best Practices

### 1. Always Use Dry-Run First

```bash
# Preview changes before executing
node scripts/add-subsystem-checklist.js --token=$LINEAR_API_TOKEN --dry-run
```

### 2. Validate JSON Input

```bash
# Verify JSON is valid before creating tickets
jq . changed-req.json  # Use jq to validate JSON
node scripts/create-verification.js --input changed-req.json
```

### 3. Link Related Tickets

In Linear ticket descriptions, cross-reference:
- Original implementation tickets
- Related verification tickets
- Requirement change commits

### 4. Update Tracking Files

Keep `untracked-notes/outdated-implementations.json` in sync:

```bash
# After verification complete
python3 tools/anspar-cc-plugins/plugins/simple-requirements/scripts/mark-verified.py d00027
```

### 5. Document Verification Decisions

In ticket comments, document:
- Why each subsystem was/wasn't affected
- What implementations were reviewed
- What changes were made
- Test results

## FAQ

**Q: When should I create a verification ticket?**
A: Automatically when a requirement's hash changes. The simple-requirements plugin detects this and triggers ticket creation.

**Q: What if a ticket has no subsystems detected?**
A: This may indicate the requirement is too abstract or infrastructure-only. Manually review and add subsystems if needed.

**Q: Can I skip subsystems that don't seem relevant?**
A: Be conservative - include subsystems when in doubt. False positives are better than missing critical verification.

**Q: How do I mark verification as complete?**
A:
1. Complete all subsystem checklist items
2. Close the Linear ticket
3. Run `mark-verified.py` to remove from tracking

**Q: What if verification reveals the requirement is wrong?**
A: Create a new ticket to fix the requirement itself. This is a separate issue from verification.

**Q: Can I batch-create verification tickets?**
A: Yes, pipe multiple JSON objects to create-verification.js or use it in a loop.

## Related Documentation

- **FDA 21 CFR Part 11**: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application
- **ALCOA+ Principles**: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/data-integrity-and-compliance-drug-cgmp-questions-and-answers
- **spec/prd-compliance.md**: Product requirements for compliance features
- **spec/ops-compliance.md**: Operational compliance procedures
- **spec/dev-compliance.md**: Developer guidelines for maintaining compliance
- **docs/adr/**: Architecture Decision Records related to compliance

## License

MIT

## Author

Anspar Foundation - https://github.com/anspar

## Contributing

This is a diary-project-specific plugin. For changes:

1. Claim a ticket: `/workflow:claim CUR-XXX`
2. Make changes following project guidelines
3. Test with `--dry-run` mode
4. Commit with requirement references: `Implements: REQ-dXXXXX`
5. Create PR and ensure validation passes

## Changelog

### 1.0.0 (2025-11-08)

Initial release:
- Verification ticket creation for changed requirements
- Subsystem impact analysis (11 subsystems)
- FDA 21 CFR Part 11 compliance verification workflows
- Integration with linear-integration and simple-requirements plugins

# Add Requirement-Based Checklist

Automatically generate implementation checklists for Linear tickets based on requirement hierarchies and dependencies.

## Usage

Add checklist based on ticket's requirement:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/add-subsystem-checklists.js \
  --ticketId="CUR-312" \
  --fromRequirement
```

## Parameters
- `--ticketId`: Linear ticket identifier (required)
- `--fromRequirement`: Extract REQ from ticket and generate checklist from sub-requirements
- `--requirement`: Explicitly specify requirement to use for checklist
- `--includeAcceptance`: Include acceptance criteria as checklist items
- `--includeSubsystems`: Add subsystem-specific tasks
- `--dry-run`: Preview checklist without updating ticket

## Automatic Checklist Generation

### From Requirement Content Analysis
Parses the actual requirement text from spec/ files to extract:

1. **SHALL/MUST statements** - Convert to mandatory tasks:
```markdown
From: "System SHALL validate all user input"
To: - [ ] Implement user input validation
```

2. **Bullet points and lists** - Direct conversion to checklist:
```markdown
From requirement text:
- Support OAuth2 authentication
- Integrate with LDAP
- Enable MFA for admin users

Becomes:
- [ ] Support OAuth2 authentication
- [ ] Integrate with LDAP
- [ ] Enable MFA for admin users
```

3. **Key concepts and components** - Identify implementation areas:
```markdown
From: "The portal uses React with TypeScript and Tailwind CSS"
To:
- [ ] Set up React with TypeScript
- [ ] Configure Tailwind CSS
- [ ] Create type definitions
```

4. **Technical specifications** - Extract as implementation tasks:
```markdown
From: "API responses must be under 200ms with caching"
To:
- [ ] Implement API response caching
- [ ] Add performance monitoring for 200ms target
- [ ] Set up cache invalidation strategy
```

### From Requirement Hierarchy
Analyzes requirement dependencies:
1. Find all child requirements (REQ-o* that implement it)
2. Find all grandchild requirements (REQ-d* that implement those)
3. Parse each requirement's content for actionable items
4. Generate comprehensive checklist:

```markdown
### Implementation Checklist

#### From REQ-p00001 Content:
- [ ] Implement complete data isolation
- [ ] Set up per-sponsor database instances
- [ ] Configure tenant separation

#### Child Requirements:
- [ ] Complete REQ-o00001: Database setup (3 sub-tasks)
- [ ] Complete REQ-o00002: Security config (5 sub-tasks)
- [ ] Complete REQ-d00001: API implementation (4 sub-tasks)
```

### From Acceptance Criteria Section
Specifically looks for "Acceptance Criteria" sections in requirements:
```markdown
### Acceptance Criteria (from spec)
- [ ] System validates user input before processing
- [ ] Error messages display within 2 seconds
- [ ] Audit log captures all actions
- [ ] All API endpoints return proper status codes
- [ ] Database transactions maintain ACID properties
```

### From Subsystem Analysis
Analyzes requirement to identify affected subsystems:
```markdown
### Subsystem Tasks
#### Database
- [ ] Update schema for new fields
- [ ] Add migration script
- [ ] Update RLS policies

#### API
- [ ] Implement new endpoint
- [ ] Update API documentation
- [ ] Add validation rules

#### Frontend
- [ ] Create UI components
- [ ] Add form validation
- [ ] Update user documentation
```

## Examples

### Basic: Add checklist from ticket's requirement
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/add-subsystem-checklists.js \
  --ticketId="CUR-312" \
  --fromRequirement
```

### Complete: All checklist types
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/add-subsystem-checklists.js \
  --ticketId="CUR-312" \
  --fromRequirement \
  --includeAcceptance \
  --includeSubsystems
```

### Preview without updating
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/add-subsystem-checklists.js \
  --ticketId="CUR-312" \
  --fromRequirement \
  --dry-run
```

### Explicit requirement
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/add-subsystem-checklists.js \
  --ticketId="CUR-312" \
  --requirement="REQ-p00024" \
  --includeAcceptance
```

## Workflow Integration

### 1. After Creating Ticket
```bash
# Create ticket
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-single-ticket.js \
  --title="Implement user authentication" \
  --description="Implements: REQ-p00002"

# Add comprehensive checklist
node ${CLAUDE_PLUGIN_ROOT}/scripts/add-subsystem-checklists.js \
  --ticketId="[returned-id]" \
  --fromRequirement \
  --includeAcceptance \
  --includeSubsystems
```

### 2. Enhancing Existing Tickets
```bash
# Find ticket
node ${CLAUDE_PLUGIN_ROOT}/scripts/search-tickets.js --query="REQ-d00027"

# Add implementation checklist
node ${CLAUDE_PLUGIN_ROOT}/scripts/add-subsystem-checklists.js \
  --ticketId="CUR-312" \
  --fromRequirement
```

## Smart Features

### Requirement Content Parsing
Intelligent extraction from spec/ files:

#### Pattern Recognition
- **SHALL/MUST/SHOULD** → Compliance tasks
- **Numbered lists** (1., 2., 3.) → Sequential steps
- **Bullet points** (-, *, •) → Parallel tasks
- **Code blocks** → Implementation examples to follow
- **Tables** → Configuration or mapping tasks
- **Bold text** → Key concepts needing implementation

#### Semantic Analysis
- **Technology mentions** (React, Docker, PostgreSQL) → Setup tasks
- **Integration points** (API, webhook, SSO) → Integration tasks
- **Performance metrics** (200ms, 99.9%) → Monitoring tasks
- **Security requirements** (MFA, encryption) → Security tasks
- **Compliance mentions** (HIPAA, GDPR) → Compliance tasks

#### Context Understanding
```markdown
From: "The system SHALL support multi-factor authentication using TOTP
       or SMS, with fallback to email verification for users without
       phone access."

Generates:
- [ ] Implement TOTP-based MFA
- [ ] Implement SMS-based MFA
- [ ] Create email verification fallback
- [ ] Add user preference for MFA method
- [ ] Handle phone number validation
- [ ] Implement recovery codes
```

### Requirement Detection
- Automatically finds REQ-* references in ticket description
- Validates requirement exists in spec/
- Reads full requirement content from spec files
- Handles multiple requirements (creates combined checklist)

### Hierarchy Traversal
- PRD → Ops → Dev requirement cascade
- Shows implementation dependencies
- Groups by requirement level

### Subsystem Intelligence
Recognizes keywords to identify subsystems:
- "database", "schema", "RLS" → Database tasks
- "API", "endpoint", "REST" → API tasks
- "UI", "frontend", "portal" → Frontend tasks
- "auth", "security", "MFA" → Security tasks
- "deploy", "CI/CD", "pipeline" → DevOps tasks

### Deduplication
- Avoids adding duplicate checklist items
- Merges with existing checklists
- Preserves checked state of existing items

## Notes
- Non-destructive: Appends to description, preserves existing content
- Works with anspar-workflow for comprehensive ticket management
- Combines well with requirements agent for validation
- Helps ensure nothing is missed during implementation
- Makes tickets self-documenting with clear success criteria
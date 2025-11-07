# Workflow State Schema

## Overview

Each git worktree maintains its own workflow state in `.git/WORKFLOW_STATE`. This file is the **source of truth** for which ticket this worktree is working on.

## File Location

```
.git/WORKFLOW_STATE
```

**Important**: This file is in `.git/` so it is:
- ✅ Per-worktree (each worktree has its own)
- ✅ Not committed to repository
- ✅ Isolated from other worktrees
- ✅ Automatically cleaned up when worktree is deleted

## JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["version", "worktree"],
  "properties": {
    "version": {
      "type": "string",
      "description": "Schema version (semver)",
      "const": "1.0.0"
    },
    "worktree": {
      "type": "object",
      "required": ["path", "branch"],
      "properties": {
        "path": {
          "type": "string",
          "description": "Absolute path to this worktree"
        },
        "branch": {
          "type": "string",
          "description": "Current git branch"
        }
      }
    },
    "sponsor": {
      "type": ["string", "null"],
      "description": "Current sponsor context. null = core functionality work (most common). Set to sponsor codename for sponsor-specific work. Valid sponsors are dynamically discovered from sponsor/ subdirectories.",
      "default": null
    },
    "activeTicket": {
      "type": "object",
      "description": "Currently claimed ticket (null if no active ticket)",
      "required": ["id", "requirements", "claimedAt", "claimedBy"],
      "properties": {
        "id": {
          "type": "string",
          "description": "Ticket ID (e.g., CUR-123, PROJ-456)",
          "pattern": "^[A-Z]+-[0-9]+$"
        },
        "requirements": {
          "type": "array",
          "description": "REQ IDs associated with this ticket",
          "items": {
            "type": "string",
            "pattern": "^REQ-[pdo][0-9]{5}$"
          }
        },
        "claimedAt": {
          "type": "string",
          "description": "ISO 8601 timestamp when ticket was claimed",
          "format": "date-time"
        },
        "claimedBy": {
          "type": "string",
          "description": "Agent type that claimed ticket",
          "enum": ["claude", "human"]
        },
        "trackerMetadata": {
          "type": "object",
          "description": "Optional tracker-specific metadata",
          "properties": {
            "trackerType": {
              "type": "string",
              "description": "Ticket tracker type",
              "enum": ["linear", "notion", "jira", "github"]
            }
          }
        }
      }
    },
    "history": {
      "type": "array",
      "description": "Log of ticket claims/releases (append-only)",
      "items": {
        "type": "object",
        "required": ["action", "timestamp"],
        "properties": {
          "action": {
            "type": "string",
            "enum": ["claim", "release", "commit"]
          },
          "timestamp": {
            "type": "string",
            "format": "date-time"
          },
          "ticketId": {
            "type": "string"
          },
          "details": {
            "type": "object",
            "description": "Action-specific details"
          }
        }
      }
    }
  }
}
```

## Example State File

### Active Ticket

```json
{
  "version": "1.0.0",
  "worktree": {
    "path": "/home/user/diary-worktrees/feature-workflow",
    "branch": "feature-workflow"
  },
  "sponsor": null,
  "activeTicket": {
    "id": "CUR-262",
    "requirements": ["REQ-d00027"],
    "claimedAt": "2025-10-30T12:00:00Z",
    "claimedBy": "claude",
    "trackerMetadata": {
      "trackerType": "linear"
    }
  },
  "history": [
    {
      "action": "claim",
      "timestamp": "2025-10-30T12:00:00Z",
      "ticketId": "CUR-262",
      "details": {
        "requirements": ["REQ-d00027"]
      }
    },
    {
      "action": "commit",
      "timestamp": "2025-10-30T12:15:00Z",
      "ticketId": "CUR-262",
      "details": {
        "commitHash": "abc123",
        "requirements": ["REQ-d00027"]
      }
    }
  ]
}
```

### No Active Ticket

```json
{
  "version": "1.0.0",
  "worktree": {
    "path": "/home/user/diary-worktrees/hotfix-123",
    "branch": "hotfix-123"
  },
  "sponsor": null,
  "activeTicket": null,
  "history": [
    {
      "action": "claim",
      "timestamp": "2025-10-30T10:00:00Z",
      "ticketId": "CUR-250",
      "details": {
        "requirements": ["REQ-d00015"]
      }
    },
    {
      "action": "release",
      "timestamp": "2025-10-30T11:30:00Z",
      "ticketId": "CUR-250",
      "details": {
        "reason": "Work complete"
      }
    }
  ]
}
```

## State Transitions

### Initialization (claim-ticket.sh)

```bash
# From: No state file exists
# To: State file with activeTicket

./scripts/claim-ticket.sh CUR-262
```

Creates:
```json
{
  "version": "1.0.0",
  "worktree": {
    "path": "<current-worktree-path>",
    "branch": "<current-branch>"
  },
  "sponsor": null,
  "activeTicket": {
    "id": "CUR-262",
    "requirements": ["REQ-d00027"],  // Fetched from Linear
    "claimedAt": "2025-10-30T12:00:00Z",
    "claimedBy": "claude"
  },
  "history": [
    {
      "action": "claim",
      "timestamp": "2025-10-30T12:00:00Z",
      "ticketId": "CUR-262",
      "details": {
        "requirements": ["REQ-d00027"]
      }
    }
  ]
}
```

### Commit (post-commit hook)

```bash
# From: State file with activeTicket
# To: State file with updated history

git commit -m "Implement feature X\n\nImplements: REQ-d00027"
# post-commit hook runs
```

Updates history:
```json
{
  "history": [
    // ... existing history ...
    {
      "action": "commit",
      "timestamp": "2025-10-30T12:15:00Z",
      "ticketId": "CUR-262",
      "details": {
        "commitHash": "abc123def456",
        "requirements": ["REQ-d00027"]
      }
    }
  ]
}
```

### Release (release-ticket.sh)

```bash
# From: State file with activeTicket
# To: State file with activeTicket = null

./scripts/release-ticket.sh
```

Updates state:
```json
{
  "activeTicket": null,
  "history": [
    // ... existing history ...
    {
      "action": "release",
      "timestamp": "2025-10-30T13:00:00Z",
      "ticketId": "CUR-262",
      "details": {
        "reason": "Work complete"
      }
    }
  ]
}
```

## Design Principles

### 1. Source of Truth

`.git/WORKFLOW_STATE` is the **authoritative source** for:
- Which ticket this worktree is working on
- When the ticket was claimed
- Which agent claimed it
- All workflow actions in this worktree

### 2. Linear is Coordination Layer

Linear ticket status ("In Progress") is **informational only**:
- ✅ Use for: Discovery, filtering, reporting
- ❌ Don't use for: Ownership locking, exclusive access

### 3. Multiple Worktrees Can Claim Same Ticket

**Valid scenario**: Multiple worktrees working on same ticket
- Example: Two PRs needed to complete REQ-d00027
- Each worktree has its own state file
- Both can have `activeTicket.id = "CUR-262"`
- Linear shows ticket as "In Progress" (correct)

### 4. Race Tolerance

Operations are designed to be **idempotent** or **append-only**:
- Adding Linear label: Idempotent (adding twice = no-op)
- Adding Linear comment: Append-only (two comments OK)
- Updating ticket status: Last-write-wins (acceptable)

### 5. History is Append-Only

`history` array is **never modified**, only appended to:
- Provides audit trail
- Can be used for debugging
- Can be analyzed for productivity metrics

## Integration with Ticket Trackers

### Linear Integration (linear-integration)

When claiming a ticket, the workflow plugin can optionally:

1. **Fetch requirements** from Linear ticket description
   ```bash
   # Linear ticket description contains:
   # **Requirement**: REQ-d00027

   # claim-ticket.sh extracts this and stores in state
   ```

2. **Update ticket status** to "In Progress"
   ```bash
   # Optional - informational only
   # Other worktrees may also set same ticket to "In Progress"
   ```

3. **Add comment** when releasing
   ```bash
   # "Work released from worktree feature-xyz"
   ```

### Future Tracker Support

The `trackerMetadata` field is extensible for other trackers:

**Notion**:
```json
"trackerMetadata": {
  "trackerType": "notion",
  "databaseId": "abc123",
  "pageId": "def456"
}
```

**Jira**:
```json
"trackerMetadata": {
  "trackerType": "jira",
  "projectKey": "PROJ",
  "issueKey": "PROJ-123"
}
```

## State File Lifecycle

### Creation

- Created by `claim-ticket.sh` or session start helper
- Initialized with worktree info and active ticket

### Updates

- `claim-ticket.sh`: Sets activeTicket
- `release-ticket.sh`: Clears activeTicket
- `post-commit` hook: Appends to history
- Never modified manually

### Deletion

- Automatically removed when worktree is deleted (`git worktree remove`)
- Can be manually removed (worktree will be treated as "no active ticket")
- Should be removed before deleting worktree manually

## Validation

Scripts validate state file:
- `version` must be "1.0.0"
- `activeTicket.id` must match ticket ID pattern
- `activeTicket.requirements` must be array of REQ-xxx
- Timestamps must be valid ISO 8601

Invalid state files are rejected with clear error messages.

## Troubleshooting

### State File Corrupted

```bash
# Backup and recreate
mv .git/WORKFLOW_STATE .git/WORKFLOW_STATE.bak
./scripts/claim-ticket.sh <TICKET-ID>
```

### Multiple Worktrees, Confused State

```bash
# Check state in each worktree
cd /path/to/worktree1
./scripts/get-active-ticket.sh

cd /path/to/worktree2
./scripts/get-active-ticket.sh

# Each worktree has independent state - this is normal!
```

### Lost State After Worktree Deletion

- State files are in `.git/` (per-worktree)
- Deleting worktree deletes its state
- This is by design (clean state management)
- Use `release-ticket.sh` before deleting worktree to update Linear

## Migration

### From No State Management

1. Existing worktrees have no `.git/WORKFLOW_STATE`
2. First commit will fail with "No active ticket"
3. Run `claim-ticket.sh <TICKET-ID>` to initialize
4. Commit succeeds

### From v1.0.0 to Future Versions

Migration scripts will be provided when schema changes.

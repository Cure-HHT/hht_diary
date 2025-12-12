# REQ-d00068: Enhanced Workflow New Work Detection

**Level**: Dev | **Implements**: - | **Status**: Draft

## Overview

Enhanced proactive workflow detection that integrates with the ticket-creation-agent to provide seamless ticket creation guidance when users start new work without an active ticket.

## Requirements

- **REQ-d00068.1**: Extended pattern detection (bug fixes, documentation work)
- **REQ-d00068.2**: Ticket-creation-agent integration in warning messages
- **REQ-d00068.3**: Actionable guidance with clear options
- **REQ-d00068.4**: Context-aware suggestions based on active ticket state
- **REQ-d00068.5**: Non-intrusive reminders (not blocking)

## Implementation

**Files Modified**:
- `hooks/user-prompt-submit` - Enhanced detection patterns and messages
- `README.md` - Updated documentation with examples
- `CHANGELOG.md` - Version 2.2.0 release notes

**Detection Patterns Added**:

1. **Bug Fix Detection**:
   - Patterns: "fix bug", "fix issue", "fix problem", "fix error"
   - Score: +4 to NEW_FEATURE_SCORE

2. **Documentation Work**:
   - Patterns: "update docs", "write README", "add documentation"
   - Score: +3 to NEW_FEATURE_SCORE

**Enhanced Messages**:

1. **No Active Ticket + Implementation Work**:
   - Suggests: "Create a ticket for [description]"
   - Points to ticket-creation-agent
   - Lists 3 clear options: create, claim, explore

2. **Active Ticket + New Feature**:
   - Asks if work is within ticket scope
   - Suggests using ticket-creation-agent for separate ticket
   - Maintains scope discipline

**Integration with Ticket-Creation-Agent**:
- Messages include natural language trigger: "Just say: 'Create a ticket for...'"
- Explains ticket-creation-agent capabilities
- Reduces friction between detection and action

## Benefits

- **Seamless workflow**: From detection → suggestion → creation in natural language
- **Reduced manual steps**: No need to remember script paths
- **Better ticket discipline**: Proactive rather than reactive enforcement
- **Context-aware**: Smart suggestions based on git state
- **Non-intrusive**: User maintains control, guidance not blocking

## Acceptance Criteria

- ✅ Bug fix patterns detected correctly
- ✅ Documentation work patterns detected correctly
- ✅ Messages suggest ticket-creation-agent
- ✅ Clear options provided for different scenarios
- ✅ README documentation updated with examples
- ✅ Non-blocking behavior maintained

## Related

- REQ-d00067: Streamlined Ticket Creation Agent
- REQ-d00064: JSON Validation
- REQ-d00065: Path Validation
- REQ-d00066: Permission Management


*End* *Enhanced Workflow New Work Detection* | **Hash**: f5f3570e
---

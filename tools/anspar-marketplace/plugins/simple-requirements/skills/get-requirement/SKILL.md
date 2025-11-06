# GetRequirement Skill

Fetch and display a requirement by its ID.

## Purpose

Allows Claude to quickly retrieve the full text and metadata of any requirement in the system. Useful when:
- User asks about a specific requirement
- Need to verify requirement content before implementation
- Checking requirement details during code review
- Understanding requirement dependencies

## Usage

```
Input: REQ-d00027 (or just d00027)
Output: Full requirement text with metadata
```

## Examples

### Example 1: Fetch by full ID
```
User: "Show me REQ-d00027"
Claude: [Uses GetRequirement skill with "REQ-d00027"]
Output:
### REQ-d00027: Containerized Development Environments

**Level**: Dev | **Implements**: o00001 | **Status**: Active | **Hash**: 8afe0445

The development environment SHALL use containerized...
[full requirement text]

**Source**: dev-environment.md:42
```

### Example 2: Fetch by short ID
```
User: "What does d00027 say?"
Claude: [Uses GetRequirement skill with "d00027"]
[Same output as above]
```

### Example 3: Requirement not found
```
User: "Show me REQ-d99999"
Claude: [Uses GetRequirement skill]
Output: ❌ Error: Requirement 'd99999' not found.
```

## Implementation

The skill calls `scripts/get-requirement.py` which:
1. Normalizes the requirement ID (removes REQ- prefix if present)
2. Parses all spec/*.md files
3. Finds the requested requirement
4. Returns formatted output with metadata

## Format

Output includes:
- **ID**: Full requirement ID (REQ-{type}{number})
- **Title**: Requirement title
- **Level**: PRD, Ops, or Dev
- **Implements**: Parent requirement IDs (if any)
- **Status**: Active, Draft, or Deprecated
- **Hash**: 8-character hash for change detection
- **Body**: Full requirement text (rationale, acceptance criteria, etc.)
- **Source**: File and line number

## Integration

This skill integrates with:
- **Validation system**: Uses same parser as validate_requirements.py
- **Hash system**: Displays hash for change detection
- **Traceability**: Shows implements hierarchy
- **Change tracking**: Used to review changed requirements

## Notes

- Accepts both `REQ-d00027` and `d00027` formats
- Case-insensitive
- Fast (< 1 second for any requirement)
- Works offline (no API calls)
- Always returns current version from spec files

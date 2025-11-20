---
name: scan
description: Find tickets missing REQ references
arguments: "[--format=summary|json]"
---

# /req:scan Command

Scan Linear tickets to find those missing requirement references for FDA compliance.

## Purpose

The `/req:scan` command ensures traceability by:
- Fetching all open tickets from Linear
- Parsing ticket descriptions for REQ-ID references
- Identifying tickets without requirement links
- Suggesting requirements based on keywords
- Supporting both summary and JSON output

## Usage

```bash
/req:scan                          # Scan all open tickets
/req:scan --format=summary         # Human-readable summary (default)
/req:scan --format=json            # Machine-readable JSON
```

## Arguments

### `--format=<FORMAT>` *(optional)*

Output format:
- `summary` (default): Human-readable report with suggestions
- `json`: Machine-readable JSON for automation
- Example: `--format=json`

## Behavior

### Scan Process

1. **Fetches open tickets**: Queries Linear for tickets in "Todo" or "In Progress"
2. **Extracts REQ references**: Parses descriptions for `REQ-{p|o|d}NNNNN` pattern
3. **Identifies missing**: Finds tickets without any REQ reference
4. **Suggests requirements**: Uses heuristics to recommend REQ-IDs
5. **Prioritizes results**: Groups by priority (Urgent → High → Normal → Low)

### Suggestion Heuristics

Matches ticket titles/descriptions to requirements using:
- **Keyword matching**: Search requirement titles for ticket keywords
- **Label analysis**: Map labels to requirement types
  - `backend` → Dev requirements
  - `security` → Security-related requirements
  - `database` → Database requirements
- **Project context**: Use project name to narrow scope
- **Recent patterns**: Look at recently linked REQs in same project

## Examples

### Summary Report

```bash
/req:scan

# Output:
# Scanning Linear tickets for missing requirement references...
#
# Fetching open tickets (status: Todo, In Progress)...
# Found 42 open tickets
#
# Analyzing requirement references...
# 27 tickets have REQ references ✅
# 15 tickets missing REQ references ❌
#
# ════════════════════════════════════════════════════════════
# Tickets Missing Requirement References
# ════════════════════════════════════════════════════════════
#
# 🔴 URGENT (2 tickets)
#
#   CUR-345: Critical: Password reset broken
#   Status: In Progress | Priority: Urgent
#   Labels: security, backend, bug
#   💡 Suggested: REQ-p00001 (Multi-sponsor authentication)
#
#   CUR-346: Database migration blocking deployment
#   Status: In Progress | Priority: Urgent
#   Labels: database, backend
#   💡 Suggested: REQ-d00007 (Database schema implementation)
#
# 🟠 HIGH (5 tickets)
#
#   CUR-240: Implement multi-factor authentication
#   Status: Todo | Priority: High
#   Labels: security, backend
#   💡 Suggested: REQ-p00042 (Multi-factor authentication via TOTP)
#
#   CUR-262: Database migration for user roles
#   Status: In Progress | Priority: High
#   Labels: backend, database
#   💡 Suggested: REQ-d00007 (Database schema implementation)
#
#   ...
#
# 🟡 NORMAL (7 tickets)
#
#   CUR-156: Update authentication documentation
#   Status: Todo | Priority: Normal
#   Labels: docs
#   💡 Suggested: REQ-p00001 (Multi-sponsor authentication)
#
#   ...
#
# 🔵 LOW (1 ticket)
#
#   CUR-189: Refactor login form component
#   Status: Todo | Priority: Low
#   Labels: frontend, refactor
#   💡 Manual review needed
#
# ════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════
#
# Total open tickets: 42
# With REQ references: 27 (64%)
# Missing REQ references: 15 (36%)
#
# Next steps:
#   1. Review suggestions above
#   2. Add requirements: /add-REQ-to-ticket CUR-XXX REQ-XXXXX
#   3. Create bulk mapping: /add-REQ-to-ticket --bulk mappings.json
```

### JSON Output

```bash
/req:scan --format=json

# Output:
# {
#   "timestamp": "2025-11-19T14:30:00Z",
#   "total_tickets": 42,
#   "with_requirements": 27,
#   "missing_requirements": 15,
#   "tickets": [
#     {
#       "id": "CUR-345",
#       "title": "Critical: Password reset broken",
#       "status": "In Progress",
#       "priority": "Urgent",
#       "priorityLabel": "🔴 Urgent",
#       "labels": ["security", "backend", "bug"],
#       "url": "https://linear.app/cure-hht/issue/CUR-345",
#       "has_requirement": false,
#       "suggested_requirement": {
#         "id": "REQ-p00001",
#         "title": "Multi-sponsor authentication",
#         "confidence": "high",
#         "reason": "Keyword match: authentication"
#       }
#     },
#     {
#       "id": "CUR-240",
#       "title": "Implement multi-factor authentication",
#       "status": "Todo",
#       "priority": "High",
#       "priorityLabel": "🟠 High",
#       "labels": ["security", "backend"],
#       "url": "https://linear.app/cure-hht/issue/CUR-240",
#       "has_requirement": false,
#       "suggested_requirement": {
#         "id": "REQ-p00042",
#         "title": "Multi-factor authentication via TOTP",
#         "confidence": "high",
#         "reason": "Exact keyword match: multi-factor authentication"
#       }
#     }
#   ]
# }
```

### Empty Scan

```bash
/req:scan

# Output:
# Scanning Linear tickets for missing requirement references...
#
# ✅ All open tickets have requirement references!
#
# Total open tickets: 42
# With REQ references: 42 (100%)
# Missing REQ references: 0 (0%)
#
# Great job maintaining requirement traceability! 🎉
```

## Integration Points

This command integrates with:
- **Linear API**: Fetches ticket data
- **spec/INDEX.md**: Validates suggested requirements
- **.requirement-cache.json**: Checks cached mappings
- **/add-REQ-to-ticket**: Follow-up command to add requirements

## Exit Codes

- `0` - Success (scan completed)
- `1` - No tickets found
- `2` - Linear API error
- `3` - Authentication error

## Error Handling

The command handles:
- Missing LINEAR_API_TOKEN
- No open tickets found
- Invalid requirement suggestions
- API rate limits
- Network timeouts

### Authentication Error

```
Error: LINEAR_API_TOKEN invalid or missing

Set environment variable:
  export LINEAR_API_TOKEN="your-token-here"

Or configure via Doppler:
  doppler run -- claude
```

### No Open Tickets

```
No open tickets found

All tickets are in "Done", "Canceled", or "Backlog" state.

This is expected if:
1. Sprint/project is complete
2. No active work in progress
3. Tickets moved to backlog

Check all tickets:
  /linear:search --query="" --format=json
```

### Rate Limit

```
Warning: Linear API rate limit approaching

Processed 50 tickets, pausing for 30 seconds...

For large teams, consider:
1. Running during off-peak hours
2. Using --format=json and caching results
3. Filtering by project or date range
```

## Use Cases

### Sprint Planning

```bash
# Before sprint: Ensure all tickets have requirements
/req:scan

# Review tickets missing REQs
# Add requirements before starting work
```

### Compliance Audit

```bash
# Generate JSON report for FDA audit
/req:scan --format=json > requirement-traceability-report.json

# Process with jq for analysis
cat requirement-traceability-report.json | \
  jq '.tickets[] | select(.has_requirement == false)'
```

### Weekly Review

```bash
# Check traceability coverage weekly
/req:scan

# Aim for 100% coverage
# Address missing requirements promptly
```

### Bulk Remediation

```bash
# 1. Scan and export
/req:scan --format=json > missing-reqs.json

# 2. Create mapping file
cat missing-reqs.json | \
  jq '.tickets[] | {ticketId: .id, reqId: .suggested_requirement.id}' | \
  jq -s '{mappings: .}' > mappings.json

# 3. Bulk add requirements
/add-REQ-to-ticket --bulk mappings.json
```

## Suggestion Confidence Levels

**High confidence**:
- Exact keyword match in title
- Strong label correlation
- Recent pattern match

**Medium confidence**:
- Partial keyword match
- Label hints
- Project context

**Low confidence** (manual review needed):
- No clear match
- Ambiguous keywords
- Multiple possible requirements

## Best Practices

1. **Run regularly**: Weekly or before sprint planning
2. **Prioritize urgent tickets**: Address high-priority missing REQs first
3. **Review suggestions**: Don't blindly accept automated suggestions
4. **Use bulk operations**: For large remediation efforts
5. **Track trends**: Monitor traceability percentage over time
6. **Integrate with CI/CD**: Block PRs for tickets without REQs

## Related Commands

- **/add-REQ-to-ticket** - Add requirement to ticket
- **/req:create-tickets** - Create tickets for unmapped requirements
- **/linear:search** - Search tickets by requirement
- **/requirements:report** - Generate compliance reports

## Implementation

```bash
node ${CLAUDE_PLUGIN_ROOT}/../requirement-traceability/scripts/scan-tickets-for-reqs.js "$@"
```

## Notes

- Requires LINEAR_API_TOKEN environment variable
- Scans only open tickets (Todo, In Progress)
- REQ-ID pattern: `REQ-{p|o|d}NNNNN`
- Suggestions are heuristic-based (review before applying)
- JSON format useful for automation
- Rate limited to 60 requests per minute
- Results cached for 5 minutes to reduce API calls

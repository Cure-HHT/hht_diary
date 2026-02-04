# CureHHT Development Workflow Plugin

A Claude Code plugin that provides development workflow guidance for the CureHHT project.

## Purpose

This plugin provides a quick reference checklist for the mandatory development workflow practices that all CureHHT developers must follow. It ensures consistency, quality, and FDA 21 CFR Part 11 compliance across the codebase.

## Installation

The plugin is part of the anspar-cc-plugins marketplace and is automatically available when the marketplace is enabled.

## Commands

### `/curehht-dev`

Displays the CureHHT development workflow practices checklist.

**Usage:**
```bash
/curehht-dev
```

## Workflow Practices Covered

1. **Always claim a ticket before starting work** - Use `/claim TICKET-ID` or the workflow:workflow agent
2. **Always work on a branch** - Never commit directly to main. Create branches like `feature/`, `fix/`, `release/`
3. **Always create a failing test first (TDD)** - Write the test that demonstrates the bug/missing feature before implementing the fix
4. **Run tests with coverage** - Use `./tool/test.sh --coverage` to run tests
5. **Maintain coverage above 70%** - Coverage threshold is 70%, ensure new code is tested
6. **All commits must include REQ references** - Format: `Implements: REQ-xxx` or `Fixes: REQ-xxx`

## Why These Practices Matter

These practices are mandatory for FDA 21 CFR Part 11 compliance:

- **Ticket claiming** - Ensures audit trail of who worked on what
- **Branch protection** - Prevents accidental changes to production code
- **TDD** - Ensures code is testable and behavior is documented
- **Coverage thresholds** - Maintains code quality and reduces defects
- **REQ traceability** - Links all changes to requirements for audit

## Related Plugins

- `workflow` - Git workflow enforcement and ticket management
- `simple-requirements` - Requirement validation and tracking
- `requirement-traceability` - REQ-to-ticket traceability

## Version History

- **1.0.0** - Initial release with workflow checklist command

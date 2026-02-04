---
name: curehht-dev
description: Display CureHHT development workflow practices checklist
arguments: ""
---

# /curehht-dev Command

Display the CureHHT development workflow practices as a checklist reminder.

## Purpose

The `/curehht-dev` command provides a quick reference for the mandatory development workflow practices that all CureHHT developers must follow. This ensures consistency, quality, and compliance across the codebase.

## Usage

```bash
/curehht-dev
```

## Output

When invoked, display the following checklist:

---

## CureHHT Development Workflow Checklist

Before starting any work, ensure you follow these mandatory practices:

### 1. Claim a Ticket Before Starting Work

- [ ] Use `/claim TICKET-ID` or the `workflow:workflow` agent to claim your ticket
- Never start work without a claimed ticket
- This ensures proper tracking and prevents conflicts

### 2. Always Work on a Branch

- [ ] Never commit directly to `main`
- [ ] Create a branch with appropriate prefix:
  - `feature/` - for new features
  - `fix/` - for bug fixes
  - `release/` - for release preparation
- Example: `feature/CUR-123-add-patient-login`

### 3. Create a Failing Test First (TDD)

- [ ] Write the test that demonstrates the bug or missing feature BEFORE implementing the fix
- [ ] Verify the test fails for the right reason
- [ ] Then implement the code to make the test pass
- This practice ensures testable code and documented expected behavior

### 4. Run Tests with Coverage

- [ ] Use `./tool/test.sh --coverage` to run tests with coverage analysis
- [ ] Review the coverage report to identify untested code paths
- [ ] Add tests for any uncovered critical paths

### 5. Maintain Coverage Above 70%

- [ ] Coverage threshold is 70% - ensure new code meets this bar
- [ ] Focus on testing critical paths and edge cases
- [ ] Use coverage reports to identify gaps

### 6. All Commits Must Include REQ References

- [ ] Every commit message must include requirement traceability
- [ ] Use format: `Implements: REQ-xxx` or `Fixes: REQ-xxx`
- [ ] Git hooks will block commits without REQ references
- [ ] Requirement format: `REQ-{p|o|d}NNNNN` (e.g., `REQ-d00027`)

---

## Quick Reference Commands

| Task | Command |
| ------ | --------- |
| Claim a ticket | `/claim CUR-123` |
| Release a ticket | `/release` |
| Run tests | `./tool/test.sh --coverage` |
| Check coverage | Review `coverage/lcov-report/index.html` |

## Related Commands

- `/claim` - Claim a ticket for work
- `/release` - Release the current ticket
- `/requirements:report` - View requirement coverage
- `/workflow:history` - View workflow history

## Why These Practices Matter

These practices are mandatory for FDA 21 CFR Part 11 compliance:

1. **Ticket claiming** - Ensures audit trail of who worked on what
2. **Branch protection** - Prevents accidental changes to production code
3. **TDD** - Ensures code is testable and behavior is documented
4. **Coverage thresholds** - Maintains code quality and reduces defects
5. **REQ traceability** - Links all changes to requirements for audit

---

*Tip: Run `/curehht-dev` at the start of each work session as a reminder!*

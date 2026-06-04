# Audit Log — Administrator User Journeys

> **Role**: Administrator
> **Source**: spec/prd-audit-log.md, spec/prd-user-account.md
> **Scope**: Sponsor Portal (web). The journey begins with the Administrator
> already signed in and on the Administrator Dashboard.

---

# JNY-AUDIT-01: View the Administrator Audit Log

**Actor**: Jordan Avery, a Sponsor Portal Administrator
**Goal**: Review the recorded administrative actions for the portal
**Context**: Jordan is on the Administrator Dashboard. The dashboard exposes two top-level tabs: Users and Audit Logs.

Validates: DIARY-GUI-audit-log-common, DIARY-GUI-audit-log-administrator

## Steps

1. Jordan clicks the "Audit Logs" top-level tab.
2. The Administrator Audit Log View is displayed as a table with Timestamp, Action, User, and Details columns, scoped to administrative actions.
3. Entries are listed in reverse chronological order (most recent first).
4. Jordan reads an entry's Details column, which gives a human-readable summary including the prior state, any parameters, and any free-text reason supplied with the action.
5. Jordan clicks the "More details" control on an entry to view the full raw record as text.

## Expected Outcome

Jordan can review administrative actions in reverse chronological order, read a human-readable summary of each, and expand any entry to its full raw record. When no entries match, an empty-state message is shown.

*End* *View the Administrator Audit Log*

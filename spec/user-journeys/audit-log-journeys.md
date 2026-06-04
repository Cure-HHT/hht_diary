# Audit Log — User Journeys

> **Roles**: Administrator, Study Coordinator (each role sees its own
> role-scoped audit log view)
> **Source**: spec/prd-audit-log.md, spec/prd-user-account.md
> **Scope**: Sponsor Portal (web). Each journey begins with the actor already
> signed in and on their default landing view.

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

---

# JNY-AUDIT-02: View the Study Coordinator Audit Log

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Review her own recorded actions, filtered to a specific participant
**Context**: Dr. Mitchell is signed in and navigates to the audit log from her default landing view. The Study Coordinator audit log view shows her own actions and includes a Participant ID column.

Validates: DIARY-GUI-audit-log-common, DIARY-GUI-audit-log-study-coordinator

## Steps

1. Dr. Mitchell opens the audit log view.
2. The Study Coordinator Audit Log View is displayed as a table with Timestamp, Action, User, and Details columns plus a Participant ID column, scoped to her own actions and listed most-recent-first.
3. Dr. Mitchell types a Participant ID into the Participant ID search input; the list filters in real time to that participant's records.
4. Dr. Mitchell reads an entry's Details column for a human-readable summary including prior state, parameters, and any reason supplied.
5. Dr. Mitchell clicks the "More details" control to view the full raw record as text.

## Expected Outcome

Dr. Mitchell can review her own actions in reverse chronological order, filter them to a specific participant by Participant ID, and expand any entry to its full raw record. When no entries match, an empty-state message is shown.

*End* *View the Study Coordinator Audit Log*

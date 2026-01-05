# Data Query (Discrepancy Note) Requirements

**Version**: 1.0
**Audience**: Product Requirements
**Status**: Roadmap (Future EDC capability)

---

## Overview

Data query workflow requirements for clinical data management. Required if HHT Diary evolves into a full EDC, replacing Medidata RAVE.

---

## REQ-p90020: Query Type Taxonomy

**Level**: PRD | **Status**: Roadmap

The system SHALL support distinct query types for different purposes.

Query types SHALL include:

| Type | Purpose | Response Required |
| ------ | --------- | ------------------- |
| Failed Validation | Auto-generated validation errors | Yes |
| Annotation | Informational notes | No |
| Query | Data clarification questions | Yes |
| Reason for Change | Edit justification | No |

**Rationale**: Different query purposes require different workflows and response expectations.

*End* *Query Type Taxonomy*

---

## REQ-p90021: Query Resolution State Machine

**Level**: PRD | **Status**: Roadmap

The system SHALL enforce a state machine for query resolution workflow.

States SHALL include:
- **Open**: New query, awaiting response
- **Updated**: Response added, under discussion
- **Resolved**: Resolution proposed, awaiting closure
- **Closed**: Query completed (terminal)
- **Not Applicable**: Query no longer relevant (terminal)

Valid transitions:
```
Open → Updated, Not Applicable
Updated → Resolved, Not Applicable
Resolved → Updated (reopen), Closed
```

**Rationale**: Structured workflow ensures queries are properly addressed and documented.

*End* *Query Resolution State Machine*

---

## REQ-p90022: Query Threading

**Level**: PRD | **Status**: Roadmap

The system SHALL support threaded conversations within queries.

Threading SHALL ensure:
- Original query is parent record
- Responses are child records linked to parent
- Resolution status tracked on parent only
- Adding response transitions parent to Updated state
- Complete thread history preserved

**Rationale**: Complex data issues may require multi-turn discussion before resolution.

*End* *Query Threading*

---

## REQ-p90023: Query Entity Mapping

**Level**: PRD | **Status**: Roadmap

The system SHALL link queries to specific data entities and fields.

Entity mapping SHALL include:
- Entity type (diary entry, questionnaire, visit, patient)
- Entity identifier
- Specific field/column name
- Activation status (deactivated if entity deleted)

**Rationale**: Queries must reference specific data points for actionable resolution.

*End* *Query Entity Mapping*

---

## REQ-p90024: Query Assignment

**Level**: PRD | **Status**: Roadmap

The system SHALL support assignment of queries to specific users.

Assignment SHALL include:
- Assignee selection (for Query type only)
- Email notification option
- Reassignment capability
- Assignment history in audit trail

**Rationale**: Clear ownership ensures queries receive timely attention.

*End* *Query Assignment*

---

## REQ-p90025: Automatic Query Generation

**Level**: PRD | **Status**: Roadmap

The system SHALL automatically create queries when validation rules fail.

Automatic queries SHALL:
- Be created as Failed Validation type
- Reference the failing entity and field
- Include validation error message
- Start in Open state
- Be attributed to system

**Rationale**: Validation failures must be documented and resolved through the query workflow.

*End* *Automatic Query Generation*

---

## REQ-p90026: Query Aging and Escalation

**Level**: PRD | **Status**: Roadmap

The system SHALL track query age and support escalation.

Aging thresholds:
- 0-7 days: Current (normal workflow)
- 8-14 days: Aging (highlighted in dashboard)
- 15+ days: Overdue (escalation notification)

Escalation SHALL notify supervisors of overdue queries.

**Rationale**: Timely query resolution is critical for data quality and study timelines.

*End* *Query Aging and Escalation*

---

## REQ-p90027: Query Notifications

**Level**: PRD | **Status**: Roadmap

The system SHALL support email notifications for query events.

Notifications SHALL include:
- New query assignment
- Response added to assigned query
- Resolution proposed
- Escalation for overdue queries

Notifications SHALL include study context, entity reference, and link to query.

**Rationale**: Email notifications ensure timely awareness of query activity.

*End* *Query Notifications*

---

## Query Workflow Summary

### Creation Flow
1. Select data field with issue
2. Choose query type
3. Enter description
4. Assign to user (Query type)
5. Send notification (optional)
6. Submit

### Response Flow
1. View assigned queries inbox
2. Select query, view thread
3. Add response
4. Submit (parent → Updated)

### Resolution Flow
1. Review complete thread
2. Propose resolution
3. Submit (parent → Resolved)
4. Supervisor reviews and closes

---

## Visual Indicators

| Status | Color | Meaning |
| -------- | ------- | --------- |
| Open | Yellow | Needs attention |
| Updated | Orange | Has new response |
| Resolved | Green | Resolution proposed |
| Closed | Black | Completed |
| Not Applicable | Gray | No longer relevant |

---

## References

- OpenClinica DiscrepancyNote implementation
- ICH E6(R2) Good Clinical Practice guidelines

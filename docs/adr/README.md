# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records (ADRs) documenting significant architectural and design decisions for the Diary Database.

## What is an ADR?

An Architecture Decision Record (ADR) is a document that captures an important architectural decision made along with its context and consequences.

## Format

Each ADR follows this structure:

```markdown
# ADR-XXX: [Title]

## Status
[Proposed | Accepted | Deprecated | Superseded]

## Context
What is the issue we're facing? What factors are driving this decision?

## Decision
What architectural decision are we making?

## Consequences
What becomes easier or harder as a result of this decision?

### Positive
- Benefits of this decision

### Negative
- Drawbacks or trade-offs

## Alternatives Considered
What other options did we consider and why were they rejected?
```

## Index of ADRs

| ADR | Title | Status | Date |
| --- | --- | --- | --- |
| [001](./ADR-001-event-sourcing-pattern.md) | Event Sourcing Pattern for Diary Data | Accepted | 2025-10-14 |
| [002](./ADR-002-jsonb-flexible-schema.md) | JSONB for Flexible Diary Schema | Accepted | 2025-10-14 |
| [003](./ADR-003-row-level-security.md) | Row-Level Security for Multi-Tenancy | Accepted | 2025-10-14 |
| [004](./ADR-004-investigator-annotations.md) | Separation of Investigator Annotations | Accepted | 2025-10-14 |
| [005](./ADR-005-database-migration-strategy.md) | Database Migration Strategy | Accepted | 2025-10-14 |
| [006](./ADR-006-docker-dev-environments.md) | Docker Dev Environments | Accepted | 2025-10-15 |
| [007](./ADR-007-multi-sponsor-build-reports.md) | Multi-Sponsor Build Reports | Accepted | 2025-10-16 |
| [008](./ADR-008-timestamp-attestation.md) | Timestamp Attestation | Accepted | 2025-10-20 |
| [009](./ADR-009-pulumi-infrastructure-as-code.md) | Pulumi Infrastructure as Code | Accepted | 2025-11-01 |
| [010](./ADR-010-requirements-format-enhancements.md) | Requirements Format Enhancements | Accepted | 2025-11-15 |
| [011](./ADR-011-event-sourcing-refinements.md) | Event Sourcing Refinements | Accepted | 2026-01-01 |
| [012](./ADR-012-terminology-standardization.md) | Terminology Standardization | Accepted | 2026-01-25 |

## When to Create an ADR

Create an ADR when making **significant architectural or design decisions** about:
- Database schema design patterns
- Technology choices (frameworks, libraries, platforms)
- Architecture patterns (event sourcing, CQRS, microservices)
- Security models (authentication, authorization, encryption)
- Compliance approaches
- Performance optimization strategies
- Data modeling approaches

**Not every decision needs an ADR** - reserve ADRs for decisions that:
- ✅ Have significant long-term impact on the system
- ✅ Involve trade-offs between multiple valid alternatives
- ✅ Affect multiple components or teams
- ✅ Have compliance or regulatory implications
- ✅ Are hard to reverse once implemented

**Don't create ADRs for**:
- ❌ Routine implementation choices (variable names, file organization)
- ❌ Trivial decisions with obvious solutions
- ❌ Decisions that can be easily reversed without consequence

## ADR Lifecycle

1. **Proposed**: Initial draft, under discussion
2. **Accepted**: Decision approved and implemented
3. **Deprecated**: Decision no longer recommended but still in use
4. **Superseded**: Replaced by a newer ADR (reference the superseding ADR)

## ADR Generation Process

ADRs are typically created in response to tickets or during feature development. Follow this workflow:

### 1. Trigger: Ticket or Feature Request

Most ADRs originate from:
- **Feature tickets**: "Add support for multiple languages" → ADR needed for i18n architecture
- **Technical debt tickets**: "Improve query performance" → ADR for caching strategy
- **Bug investigations**: "Race condition in sync" → ADR for conflict resolution approach
- **Compliance requirements**: "Add GDPR support" → ADR for data retention policy

**In your ticket tracking system**:
```
Ticket #123: Add multi-language support
- During implementation planning, team identifies need for ADR
- Developer creates ADR-XXX draft to document decision
```

### 2. Draft ADR (Status: Proposed)

When you identify a decision that needs documentation:

1. **Create ADR file**: `docs/adr/ADR-XXX-descriptive-title.md`
2. **Use next sequential number**: Check index below for next available number
3. **Copy the template structure** (see Format section above)
4. **Set status to "Proposed"**
5. **Reference the ticket**: Add ticket number in Context section
   ```markdown
   ## Context

   **Ticket**: #123 - Add multi-language support

   We need to support multiple languages...
   ```

6. **Fill in sections**:
   - **Context**: What problem are we solving? Why now? (reference ticket)
   - **Decision**: What are we choosing to do?
   - **Consequences**: What are the trade-offs?
   - **Alternatives Considered**: What else did we evaluate?

### 3. Review & Discussion

1. **Share with team**: Create PR with ADR draft
2. **Gather feedback**: Team reviews alternatives and consequences
3. **Iterate**: Update ADR based on discussion
4. **Decision point**: Team decides to accept, reject, or revise

### 4. Implementation (Status: Accepted)

Once the decision is made:

1. **Update status to "Accepted"**
2. **Add implementation date**
3. **Update this index** (table above)
4. **Implement the decision**: Write code, update configs, etc.
5. **Link ADR to implementation**:
   - Reference ADR in commit messages: `"Implement multi-language support per ADR-XXX"`
   - Add ADR reference to code comments where relevant
   - Link requirements if applicable (see spec/requirements-format.md)

6. **Commit ADR with implementation**: ADR and code go together
   ```bash
   git add docs/adr/ADR-XXX-*.md
   git add src/i18n/
   git commit -m "[Ticket #123] Add multi-language support per ADR-XXX"
   ```

### 5. Maintenance (Deprecated/Superseded)

As the system evolves:

- **Deprecated**: Decision no longer recommended but still in use
  - Update status and add deprecation note
  - Document why it's deprecated and what replaces it

- **Superseded**: Replaced by a newer ADR
  - Update status to "Superseded by ADR-YYY"
  - New ADR should reference the old one in Context section

## Contributing

When creating a new ADR:
1. Identify trigger (usually a ticket or feature requirement)
2. Create draft ADR file with "Proposed" status
3. Copy the template structure above
4. Use the next sequential number (ADR-XXX)
5. Write a clear, descriptive title
6. Fill in all sections thoroughly, including ticket reference
7. Get review from technical lead and team
8. Update status to "Accepted" after approval
9. Update this index
10. Commit the ADR with the implementing code, referencing the ticket

## Relationship to Requirements and Tickets

Understanding how ADRs, requirements, and tickets work together:

### Documentation Hierarchy

```
Ticket #123: "Add multi-language support"
    ↓
ADR-XXX: "Internationalization Architecture"  (docs/adr/)
    ↓ (may create new requirements)
REQ-p00019: "Multi-Language Support"  (spec/prd-diary-app.md)
REQ-d00012: "i18n Implementation"  (spec/dev-app.md)
    ↓ (requirements link to code)
Code: src/i18n/*.ts  (with requirement references in comments)
```

### When to Create Each

| Document Type | Purpose | When to Create | Example |
| --- | --- | --- | --- |
| **Ticket** | Track work to be done | User/stakeholder requests feature or bug fix | "Add multi-language support" |
| **ADR** | Document architectural decision | Significant design choice with trade-offs | "Why we chose i18next over custom solution" |
| **Requirement** | Define what system must do | Feature accepted and needs formal specification | "REQ-p00019: System shall support EN/ES/FR" |
| **Code** | Implement the feature | After ADR and requirements exist | `i18n.service.ts` with req references |

### Workflow Example

1. **Ticket created**: #123 "Add multi-language support"
2. **Team discussion**: Multiple approaches possible (i18next, custom, server-side)
3. **ADR drafted**: ADR-006 documents decision to use i18next library
   - **Context**: Ticket #123, need to support 3 languages
   - **Decision**: Use i18next library for client-side translation
   - **Alternatives**: Custom solution, server-side rendering, Polyglot.js
4. **Requirements created** (if formal spec needed):
   - REQ-p00019: "Multi-Language Support" (what)
   - REQ-d00012: "i18n Implementation using i18next" (how)
5. **Code implemented**:
   ```typescript
   // src/i18n/i18n.service.ts
   // IMPLEMENTS REQUIREMENTS:
   //   REQ-p00019: Multi-Language Support
   //   REQ-d00012: i18n Implementation
   // ARCHITECTURE: See docs/adr/ADR-006-internationalization.md
   ```
6. **Commit message**: `"[Ticket #123] Add multi-language support per ADR-006 (implements REQ-p00019, REQ-d00012)"`

### ADRs Without Requirements

Not every ADR needs formal requirements:

**ADR needs requirements when**:
- ✅ Feature has compliance implications
- ✅ Feature affects external contracts/APIs
- ✅ Decision creates new capabilities users depend on
- ✅ System behavior must be formally validated

**ADR doesn't need requirements when**:
- ✅ Pure implementation detail (internal refactoring)
- ✅ Performance optimization without behavior change
- ✅ Developer tooling or build system choices
- ✅ Technical debt resolution

**Example**: ADR-005 "Database Migration Strategy" documents *how* we manage migrations, but doesn't need formal requirements because it's a development process decision, not a system capability.

## References

- [Documenting Architecture Decisions by Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub Organization](https://adr.github.io/)
- **Requirements format**: `../spec/requirements-format.md`
- **Requirement traceability**: `../spec/README.md` and `CLAUDE.md`

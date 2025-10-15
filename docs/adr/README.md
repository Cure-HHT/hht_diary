# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records (ADRs) documenting significant architectural and design decisions for the Clinical Trial Diary Database.

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
|-----|-------|--------|------|
| [001](./ADR-001-event-sourcing-pattern.md) | Event Sourcing Pattern for Diary Data | Accepted | 2025-10-14 |
| [002](./ADR-002-jsonb-flexible-schema.md) | JSONB for Flexible Diary Schema | Accepted | 2025-10-14 |
| [003](./ADR-003-row-level-security.md) | Row-Level Security for Multi-Tenancy | Accepted | 2025-10-14 |
| [004](./ADR-004-investigator-annotations.md) | Separation of Investigator Annotations | Accepted | 2025-10-14 |

## When to Create an ADR

Create an ADR when making decisions about:
- Database schema design patterns
- Technology choices (frameworks, libraries, platforms)
- Architecture patterns (event sourcing, CQRS, microservices)
- Security models (authentication, authorization, encryption)
- Compliance approaches
- Performance optimization strategies
- Data modeling approaches

## ADR Lifecycle

1. **Proposed**: Initial draft, under discussion
2. **Accepted**: Decision approved and implemented
3. **Deprecated**: Decision no longer recommended but still in use
4. **Superseded**: Replaced by a newer ADR (reference the superseding ADR)

## Contributing

When creating a new ADR:
1. Copy the template structure above
2. Use the next sequential number (ADR-XXX)
3. Write a clear, descriptive title
4. Fill in all sections thoroughly
5. Get review from technical lead
6. Update this index
7. Commit the ADR with the implementing code

## References

- [Documenting Architecture Decisions by Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub Organization](https://adr.github.io/)

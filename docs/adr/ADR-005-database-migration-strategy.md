# ADR-005: Database Migration Strategy

## Status

Accepted

## Context

The Clinical Trial Diary Database requires a formal change control process for schema modifications to satisfy FDA 21 CFR Part 11 compliance requirements. As the system evolves, we need:

1. **Compliance**: Documented change control process for all schema modifications
2. **Traceability**: Clear audit trail of when and why schema changes were made
3. **Reliability**: Ability to safely roll back changes if issues arise
4. **Repeatability**: Consistent deployment process across dev/staging/production environments
5. **Zero-downtime**: Production deployments without service interruptions
6. **Testing**: Verification that schema changes work correctly before production

Without a structured migration strategy, schema changes would be:
- Manual and error-prone
- Difficult to track and audit
- Risky to deploy
- Inconsistent across environments
- Non-compliant with regulatory requirements

## Decision

We will implement a **versioned migration system** with the following characteristics:

### 1. Migration File Structure

```
database/migrations/
├── README.md
├── NNN_description.sql       # Sequential numbered migrations
└── rollback/
    └── NNN_rollback.sql      # Corresponding rollback scripts
```

- **Sequential numbering**: 001, 002, 003... ensures order
- **Descriptive names**: Clearly indicate what each migration does
- **Paired rollbacks**: Every migration has a corresponding rollback

### 2. Migration File Format

Each migration includes:
- Transaction wrapper (BEGIN/COMMIT)
- Documentation (ticket reference, author, purpose)
- The actual schema changes
- Verification logic to confirm success
- Idempotent SQL (safe to run multiple times)

### 3. Migration Process

**Development**:
1. Create migration and rollback files
2. Test locally
3. Code review and approval
4. Merge to main branch

**Staging**:
1. Apply migration to staging database
2. Run full test suite
3. QA approval

**Production**:
1. Create backup
2. Apply migration
3. Verify success
4. Monitor for 24-48 hours

### 4. Compliance Integration

Every migration must satisfy FDA 21 CFR Part 11 change control:
- Change request documented (ticket reference)
- Impact and risk assessment
- Technical and compliance review
- Testing and validation
- Documentation updates
- Post-deployment verification

### 5. Tool Selection

**Current approach**: Manual execution via `psql`
- Simple and transparent
- Full control over execution
- No additional dependencies
- Team already familiar with PostgreSQL

**Future consideration**: Migration tool (Flyway, Liquibase, sqitch)
- Will evaluate when team grows or complexity increases
- Current manual process is adequate for project scale

## Consequences

### Positive

1. **Compliance**: Satisfies FDA 21 CFR Part 11 change control requirements
2. **Safety**: Every change is tested and reversible
3. **Documentation**: Complete history of schema evolution
4. **Consistency**: Same process for all environments
5. **Transparency**: All changes visible in version control
6. **Traceability**: Clear link between tickets and schema changes
7. **Confidence**: Reduced risk of production schema issues
8. **Knowledge sharing**: Migration files serve as documentation

### Negative

1. **Process overhead**: More steps than manual schema changes
2. **Discipline required**: Team must follow process consistently
3. **Learning curve**: New developers must learn migration workflow
4. **Manual execution**: No automated migration runner (yet)
5. **Review bottleneck**: Migrations require technical and compliance review
6. **Testing time**: Must test in multiple environments

### Mitigations

- **Templates**: Provide migration and rollback templates to reduce overhead
- **Documentation**: Clear README and strategy docs to reduce learning curve
- **Automation**: Can add migration tool later if manual process becomes burdensome
- **Review process**: Streamlined review checklist to avoid bottlenecks

## Alternatives Considered

### Alternative 1: Ad-hoc Schema Changes

**Approach**: Make schema changes directly in each environment without versioning

**Rejected because**:
- Non-compliant with FDA 21 CFR Part 11 change control
- No audit trail
- Environments would drift
- No rollback capability
- High risk for production

### Alternative 2: ORM Migrations (e.g., Prisma, TypeORM)

**Approach**: Use application framework's migration system

**Rejected because**:
- Database-first design (not application-first)
- Compliance requires database-level documentation
- Team expertise is in SQL, not ORM tools
- Less transparency for regulatory audits
- Harder to verify compliance

### Alternative 3: Temporal Tables / Database Versioning

**Approach**: Use PostgreSQL temporal tables or database-level versioning

**Rejected because**:
- Overly complex for current needs
- Focuses on data versioning, not schema versioning
- Doesn't solve change control process
- Would still need migration strategy on top

### Alternative 4: Enterprise Migration Tool (Day 1)

**Approach**: Adopt Flyway or Liquibase from the start

**Rejected for now because**:
- Additional dependency and complexity
- Manual process is adequate for current scale
- Team unfamiliar with these tools
- Can add later if needed (migrations are compatible)
- Compliance is met with manual process

## Implementation

The migration strategy is documented in:
- `spec/MIGRATION_STRATEGY.md` - Comprehensive strategy guide
- `database/migrations/README.md` - Quick start for developers
- Migration templates in migration files 001, 002, 003

Key files:
- `database/migrations/001_initial_schema.sql` - Baseline migration
- `database/migrations/002_add_audit_metadata.sql` - Example additive migration
- `database/migrations/003_add_tamper_detection.sql` - Example function/trigger migration
- Corresponding rollback files in `rollback/` directory

## Validation

Migration strategy validates successfully when:
- [ ] All schema changes go through migration files
- [ ] Every migration has working rollback
- [ ] Migrations tested in dev before staging
- [ ] Migrations tested in staging before production
- [ ] Change control documentation complete for each migration
- [ ] No manual schema changes in production
- [ ] Team follows process consistently

## Related Decisions

- **ADR-001**: Event Sourcing Pattern - Migrations must preserve audit trail integrity
- **ADR-003**: Row-Level Security - Migrations must maintain RLS policies
- **TICKET-001**: Audit Metadata - First production migration example
- **TICKET-002**: Tamper Detection - Migration with triggers and functions
- **TICKET-009**: This ADR documents the decision for this ticket

## References

- FDA 21 CFR Part 11 - Electronic Records and Signatures (Section 11.10 - Controls for closed systems)
- `spec/compliance-practices.md` - Lines 289-318 (Change Control)
- `spec/core-practices.md` - Continuous Compliance section
- PostgreSQL Documentation: Schema Management
- [Evolutionary Database Design](https://martinfowler.com/articles/evodb.html) by Martin Fowler

## Review and Approval

**Author**: Database Team
**Technical Review**: Database Architect
**Compliance Review**: Compliance Officer
**Date**: 2025-10-14
**Status**: Accepted

## Change Log

| Date | Change | Author |
| --- | --- | --- |
| 2025-10-14 | Initial ADR created | Claude Code |

---

**Next Review**: 2026-01-14 (Quarterly review cycle)

# ADR-003: Row-Level Security for Multi-Tenancy

**Date**: 2025-10-14
**Deciders**: Development Team, Security Team
**Security Impact**: Critical

## Status

Accepted

---

## Context

The clinical trial diary database serves multiple stakeholders with different access requirements:

1. **Study Participants (USERS)**: Should only see their own diary entries
2. **Investigators**: Should see data for patients at their assigned sites
3. **Analysts**: Should have read-only access to assigned sites
4. **Admins**: May need cross-site access for system management

### Security Requirements

- **Data Isolation**: Users must not access other users' data
- **Site Isolation**: Investigators limited to assigned sites
- **Defense in Depth**: Access control enforced at database level, not just application
- **Audit Trail**: Access attempts logged
- **Compliance**: HIPAA requires access controls for patient data
- **Multi-Tenancy**: Single database serves multiple clinical sites

### Traditional Approach Limitations

**Application-Layer Only**:
```javascript
// Application code filters data
const entries = await db.query(
  "SELECT * FROM diary_entries WHERE patient_id = ?",
  [currentUser.id]
);
```

**Problems**:
- ❌ Developers might forget to add WHERE clause
- ❌ SQL injection could bypass application filters
- ❌ Direct database access (admin tools) bypasses security
- ❌ Difficult to audit and verify completeness
- ❌ Single mistake exposes all data

---

## Decision

We will use **PostgreSQL Row-Level Security (RLS)** to enforce access controls at the database layer.

### Implementation

**1. Enable RLS on All Tables**:
```sql
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE record_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE record_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE investigator_annotations ENABLE ROW LEVEL SECURITY;
-- ... all tables
```

**2. Define Policies Based on User Role**:
```sql
-- Users can only see their own data
CREATE POLICY user_select_own ON record_state
    FOR SELECT
    TO authenticated
    USING (patient_id = current_user_id());

-- Investigators see data at assigned sites
CREATE POLICY investigator_select_site ON record_state
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'INVESTIGATOR'
        AND site_id IN (
            SELECT site_id
            FROM investigator_site_assignments
            WHERE investigator_id = current_user_id()
            AND is_active = true
        )
    );

-- Admins see all data
CREATE POLICY admin_select_all ON record_state
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'ADMIN');
```

**3. Extract User Context from JWT**:
```sql
-- Helper functions extract info from Supabase JWT
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(
        current_setting('request.jwt.claims', true)::json->>'sub',
        current_user
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(
        current_setting('request.jwt.claims', true)::json->>'role',
        'anon'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
```

---

## Consequences

### Positive Consequences

✅ **Defense in Depth**
- Access control enforced at database layer
- Protection even if application has bugs
- Works for direct database access (admin tools, SQL clients)

✅ **Impossible to Bypass**
- Every query automatically filtered by RLS
- Developers cannot accidentally expose data
- SQL injection attacks filtered by RLS

✅ **Consistent Security**
```sql
-- Both queries respect RLS automatically
SELECT * FROM record_state;  -- Filtered by RLS

SELECT * FROM record_state
WHERE site_id = 'site_123';  -- Still filtered by RLS
```

✅ **Audit-Friendly**
- Clear, declarative security policies
- Easy to review and audit
- Policies versioned with schema

✅ **Role-Based**
- Single user identity, multiple roles possible
- Policies adapt to user role automatically
- Supports complex access patterns

✅ **Performance**
- RLS adds minimal overhead
- Uses indexes effectively
- Query planner optimizes with RLS constraints

✅ **Compliance**
- Meets HIPAA access control requirements
- Demonstrates "reasonable safeguards"
- Shows due diligence for auditors

### Negative Consequences

⚠️ **Complexity**
- Policies can become complex
- Debugging RLS issues harder
- Need to understand policy evaluation order

⚠️ **Performance Considerations**
- Subqueries in policies can impact performance
- Complex policies may need optimization
- Need to monitor query plans
- **Mitigation**: Index columns used in policies

⚠️ **Testing Complexity**
- Must test as different roles
- Need to set JWT claims in tests
- Integration tests more complex
- **Mitigation**: Helper functions for test user setup

⚠️ **Bypass for Service Role**
- `service_role` bypasses RLS (by design)
- Must protect service role credentials carefully
- Background jobs need careful design
- **Mitigation**: Document service role usage, strict credential management

⚠️ **Policy Conflicts**
- Multiple policies can interact unexpectedly
- OR'd together for SELECT, AND'd for INSERT/UPDATE
- Need clear policy design
- **Mitigation**: Document policy interaction, test thoroughly

---

## Alternatives Considered

### Alternative 1: Application-Layer Security Only

**Approach**: Filter data in application code

```javascript
// Application layer
function getDiaryEntries(userId) {
  return db.query(
    "SELECT * FROM diary_entries WHERE patient_id = ?",
    [userId]
  );
}
```

**Why Rejected**:
- ❌ Easy to make mistakes
- ❌ No protection for direct DB access
- ❌ Doesn't protect against SQL injection
- ❌ Hard to audit completeness
- ✅ Simpler to implement initially
- ✅ More flexible

**Verdict**: Not secure enough for healthcare data

### Alternative 2: Separate Database Per Site

**Approach**: One database instance per clinical site

**Why Rejected**:
- ❌ Expensive (many databases to maintain)
- ❌ Cross-site queries impossible
- ❌ Harder to maintain consistency
- ❌ Complex deployment and backups
- ❌ Doesn't scale to many sites
- ✅ Perfect data isolation
- ✅ Simple access control

**Verdict**: Over-engineering; RLS provides sufficient isolation

### Alternative 3: View-Based Security

**Approach**: Create views with WHERE clauses, grant access to views only

```sql
CREATE VIEW user_diary_entries AS
SELECT * FROM diary_entries
WHERE patient_id = current_user_id();

GRANT SELECT ON user_diary_entries TO authenticated;
REVOKE SELECT ON diary_entries FROM authenticated;
```

**Why Rejected**:
- ❌ Must create view for every table/role combination
- ❌ Views harder to maintain than policies
- ❌ Less flexible than RLS policies
- ❌ Performance overhead of views
- ✅ Explicit security boundaries
- ✅ Compatible with older PostgreSQL

**Verdict**: RLS is more maintainable and flexible

### Alternative 4: Materialized Security Context

**Approach**: Denormalize security context into every table

```sql
CREATE TABLE diary_entries (
    id UUID PRIMARY KEY,
    patient_id TEXT,
    site_id TEXT,
    allowed_users TEXT[],  -- Array of users who can access
    allowed_roles TEXT[],  -- Array of roles who can access
    -- ... other columns
);
```

**Why Rejected**:
- ❌ Data duplication
- ❌ Hard to keep security context in sync
- ❌ Complex updates when permissions change
- ❌ Bloated tables
- ✅ Simple WHERE clauses
- ✅ Good query performance

**Verdict**: Maintenance burden too high

---

## Implementation Guidelines

### For Developers

**1. Always Test with Different Roles**:
```javascript
// Test helper
async function testAsUser(userId, role, testFn) {
  await db.query(
    "SET request.jwt.claims = ?",
    [JSON.stringify({ sub: userId, role: role })]
  );
  await testFn();
}

// Test
test('users can only see own data', async () => {
  await testAsUser('user_1', 'USER', async () => {
    const entries = await getDiaryEntries();
    expect(entries.every(e => e.patient_id === 'user_1')).toBe(true);
  });
});
```

**2. Explain Query Plans**:
```sql
-- Check that RLS is using indexes
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM record_state
WHERE patient_id = 'user_123';
```

**3. Monitor Policy Performance**:
- Watch for slow queries with RLS
- Index all columns used in policies
- Simplify complex policy subqueries

**4. Document Policy Intent**:
```sql
CREATE POLICY user_select_own ON record_state
    FOR SELECT
    TO authenticated
    USING (patient_id = current_user_id());

COMMENT ON POLICY user_select_own ON record_state IS
  'Users can view their own diary entries only. Enforces patient data privacy.';
```

### Common Patterns

**Pattern 1: User-Owned Data**:
```sql
-- Users access only their own records
USING (patient_id = current_user_id())
```

**Pattern 2: Site-Based Access**:
```sql
-- Investigators access data at assigned sites
USING (
    site_id IN (
        SELECT site_id FROM investigator_site_assignments
        WHERE investigator_id = current_user_id()
        AND is_active = true
    )
)
```

**Pattern 3: Role-Based Access**:
```sql
-- Admins access all data
USING (current_user_role() = 'ADMIN')
```

**Pattern 4: Combined Conditions**:
```sql
-- Multiple policies OR'd together for SELECT
CREATE POLICY user_access ...
    USING (patient_id = current_user_id());

CREATE POLICY investigator_access ...
    USING (current_user_role() = 'INVESTIGATOR' AND ...);
```

---

## Security Verification

### Audit Checklist

- [ ] RLS enabled on all sensitive tables
- [ ] Policies defined for all roles (USER, INVESTIGATOR, ANALYST, ADMIN)
- [ ] Policies tested with actual user scenarios
- [ ] Service role access documented and justified
- [ ] Bypass mechanisms (if any) documented
- [ ] Policy performance acceptable
- [ ] Security review completed

### Testing RLS

```sql
-- Test as different users
BEGIN;
SET request.jwt.claims = '{"sub": "user_1", "role": "USER"}';
SELECT COUNT(*) FROM record_state;  -- Should only see user_1's data
ROLLBACK;

BEGIN;
SET request.jwt.claims = '{"sub": "investigator_1", "role": "INVESTIGATOR"}';
SELECT COUNT(*) FROM record_state;  -- Should see assigned sites only
ROLLBACK;

BEGIN;
SET request.jwt.claims = '{"sub": "admin_1", "role": "ADMIN"}';
SELECT COUNT(*) FROM record_state;  -- Should see all data
ROLLBACK;
```

---

## References

- [PostgreSQL Row-Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Supabase RLS Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [HIPAA Access Controls](https://www.hhs.gov/hipaa/for-professionals/security/laws-regulations/index.html)
- Database implementation: `database/rls_policies.sql`

---

## Related ADRs

- [ADR-001](./ADR-001-event-sourcing-pattern.md) - RLS applies to event log and state tables
- [ADR-004](./ADR-004-investigator-annotations.md) - RLS protects annotations

---

**Review History**:
- 2025-10-14: Accepted by development team and security team

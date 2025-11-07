# Database Security Architecture

> **Purpose**: Document security controls and encryption strategy
>
> **Compliance**: FDA 21 CFR Part 11, HIPAA, GDPR

**Version**: 1.0.0 | **Date**: 2025-10-14

---

## Overview

This database implements a **defense-in-depth** security architecture with multiple layers of protection:

1. **Encryption** (at-rest and in-transit)
2. **Access Controls** (RLS, RBAC)
3. **Audit Trails** (immutable, tamper-evident)
4. **Privacy-by-Design** (data de-identification)
5. **Network Security** (TLS, firewalls)

---

## Encryption

### Encryption at Rest

**Provider**: Supabase (PostgreSQL with transparent data encryption)
**Algorithm**: AES-256
**Key Management**: Automatic rotation managed by Supabase

**What is encrypted**:
- All database tables and indexes
- Backups and snapshots
- Write-ahead logs (WAL)
- Temporary files and sort operations

**Verification**:
```sql
-- Verify encryption is enabled (Supabase admin only)
SHOW ssl;
SHOW data_encryption_version;
```

**Configuration**: Managed by Supabase, no manual configuration required

### Encryption in Transit

**Protocol**: TLS 1.3 / TLS 1.2
**Certificate**: Managed by Supabase with automatic renewal

**Requirements**:
- ✅ All client connections MUST use TLS
- ✅ Certificate validation MUST be enabled
- ✅ Minimum TLS version: 1.2
- ✅ Mobile apps SHOULD implement certificate pinning

**Connection String Example**:
```
postgresql://user:pass@host:5432/db?sslmode=require
```

**Supabase Connection**:
```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://your-project.supabase.co',
  'your-anon-key',
  {
    db: {
      schema: 'public',
    },
    auth: {
      persistSession: true,
    },
    global: {
      headers: { 'x-client-info': 'clinical-trial-diary' },
    },
  }
)
```

All Supabase connections use HTTPS/TLS by default.

---

## Access Controls

### Row-Level Security (RLS)

**Status**: Enabled on all tables

**Enforcement**: PostgreSQL RLS policies filter data based on user JWT claims

**Example Policies**:
```sql
-- Users can only see their own data
CREATE POLICY user_select_own ON record_state
    FOR SELECT TO authenticated
    USING (patient_id = current_user_id());

-- Investigators see data at their assigned sites
CREATE POLICY investigator_select_site ON record_state
    FOR SELECT TO authenticated
    USING (
        current_user_role() = 'INVESTIGATOR'
        AND site_id IN (
            SELECT site_id FROM investigator_site_assignments
            WHERE investigator_id = current_user_id()
            AND is_active = true
        )
    );
```

**Testing RLS**:
```sql
-- Test as different users
SET request.jwt.claims = '{"sub": "user_123", "role": "USER"}';
SELECT COUNT(*) FROM record_state; -- Should only see own data

SET request.jwt.claims = '{"sub": "admin_1", "role": "ADMIN"}';
SELECT COUNT(*) FROM record_state; -- Should see all data
```

# REQ-o00007: Role-Based Permission Configuration

**Level**: Ops | **Implements**: p00005, p00014, p00015 | **Status**: Active

User roles and permissions SHALL be configured in the database and authentication system, enforcing role-based access control at both application and database layers.

Permission configuration SHALL include:
- Role definitions stored in database (USER, INVESTIGATOR, ANALYST, ADMIN)
- Role assignment tracked with audit trail
- JWT claims include user role for database RLS enforcement
- Permission matrix documented and enforced
- Role changes require administrator approval

**Rationale**: Implements RBAC (p00005), least privilege (p00014), and database-level enforcement (p00015) through operational configuration. Roles must be consistently configured across authentication system and database.

**Acceptance Criteria**:
- Roles defined in both Supabase Auth and database tables
- JWT tokens include role claim
- Database RLS policies reference role claim
- Role assignment changes logged in audit trail
- Permission matrix matches specification exactly

*End* *Role-Based Permission Configuration* | **Hash**: 9921779b
---

### Role-Based Access Control (RBAC)

**Roles**:
- `USER` - Study participants (create/edit own diary entries)
- `INVESTIGATOR` - Clinical staff (view/annotate data at assigned sites)
- `ANALYST` - Data analysts (read-only access to assigned sites)
- `ADMIN` - System administrators (full access, logged)

**Role Assignment**:
- Stored in `user_profiles.role`
- Included in JWT claims by Supabase Auth
- Changes logged in `role_change_log` (audit trail)

**Permission Matrix**:

| Action | USER | INVESTIGATOR | ANALYST | ADMIN |
|--------|------|--------------|---------|-------|
| Create own diary entry | ✅ | ❌ | ❌ | ✅ |
| Edit own diary entry | ✅ | ❌ | ❌ | ✅ |
| View own data | ✅ | ❌ | ❌ | ✅ |
| View site data | ❌ | ✅ (assigned sites) | ✅ (assigned sites) | ✅ |
| Add annotations | ❌ | ✅ | ❌ | ✅ |
| Assign users to sites | ❌ | ❌ | ❌ | ✅ |
| Modify roles | ❌ | ❌ | ❌ | ✅ |
| View audit trail | Own | Assigned sites | Assigned sites | ✅ |

---

## Authentication

### Supabase Auth Integration

**Provider**: Supabase Auth (separate from application database)

**Features**:
- Email/password authentication
- OAuth providers (Google, Apple, Microsoft)
- Magic link (passwordless)
- JWT-based sessions
- Multi-factor authentication (2FA)

**Required for Investigators and Admins**:
- ✅ Multi-factor authentication (2FA)
- ✅ Strong password policy (12+ characters, complexity)
- ✅ Session timeout (configurable, default 1 hour)

**Session Management**:
```sql
-- Active sessions tracked in user_sessions table
SELECT * FROM user_sessions
WHERE user_id = current_user_id()
AND is_active = true
AND expires_at > now();
```

### Password Policy

**Requirements**:
- Minimum 12 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character
- No common passwords (dictionary check)
- Password expiry: 90 days (configurable)

**Configured in**: Supabase Auth settings

---

## Audit Trail

### Immutable Audit Log

**Table**: `record_audit`
**Protection**: Rules prevent UPDATE and DELETE operations

```sql
CREATE RULE audit_no_update AS ON UPDATE TO record_audit DO INSTEAD NOTHING;
CREATE RULE audit_no_delete AS ON DELETE TO record_audit DO INSTEAD NOTHING;
```

**What is logged**:
- All data modifications (create, update, delete)
- User identification (user_id, role)
- Timestamps (client and server)
- Change reason (mandatory)
- Device and network information
- Cryptographic signature (tamper detection)

### Tamper Detection

**Implementation**: SHA-256 cryptographic hashing

**Verification**:
```sql
-- Verify a single audit entry
SELECT verify_audit_hash(12345);

-- Generate integrity report
SELECT * FROM generate_integrity_report();

-- Detect tampered records
SELECT * FROM detect_tampered_records();
```

**Automated Checks**: Should be run weekly as part of compliance monitoring

---

## Network Security

### Firewall Rules

**Database Access**:
- Restricted to application servers only
- No direct public database access
- IP whitelisting for admin access
- VPC isolation (if using cloud infrastructure)

**Supabase Configuration**:
- API Gateway handles all requests
- Database not directly exposed to internet
- Rate limiting enabled
- DDoS protection included

### API Security

**Supabase API**:
- All requests authenticated via JWT
- Row-level security enforced
- Rate limiting per client
- Request logging enabled

**Best Practices**:
```javascript
// Always use authenticated client
const { data, error } = await supabase
  .from('record_state')
  .select('*')
  .eq('patient_id', user.id); // RLS ensures user can only see own data
```

---

## Security Monitoring

### Real-Time Monitoring

**Authentication Events**:
```sql
-- Recent failed login attempts
SELECT * FROM auth_audit_log
WHERE event_type = 'LOGIN_FAILED'
AND timestamp > now() - interval '1 hour'
ORDER BY timestamp DESC;

-- Suspicious activity
SELECT * FROM security_alerts
WHERE timestamp > now() - interval '24 hours';
```

**Audit Trail Integrity**:
```sql
-- Check for tampered records (should be run daily)
SELECT * FROM detect_tampered_records(
    now() - interval '7 days',
    now()
);

-- Check for sequence gaps
SELECT * FROM check_audit_sequence_gaps();
```

### Alerting

**Critical Alerts** (immediate notification):
- Failed login attempts > 5 in 15 minutes
- Hash verification failure (tampering detected)
- Audit sequence gap detected
- Unauthorized admin action
- Role change without approval

**Warning Alerts** (daily summary):
- Permission denied attempts
- Session timeout spikes
- Unusual access patterns

**Configuration**: Set up via monitoring platform (e.g., Sentry, Datadog)

---

## Incident Response

### Security Incident Types

1. **Unauthorized Access** - User accessing data outside their permissions
2. **Data Breach** - Unauthorized disclosure of clinical data
3. **Tampering** - Hash verification failures
4. **Insider Threat** - Authorized user misusing access
5. **System Compromise** - Database server compromise

### Response Procedures

**Immediate Actions**:
1. Identify scope of incident (audit logs)
2. Contain threat (revoke access if needed)
3. Document incident details
4. Notify security team
5. Preserve evidence (don't delete audit logs)

**Investigation**:
```sql
-- Identify all actions by user during timeframe
SELECT * FROM record_audit
WHERE created_by = 'suspicious_user_id'
AND server_timestamp BETWEEN '2025-01-01' AND '2025-01-02'
ORDER BY server_timestamp;

-- Check authentication history
SELECT * FROM auth_audit_log
WHERE user_id = 'suspicious_user_id'
ORDER BY timestamp DESC;
```

**Reporting**:
- Security incidents logged in `admin_action_log`
- Regulatory reporting if required (HIPAA breach notification)
- Documentation for post-mortem analysis

---

## Backup and Recovery

### Backup Strategy

**Frequency**:
- Continuous: Write-ahead logs (WAL)
- Hourly: Incremental backups
- Daily: Full database backups
- Weekly: Long-term retention

**Retention**:
- Daily backups: 30 days
- Weekly backups: 1 year
- Annual backups: Permanent (compliance requirement)

**Encryption**: All backups encrypted with AES-256

**Testing**: Monthly restore test to verify backup integrity

### Disaster Recovery

**Recovery Time Objective (RTO)**: < 4 hours
**Recovery Point Objective (RPO)**: < 1 hour

**Procedures**:
1. Restore from most recent backup
2. Replay WAL to latest transaction
3. Verify audit trail integrity
4. Validate tamper detection hashes
5. Resume operations with monitoring

---

## Compliance Certifications

### Current Compliance

- ✅ **FDA 21 CFR Part 11** - Electronic records and signatures
- ✅ **HIPAA** - De-identified data, no PHI stored
- ✅ **GDPR** - Pseudonymization, encryption, right to deletion
- ✅ **SOC 2 Type II** - Via Supabase infrastructure
- ✅ **ISO 27001** - Information security management

### Audit Preparation

**Documentation Required**:
- [ ] This security architecture document
- [ ] Data classification document (`DATA_CLASSIFICATION.md`)
- [ ] Access control policies
- [ ] Incident response procedures
- [ ] Backup and recovery procedures
- [ ] Audit trail integrity reports
- [ ] Penetration test results (annual)
- [ ] Vulnerability scan results (quarterly)

**Audit Evidence**:
```sql
-- Generate compliance report for auditors
SELECT * FROM generate_integrity_report(
    now() - interval '90 days',
    now()
);

-- Authentication compliance
SELECT * FROM auth_audit_report
WHERE timestamp > now() - interval '90 days';
```

---

## Security Hardening Checklist

### Database Configuration

- [x] Encryption at rest enabled (Supabase default)
- [x] TLS 1.2+ enforced for connections
- [x] Row-level security enabled on all tables
- [x] Audit trail immutability enforced
- [x] Cryptographic tamper detection implemented
- [ ] Regular security audits scheduled
- [ ] Vulnerability scanning automated
- [ ] Backup testing monthly
- [ ] Incident response plan documented

### Application Security

- [ ] Certificate pinning in mobile apps
- [ ] Input validation on all user inputs
- [ ] Parameterized queries (no SQL injection)
- [ ] HTTPS enforced (no HTTP)
- [ ] Session timeout configured
- [ ] CSRF protection enabled
- [ ] Rate limiting implemented
- [ ] Security headers configured

### Operational Security

- [ ] Multi-factor authentication for admins
- [ ] Password policy enforced
- [ ] Access reviews quarterly
- [ ] Security training for developers
- [ ] Penetration testing annually
- [ ] Vulnerability scanning quarterly
- [ ] Audit log review weekly
- [ ] Compliance reports monthly

---

## Contact

**Security Issues**: Report to security team immediately
**Compliance Questions**: Contact compliance officer
**Technical Questions**: Contact database administrator

---

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2025-10-14 | Initial security documentation | Development Team |

---

**Document Classification**: Internal Use - Security Documentation
**Review Frequency**: Quarterly or after security incidents
**Owner**: Security Team / Technical Lead

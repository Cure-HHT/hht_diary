# Database Security Architecture

> **Purpose**: Document security controls and encryption strategy
>
> **Compliance**: FDA 21 CFR Part 11, HIPAA, GDPR

**Version**: 2.0.0 | **Date**: 2025-11-24

---

## Overview

This database implements a **defense-in-depth** security architecture with multiple layers of protection:

1. **Encryption** (at-rest and in-transit)
2. **Access Controls** (RLS, RBAC, IAM)
3. **Audit Trails** (immutable, tamper-evident)
4. **Privacy-by-Design** (data de-identification)
5. **Network Security** (TLS, VPC, firewall)

---

## Encryption

### Encryption at Rest

**Provider**: Google Cloud SQL (PostgreSQL with Customer-Managed Encryption Keys)
**Algorithm**: AES-256
**Key Management**: Cloud KMS with automatic rotation (configurable)

**What is encrypted**:
- All database tables and indexes
- Backups and snapshots
- Write-ahead logs (WAL)
- Temporary files and sort operations

**Verification**:
```bash
# Verify encryption is enabled on Cloud SQL instance
gcloud sql instances describe ${INSTANCE_NAME} \
  --format="get(settings.dataDiskEncryptionKey)"
```

**Configuration**: Automatic encryption by default; CMEK optional for enhanced control

### Customer-Managed Encryption Keys (CMEK)

For enhanced compliance, use Cloud KMS for key management:

```bash
# Create KMS keyring
gcloud kms keyrings create clinical-diary-keyring \
  --location=us-central1

# Create encryption key
gcloud kms keys create cloudsql-key \
  --keyring=clinical-diary-keyring \
  --location=us-central1 \
  --purpose=encryption

# Create Cloud SQL instance with CMEK
gcloud sql instances create ${INSTANCE_NAME} \
  --database-version=POSTGRES_15 \
  --disk-encryption-key=projects/${PROJECT_ID}/locations/us-central1/keyRings/clinical-diary-keyring/cryptoKeys/cloudsql-key
```

### Encryption in Transit

**Protocol**: TLS 1.3 / TLS 1.2
**Certificate**: Managed by GCP with automatic renewal

**Requirements**:
- ✅ All client connections MUST use TLS (enforced by Cloud SQL)
- ✅ Certificate validation MUST be enabled
- ✅ Minimum TLS version: 1.2
- ✅ Mobile apps SHOULD implement certificate pinning

**Connection String Example**:
```
postgresql://user:pass@/dbname?host=/cloudsql/project:region:instance
```

**Cloud Run Connection** (automatic TLS via Unix socket):
```dart
// Cloud Run connects via Unix socket - TLS not needed for socket
final conn = await Connection.open(
  Endpoint(
    host: '/cloudsql/${instanceConnectionName}',
    database: 'clinical_diary',
    username: 'app_user',
    password: databasePassword,
  ),
  settings: ConnectionSettings(
    sslMode: SslMode.disable, // Unix socket doesn't use SSL
  ),
);
```

**External Connection** (via Cloud SQL Proxy):
```bash
# Cloud SQL Proxy handles TLS automatically
cloud_sql_proxy -instances=project:region:instance=tcp:5432

# Connect via localhost (proxy handles encryption)
psql -h 127.0.0.1 -U app_user -d clinical_diary
```

---

## Access Controls

### Row-Level Security (RLS)

**Status**: Enabled on all tables

**Enforcement**: PostgreSQL RLS policies filter data based on application-set session variables

**Session Variable Setup** (set by application before queries):
```sql
-- Application sets these variables from authenticated user's JWT claims
SET app.current_user_id = 'user_123';
SET app.current_user_role = 'USER';
SET app.current_site_id = 'site_001';
```

**Example Policies**:
```sql
-- Helper function to get current user ID from session
CREATE OR REPLACE FUNCTION current_user_id() RETURNS TEXT AS $$
  SELECT current_setting('app.current_user_id', true);
$$ LANGUAGE SQL STABLE;

-- Helper function to get current user role
CREATE OR REPLACE FUNCTION current_user_role() RETURNS TEXT AS $$
  SELECT current_setting('app.current_user_role', true);
$$ LANGUAGE SQL STABLE;

-- Users can only see their own data
CREATE POLICY user_select_own ON record_state
    FOR SELECT
    USING (patient_id = current_user_id());

-- Investigators see data at their assigned sites
CREATE POLICY investigator_select_site ON record_state
    FOR SELECT
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
-- Test as different users (via session variables)
SET app.current_user_id = 'user_123';
SET app.current_user_role = 'USER';
SELECT COUNT(*) FROM record_state; -- Should only see own data

SET app.current_user_role = 'ADMIN';
SELECT COUNT(*) FROM record_state; -- Should see all data
```

# REQ-o00007: Role-Based Permission Configuration

**Level**: Ops | **Implements**: p00005, p00014, p00015 | **Status**: Active

User roles and permissions SHALL be configured in the database and authentication system, enforcing role-based access control at both application and database layers.

Permission configuration SHALL include:
- Role definitions stored in database (USER, INVESTIGATOR, ANALYST, ADMIN)
- Role assignment tracked with audit trail
- JWT claims include user role for application-level checks
- Application sets session variables for database RLS enforcement
- Permission matrix documented and enforced
- Role changes require administrator approval

**Rationale**: Implements RBAC (p00005), least privilege (p00014), and database-level enforcement (p00015) through operational configuration. Roles must be consistently configured across Identity Platform and database.

**Acceptance Criteria**:
- Roles defined in both Identity Platform (custom claims) and database tables
- Application extracts role from JWT and sets session variables
- Database RLS policies reference session variables
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
- Included in JWT custom claims via Identity Platform
- Changes logged in `role_change_log` (audit trail)

**Permission Matrix**:

| Action | USER | INVESTIGATOR | ANALYST | ADMIN |
| --- | --- | --- | --- | --- |
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

### Identity Platform Integration

**Provider**: Google Identity Platform (Firebase Auth)

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

**Custom Claims Setup** (Cloud Function):
```javascript
// functions/customClaims/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.addCustomClaims = functions.auth.user().onCreate(async (user) => {
  // Default role for new users
  await admin.auth().setCustomUserClaims(user.uid, {
    role: 'USER',
    sponsorId: process.env.SPONSOR_ID,
  });
});
```

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

**Configured in**: Identity Platform Console > Settings > Password Policy

---

## GCP IAM Security

### Service Account Principles

**Principle of Least Privilege**:
```bash
# Create service account with minimal permissions
gcloud iam service-accounts create clinical-diary-server \
  --display-name="Clinical Diary Server"

# Grant only required roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:clinical-diary-server@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# DO NOT grant roles/owner or roles/editor
```

### IAM Roles for Clinical Diary

| Role | GCP IAM Role | Purpose |
|------|--------------|---------|
| Cloud SQL Access | `roles/cloudsql.client` | Connect to Cloud SQL |
| Secret Access | `roles/secretmanager.secretAccessor` | Read secrets |
| Logging | `roles/logging.logWriter` | Write logs |
| Monitoring | `roles/monitoring.metricWriter` | Write metrics |

### Workload Identity (Recommended)

Instead of service account keys, use Workload Identity for Cloud Run:

```bash
# Enable Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
  clinical-diary-server@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[default/clinical-diary]"

# Deploy Cloud Run with service account
gcloud run deploy clinical-diary \
  --service-account=clinical-diary-server@${PROJECT_ID}.iam.gserviceaccount.com
```

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

**Automated Checks**: Scheduled via Cloud Scheduler + Cloud Functions

---

## Network Security

### VPC Configuration

**Database Access**:
- Cloud SQL uses Private IP within VPC
- No public IP exposed
- VPC Connector for Cloud Run access
- Authorized networks for admin access only

**VPC Setup**:
```bash
# Create VPC Connector for Cloud Run
gcloud compute networks vpc-access connectors create clinical-diary-connector \
  --region=$REGION \
  --subnet=default \
  --min-instances=2 \
  --max-instances=10

# Deploy Cloud Run with VPC Connector
gcloud run deploy clinical-diary \
  --vpc-connector=clinical-diary-connector \
  --vpc-egress=private-ranges-only
```

### Cloud SQL Security

**Network Configuration**:
```bash
# Remove public IP (private IP only)
gcloud sql instances patch ${INSTANCE_NAME} \
  --no-assign-ip

# Authorize specific networks (if needed for admin)
gcloud sql instances patch ${INSTANCE_NAME} \
  --authorized-networks=10.0.0.0/8
```

### API Security

**Cloud Run**:
- All requests authenticated via Identity Platform JWT
- Row-level security enforced at database layer
- Rate limiting via Cloud Armor (optional)
- Request logging via Cloud Logging

**Best Practices**:
```dart
// Verify JWT and set session variables
Future<void> handleRequest(Request request) async {
  // Verify Firebase ID token
  final idToken = request.headers['Authorization']?.replaceFirst('Bearer ', '');
  final decodedToken = await FirebaseAuth.instance.verifyIdToken(idToken);

  // Get user claims
  final userId = decodedToken.uid;
  final role = decodedToken.claims['role'] ?? 'USER';

  // Set session variables for RLS
  await db.execute('''
    SET app.current_user_id = '$userId';
    SET app.current_user_role = '$role';
  ''');

  // Now execute query - RLS automatically filters
  final result = await db.query('SELECT * FROM record_state');
}
```

---

## Security Monitoring

### Cloud Audit Logs

GCP automatically logs all administrative actions:

```bash
# View Cloud SQL admin activity
gcloud logging read 'resource.type="cloudsql_database" AND protoPayload.methodName:"cloudsql"' \
  --limit=50

# View authentication events (Identity Platform)
gcloud logging read 'resource.type="identitytoolkit.googleapis.com/Project"' \
  --limit=50
```

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

**Configuration**: Set up via Cloud Monitoring alert policies

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

**Cloud SQL Automated Backups**:
- Daily automated backups
- Point-in-time recovery (PITR) enabled
- Configurable retention (7-365 days)

**Configuration**:
```bash
# Configure backups
gcloud sql instances patch ${INSTANCE_NAME} \
  --backup-start-time=02:00 \
  --enable-point-in-time-recovery \
  --retained-backups-count=30
```

**Retention**:
- Daily backups: 30 days
- Weekly exports: 1 year (Cloud Storage)
- Annual exports: Permanent (Cloud Storage Coldline)

**Encryption**: All backups encrypted with AES-256

**Testing**: Monthly restore test to verify backup integrity

### Disaster Recovery

**Recovery Time Objective (RTO)**: < 4 hours
**Recovery Point Objective (RPO)**: < 5 minutes (PITR)

**Procedures**:
1. Create new instance from backup or PITR
2. Verify audit trail integrity
3. Validate tamper detection hashes
4. Update connection strings
5. Resume operations with monitoring

---

## Compliance Certifications

### GCP Compliance

- ✅ **FDA 21 CFR Part 11** - Electronic records and signatures
- ✅ **HIPAA** - BAA available, de-identified data, no PHI stored
- ✅ **GDPR** - EU data residency, encryption, right to deletion
- ✅ **SOC 2 Type II** - Native GCP certification
- ✅ **ISO 27001** - Information security management
- ✅ **FedRAMP** - Available for government workloads

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

- [x] Encryption at rest enabled (Cloud SQL default)
- [x] TLS 1.2+ enforced for connections
- [x] Row-level security enabled on all tables
- [x] Audit trail immutability enforced
- [x] Cryptographic tamper detection implemented
- [x] Private IP only (no public access)
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
| --- | --- | --- | --- |
| 1.0.0 | 2025-10-14 | Initial security documentation | Development Team |
| 2.0.0 | 2025-11-24 | Migration to GCP (Cloud SQL, Identity Platform, IAM) | Claude |

---

**Document Classification**: Internal Use - Security Documentation
**Review Frequency**: Quarterly or after security incidents
**Owner**: Security Team / Technical Lead

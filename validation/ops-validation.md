# Validation Execution Procedures

**Version**: 1.0
**Audience**: Operations
**Last Updated**: 2025-10-24
**Status**: Active

> **See**: spec/prd-validation.md for validation requirements overview
> **See**: spec/prd-clinical-trials.md for regulatory compliance context
> **See**: validation/checklist.md for validation package checklist

---

## Purpose

This document provides step-by-step operational procedures for executing system validation (IQ/OQ/PQ) for clinical trial deployments.

**Audience**: Validation engineers, QA personnel, system administrators

---

## Pre-Validation Setup

### Step 1: Establish Validation Environment

**Requirements**:
- Separate from development environment
- Identical configuration to production
- Dedicated database instance
- No development/debugging tools installed
- Controlled access (validation team only)

**Commands**:

```bash
# Verify environment isolation
echo $ENVIRONMENT
# Expected output: "validation" or "staging"

# Check no development tools present
which node --version  # Should show specific production version only
ls -la .git            # Should not exist in deployment

# Verify database connection
psql $DATABASE_URL -c "SELECT current_database(), current_user;"
# Verify it's validation database, not dev or production

# Check Supabase project
supabase status
# Verify project ID matches validation environment
```

**Checklist**:
- [ ] Environment variable verification complete
- [ ] Database is validation-specific (not dev, not production)
- [ ] Application deployed from tagged release (not main branch)
- [ ] SSL certificates installed and verified
- [ ] Backup systems operational
- [ ] Monitoring systems configured
- [ ] Access controls configured (validation team only)

---

### Step 2: Version Control and Configuration Management

**Lock Down Versions**:

```bash
# Document exact versions
echo "=== System Version Manifest ===" > validation-manifest.txt
date >> validation-manifest.txt

# Application version
git rev-parse HEAD >> validation-manifest.txt
git describe --tags >> validation-manifest.txt

# Database version
psql $DATABASE_URL -c "SELECT version();" >> validation-manifest.txt

# Supabase CLI version
supabase --version >> validation-manifest.txt

# Flutter/Dart version (if mobile app)
flutter --version >> validation-manifest.txt

# Node.js version (if web app)
node --version >> validation-manifest.txt

# Store manifest
cat validation-manifest.txt
```

**Configuration Snapshot**:

```bash
# Export environment configuration (sanitize secrets first)
env | grep -E "(SUPABASE|DATABASE|APP_)" | sort > validation-config.txt

# Export database schema
pg_dump $DATABASE_URL --schema-only > validation-schema.sql

# Export RLS policies
psql $DATABASE_URL -c "\d+ record_state" > validation-rls-policies.txt
```

**Checklist**:
- [ ] Version manifest created and stored
- [ ] Configuration snapshot captured
- [ ] Schema export completed
- [ ] All versions match validation protocol specifications

---

### Step 3: Test Data Preparation

**Create Test User Accounts**:

```sql
-- Patient test accounts (5 minimum)
INSERT INTO auth.users (email, role) VALUES
  ('patient-test-001@example.com', 'USER'),
  ('patient-test-002@example.com', 'USER'),
  ('patient-test-003@example.com', 'USER'),
  ('patient-test-004@example.com', 'USER'),
  ('patient-test-005@example.com', 'USER');

-- Investigator test accounts (3 minimum, different sites)
INSERT INTO auth.users (email, role) VALUES
  ('investigator-site-a@example.com', 'INVESTIGATOR'),
  ('investigator-site-b@example.com', 'INVESTIGATOR'),
  ('investigator-site-c@example.com', 'INVESTIGATOR');

-- Analyst test account
INSERT INTO auth.users (email, role) VALUES
  ('analyst-test@example.com', 'ANALYST');

-- Sponsor test account
INSERT INTO auth.users (email, role) VALUES
  ('sponsor-test@example.com', 'SPONSOR');

-- Auditor test account
INSERT INTO auth.users (email, role) VALUES
  ('auditor-test@example.com', 'AUDITOR');

-- Administrator test account
INSERT INTO auth.users (email, role) VALUES
  ('admin-test@example.com', 'ADMIN');
```

**Assign Sites**:

```sql
-- Create test clinical sites
INSERT INTO clinical_sites (site_id, site_name, location) VALUES
  ('SITE-A', 'Test Site Alpha', 'City A'),
  ('SITE-B', 'Test Site Beta', 'City B'),
  ('SITE-C', 'Test Site Gamma', 'City C');

-- Assign investigators to sites
INSERT INTO investigator_site_assignments (user_id, site_id) VALUES
  ((SELECT id FROM auth.users WHERE email = 'investigator-site-a@example.com'), 'SITE-A'),
  ((SELECT id FROM auth.users WHERE email = 'investigator-site-b@example.com'), 'SITE-B'),
  ((SELECT id FROM auth.users WHERE email = 'investigator-site-c@example.com'), 'SITE-C');
```

**Checklist**:
- [ ] All test user accounts created with proper roles
- [ ] Test clinical sites created
- [ ] Site assignments configured
- [ ] Test passwords documented securely
- [ ] Test data clearly marked (not production)

---

## Installation Qualification (IQ) Execution

### IQ-001: Hardware/Infrastructure Verification

**Objective**: Verify hosting environment meets specifications

**Procedure**:

```bash
# Check server resources
free -h                    # Memory
df -h                      # Disk space
nproc                      # CPU cores
uptime                     # System stability

# Expected results documented in IQ protocol
# Example: >= 4GB RAM, >= 50GB disk, >= 2 CPU cores
```

**Evidence**: Screenshot of output, compare to requirements

**Pass/Fail Criteria**: All resources meet or exceed specifications

---

### IQ-002: Database Installation Verification

**Objective**: Verify PostgreSQL and Supabase correctly installed

**Procedure**:

```bash
# Verify PostgreSQL version
psql $DATABASE_URL -c "SELECT version();"
# Expected: PostgreSQL 15.x or later

# Verify required extensions installed
psql $DATABASE_URL -c "SELECT * FROM pg_extension;"
# Expected: pgaudit, pg_stat_statements, uuid-ossp

# Verify pgaudit enabled
psql $DATABASE_URL -c "SHOW pgaudit.log;"
# Expected: 'all' or specific log settings

# Verify RLS enabled on tables
psql $DATABASE_URL -c "
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename IN ('record_state', 'record_audit');
"
# Expected: rowsecurity = true for all tables
```

**Evidence**: SQL query results

**Pass/Fail Criteria**:
- PostgreSQL version >= 15
- All required extensions present
- pgaudit enabled
- RLS enabled on all data tables

---

### IQ-003: Security Configuration Verification

**Objective**: Verify SSL/TLS and encryption configured

**Procedure**:

```bash
# Verify SSL certificate
openssl s_client -connect api.yourdomain.com:443 -servername api.yourdomain.com
# Check: Valid certificate, not expired, correct domain

# Verify database encryption in transit
psql $DATABASE_URL -c "SHOW ssl;"
# Expected: on

# Verify minimum TLS version
psql $DATABASE_URL -c "SHOW ssl_min_protocol_version;"
# Expected: TLSv1.2 or higher

# Test HTTPS redirect
curl -I http://api.yourdomain.com
# Expected: 301/302 redirect to https://
```

**Evidence**: Certificate details, configuration outputs

**Pass/Fail Criteria**:
- Valid SSL certificate
- Database connections use SSL
- TLS 1.2 or higher enforced
- HTTP redirects to HTTPS

---

### IQ-004: Backup System Verification

**Objective**: Verify automated backups configured and functional

**Procedure**:

```bash
# Check Supabase backup configuration
# (Via Supabase dashboard or API)

# Verify backup schedule
# Expected: Daily automated backups

# Test manual backup
pg_dump $DATABASE_URL > test-backup-$(date +%Y%m%d).sql

# Verify backup created and valid
ls -lh test-backup-*.sql
pg_restore --list test-backup-*.sql | head -20

# Cleanup test backup
rm test-backup-*.sql
```

**Evidence**: Backup configuration screenshots, test backup file info

**Pass/Fail Criteria**:
- Automated backups configured
- Manual backup succeeds
- Backup file is valid and readable

---

### IQ-005: Monitoring System Verification

**Objective**: Verify monitoring and alerting configured

**Procedure**:

```bash
# Check monitoring endpoints
curl https://api.yourdomain.com/health
# Expected: 200 OK with health status

# Verify log aggregation
# Check logs are being collected (method depends on setup)
tail -50 /var/log/app.log  # or equivalent

# Test alert system (if configured)
# Trigger test alert and verify receipt
```

**Evidence**: Health check responses, log samples, alert test confirmation

**Pass/Fail Criteria**:
- Health endpoints respond correctly
- Logs being collected
- Alerts functional (if configured)

---

## Operational Qualification (OQ) Execution

### OQ Test Execution Framework

**For Each Test Case**:

1. **Setup**: Prepare test data/accounts
2. **Execute**: Perform test steps exactly as written in protocol
3. **Capture**: Screenshot/log evidence
4. **Compare**: Actual vs. expected results
5. **Document**: Pass/fail status with evidence
6. **Sign**: Tester and reviewer signatures

---

### OQ-AUTH-001: User Authentication - Valid Login

**Objective**: Verify users can log in with valid credentials

**Test Data**:
- Email: patient-test-001@example.com
- Password: (test password)

**Procedure**:
1. Navigate to login page
2. Enter valid email and password
3. Click "Login" button
4. Observe result

**Expected Result**:
- Login succeeds
- User redirected to home page
- Session created
- Audit log entry created with login event

**Verification Commands**:

```sql
-- Check session created
SELECT * FROM auth.sessions
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'patient-test-001@example.com')
ORDER BY created_at DESC LIMIT 1;

-- Check audit log
SELECT * FROM audit_log
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'patient-test-001@example.com')
  AND action = 'LOGIN'
ORDER BY timestamp DESC LIMIT 1;
```

**Evidence Required**:
- Screenshot of successful login
- SQL query results showing session
- Audit log entry screenshot

**Pass Criteria**: Login succeeds, session created, audit logged

---

### OQ-AUTH-002: User Authentication - Invalid Password

**Objective**: Verify failed login with wrong password

**Test Data**:
- Email: patient-test-001@example.com
- Password: wrong-password-123

**Procedure**:
1. Navigate to login page
2. Enter valid email with invalid password
3. Click "Login" button
4. Observe result

**Expected Result**:
- Login fails
- Error message displayed: "Invalid credentials"
- No session created
- Failed login attempt logged

**Verification Commands**:

```sql
-- Verify no new session created
SELECT COUNT(*) FROM auth.sessions
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'patient-test-001@example.com')
  AND created_at > NOW() - INTERVAL '5 minutes';
-- Expected: 0 or unchanged from previous

-- Check failed login logged
SELECT * FROM audit_log
WHERE email = 'patient-test-001@example.com'
  AND action = 'LOGIN_FAILED'
ORDER BY timestamp DESC LIMIT 1;
```

**Evidence Required**:
- Screenshot of error message
- SQL query results confirming no session
- Audit log entry for failed attempt

**Pass Criteria**: Login denied, error shown, attempt logged

---

### OQ-AUTH-003: Two-Factor Authentication

**Objective**: Verify 2FA required for investigator accounts

**Test Data**:
- Email: investigator-site-a@example.com
- Password: (test password)
- 2FA enabled on account

**Procedure**:
1. Login with email and password
2. Observe 2FA prompt
3. Enter valid 2FA code from authenticator app
4. Observe result

**Expected Result**:
- Password accepted, 2FA code requested
- Valid 2FA code grants access
- Session created with 2FA flag
- Login audit entry includes 2FA verification

**Verification Commands**:

```sql
-- Check session has 2FA verified
SELECT user_id, created_at, metadata->>'mfa_verified' as mfa_verified
FROM auth.sessions
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'investigator-site-a@example.com')
ORDER BY created_at DESC LIMIT 1;
-- Expected: mfa_verified = 'true'
```

**Evidence Required**:
- Screenshot of 2FA prompt
- Screenshot of successful login after 2FA
- SQL query showing mfa_verified flag

**Pass Criteria**: 2FA enforced, session marked as MFA-verified

---

### OQ-RBAC-001: Patient Data Isolation

**Objective**: Verify patient can only see own data

**Test Data**:
- Patient A: patient-test-001@example.com
- Patient B: patient-test-002@example.com
- Both have diary entries

**Procedure**:
1. Login as Patient A
2. Navigate to diary entries
3. Attempt to query all entries (API call or SQL)
4. Observe results

**Expected Result**:
- Patient A sees only their own entries
- Patient B's entries not visible
- RLS policy prevents access to other patient data

**Verification Commands**:

```sql
-- Login as patient-test-001 (simulate with SET)
SET request.jwt.claims = '{"sub": "<patient-001-uuid>", "role": "USER"}';

-- Query diary entries
SELECT * FROM record_state;
-- Expected: Only patient-001's entries returned

-- Attempt to query another patient's entry by ID
SELECT * FROM record_state WHERE patient_id = '<patient-002-uuid>';
-- Expected: Empty result (RLS blocks)
```

**Evidence Required**:
- Screenshot of Patient A's diary view
- SQL query results showing only own data
- SQL query results showing empty set for other patient

**Pass Criteria**: RLS prevents cross-patient data access

---

### OQ-RBAC-002: Investigator Site-Scoped Access

**Objective**: Verify investigator can only access assigned site data

**Test Data**:
- Investigator A assigned to SITE-A
- Patient at SITE-A
- Patient at SITE-B

**Procedure**:
1. Login as Investigator A
2. Select SITE-A as active site
3. Query patient list
4. Attempt to query SITE-B patient

**Expected Result**:
- Investigator sees SITE-A patients
- Cannot see SITE-B patients
- RLS policy enforces site scope

**Verification Commands**:

```sql
-- Simulate investigator-site-a session
SET request.jwt.claims = '{"sub": "<investigator-a-uuid>", "role": "INVESTIGATOR"}';

-- Query patients (should see SITE-A only)
SELECT p.patient_id, p.site_id
FROM record_state r
JOIN patients p ON r.patient_id = p.patient_id;
-- Expected: Only SITE-A patients

-- Attempt direct access to SITE-B patient
SELECT * FROM record_state WHERE site_id = 'SITE-B';
-- Expected: Empty result (RLS blocks)
```

**Evidence Required**:
- Screenshot of investigator portal showing SITE-A patients
- SQL query results showing site filtering
- SQL query showing SITE-B access blocked

**Pass Criteria**: Site scoping enforced by RLS

---

### OQ-AUDIT-001: Audit Trail - Create Event

**Objective**: Verify data creation captured in audit trail

**Procedure**:
1. Login as patient-test-001
2. Create new diary entry with specific data
3. Query audit trail

**Expected Result**:
- New entry created in record_state
- Audit event recorded in record_audit
- Audit includes: user_id, timestamp, action='CREATE', data payload

**Verification Commands**:

```sql
-- Find the newly created entry
SELECT * FROM record_state
WHERE patient_id = '<patient-001-uuid>'
ORDER BY created_at DESC LIMIT 1;
-- Note the record_id

-- Check corresponding audit event
SELECT
  event_id,
  record_id,
  user_id,
  action,
  timestamp,
  payload
FROM record_audit
WHERE record_id = '<record-id-from-above>'
  AND action = 'CREATE'
ORDER BY timestamp DESC LIMIT 1;
```

**Evidence Required**:
- Screenshot of diary entry creation in app
- SQL query showing record_state entry
- SQL query showing audit_event with matching data

**Pass Criteria**:
- Audit event exists
- Contains correct user_id, timestamp, action
- Payload matches created data

---

### OQ-AUDIT-002: Audit Trail - Update Event

**Objective**: Verify data modifications captured with reason

**Procedure**:
1. Login as patient-test-001
2. Modify existing diary entry
3. Provide reason for change: "Corrected data entry error"
4. Query audit trail

**Expected Result**:
- record_state shows updated value
- New audit event with action='UPDATE'
- Audit includes reason for change
- Original value preserved in audit history

**Verification Commands**:

```sql
-- Check current state
SELECT * FROM record_state WHERE record_id = '<record-id>';

-- Check audit history (should show CREATE then UPDATE)
SELECT
  event_id,
  action,
  timestamp,
  payload,
  reason
FROM record_audit
WHERE record_id = '<record-id>'
ORDER BY timestamp ASC;
-- Expected: 2 events (CREATE, UPDATE)
```

**Evidence Required**:
- Screenshot of update with reason field
- SQL showing updated record_state
- SQL showing both CREATE and UPDATE events
- Reason field populated in UPDATE event

**Pass Criteria**:
- Update event recorded
- Reason captured
- Original value preserved in history

---

### OQ-AUDIT-003: Audit Trail Immutability

**Objective**: Verify audit events cannot be modified or deleted

**Procedure**:
1. Identify existing audit event
2. Attempt to UPDATE audit record
3. Attempt to DELETE audit record
4. Observe results

**Verification Commands**:

```sql
-- Attempt to modify audit event (should fail)
UPDATE record_audit
SET payload = '{"modified": true}'::jsonb
WHERE event_id = '<some-event-id>';
-- Expected: ERROR - permission denied

-- Attempt to delete audit event (should fail)
DELETE FROM record_audit WHERE event_id = '<some-event-id>';
-- Expected: ERROR - permission denied

-- Verify event unchanged
SELECT * FROM record_audit WHERE event_id = '<some-event-id>';
-- Expected: Original data intact
```

**Evidence Required**:
- SQL error messages from attempted UPDATE
- SQL error messages from attempted DELETE
- SQL query showing original data unchanged

**Pass Criteria**:
- UPDATE blocked (permission denied)
- DELETE blocked (permission denied)
- Audit data remains unchanged

---

### OQ-SYNC-001: Offline Data Capture and Sync

**Objective**: Verify offline entry syncs when reconnected

**Test Data**:
- Mobile app with offline capability
- Patient logged in

**Procedure**:
1. Enable airplane mode on test device
2. Create diary entry while offline
3. Verify entry stored locally
4. Disable airplane mode (restore connectivity)
5. Observe automatic sync
6. Verify entry appears in database

**Expected Result**:
- Entry created locally while offline
- Upon reconnection, entry syncs automatically
- Server receives entry with correct timestamp
- Audit trail shows client-originated creation

**Verification Commands**:

```sql
-- After sync, check for entry
SELECT
  record_id,
  created_at,
  sync_timestamp,
  metadata->>'client_created_at' as client_timestamp
FROM record_state
WHERE patient_id = '<patient-uuid>'
ORDER BY created_at DESC LIMIT 1;

-- Check audit event
SELECT * FROM record_audit
WHERE record_id = '<record-id-from-above>'
  AND action = 'CREATE';
-- Verify timestamp shows original offline creation time
```

**Evidence Required**:
- Screenshot of entry created in offline mode
- Screenshot of sync indicator
- SQL showing entry in database post-sync
- Timestamp verification

**Pass Criteria**:
- Entry created offline
- Syncs automatically when online
- Timestamps preserved correctly

---

### OQ-SECURITY-001: SQL Injection Prevention

**Objective**: Verify system protected against SQL injection

**Procedure**:
1. Attempt SQL injection in login field
2. Attempt SQL injection in data entry field
3. Observe results

**Test Inputs**:
```
Email: admin' OR '1'='1
Password: anything

Diary entry: '; DROP TABLE record_state; --
```

**Expected Result**:
- Injection attempts treated as literal strings
- No SQL execution occurs
- No error messages revealing database structure
- Attempts logged as suspicious activity

**Verification Commands**:

```sql
-- Verify tables still exist
SELECT tablename FROM pg_tables WHERE schemaname = 'public';
-- Expected: All tables present

-- Check for logged injection attempts
SELECT * FROM security_log
WHERE event_type = 'INJECTION_ATTEMPT'
ORDER BY timestamp DESC LIMIT 10;
```

**Evidence Required**:
- Screenshots of injection attempts
- SQL showing tables unaffected
- Security log entries (if logging configured)

**Pass Criteria**:
- Injection attempts fail
- No database damage
- System remains secure

---

### OQ-EXPORT-001: Data Export Functionality

**Objective**: Verify data can be exported for regulatory submission

**Procedure**:
1. Login as sponsor or auditor
2. Request data export for specific date range
3. Download export file
4. Verify export contents

**Expected Result**:
- Export includes all required data
- Audit trail included in export
- Format is standard (CSV, JSON, or XML)
- Export action logged

**Verification Commands**:

```bash
# Inspect export file
unzip data-export-20251024.zip
ls -la

# Check export contains expected files
# Expected: patient_data.csv, audit_trail.csv, metadata.json

# Verify export logged
```

```sql
SELECT * FROM audit_log
WHERE action = 'DATA_EXPORT'
  AND user_id = '<sponsor-uuid>'
ORDER BY timestamp DESC LIMIT 1;
```

**Evidence Required**:
- Screenshot of export request
- Export file contents listing
- Sample data from export (de-identified)
- Audit log entry for export action

**Pass Criteria**:
- Export completes successfully
- Contains required data and audit trail
- Export action logged

---

## Performance Qualification (PQ) Execution

### PQ-PATIENT-001: Complete Patient Workflow

**Objective**: Verify end-to-end patient experience

**Scenario**: New patient enrollment through 7 days of diary entries

**Procedure**:

**Day 0: Enrollment**
1. Patient receives enrollment QR code
2. Scan QR code → app download/open
3. Complete enrollment form
4. Create account and login
5. See sponsor branding

**Days 1-7: Daily Entries**
6. Each day, create diary entry
7. Test offline entry (Day 3)
8. View entry history
9. Modify previous entry with reason (Day 5)

**Day 8: Review**
10. View all entries in calendar view
11. Export personal data

**Expected Results**:
- Enrollment completes in < 5 minutes
- Daily entries save in < 10 seconds
- Offline entry syncs within 30 seconds of reconnection
- Entry modification preserves history
- Calendar view shows all 7 entries
- Personal data export succeeds

**Evidence Required**:
- Screenshots of each major step
- Timing measurements
- Database verification of all 7 entries
- Audit trail showing full history

**Pass Criteria**: Complete workflow succeeds without errors

---

### PQ-INVESTIGATOR-001: Investigator Daily Workflow

**Objective**: Verify investigator portal workflow

**Scenario**: Daily data review and query generation

**Procedure**:
1. Login to investigator portal
2. Select active site
3. Review patient dashboard (list of patients)
4. Select specific patient
5. Review patient diary entries
6. Identify questionable entry
7. Create data query for clarification
8. Add annotation to entry
9. Generate site report
10. Logout

**Expected Results**:
- Dashboard loads in < 5 seconds
- Patient data loads in < 3 seconds
- Query creation succeeds
- Annotation saved with investigator ID
- Report generation completes in < 30 seconds
- All actions logged in audit trail

**Evidence Required**:
- Screenshots of portal workflow
- Performance timing measurements
- SQL verification of query and annotation
- Audit trail verification

**Pass Criteria**: Workflow completes efficiently without errors

---

### PQ-LOAD-001: Concurrent User Load Testing

**Objective**: Verify system performs under realistic load

**Test Configuration**:
- 100 concurrent users
- Mix of patients (80%), investigators (15%), sponsors (5%)
- 30-minute test duration

**Procedure**:

```bash
# Use load testing tool (e.g., k6, JMeter)
k6 run --vus 100 --duration 30m load-test-script.js
```

**Monitoring During Test**:

```bash
# Monitor database connections
psql $DATABASE_URL -c "SELECT count(*) FROM pg_stat_activity;"

# Monitor response times
# Via application monitoring dashboard

# Monitor error rates
tail -f /var/log/app-error.log
```

**Expected Results**:
- Average response time < 2 seconds
- 95th percentile response time < 5 seconds
- Error rate < 0.1%
- Database connections remain stable
- No memory leaks
- No connection pool exhaustion

**Evidence Required**:
- Load test results summary
- Response time graphs
- Error rate metrics
- Database performance metrics
- System resource utilization

**Pass Criteria**:
- All performance targets met
- No system crashes
- No data corruption

---

### PQ-BACKUP-001: Backup and Recovery

**Objective**: Verify data can be recovered from backup

**Procedure**:

**Phase 1: Create Baseline**
1. Capture current database state
2. Document record count
3. Create backup

```bash
# Count records
psql $DATABASE_URL -c "SELECT
  (SELECT COUNT(*) FROM record_state) as record_count,
  (SELECT COUNT(*) FROM record_audit) as audit_count,
  (SELECT COUNT(*) FROM auth.users) as user_count;"

# Create backup
pg_dump $DATABASE_URL > backup-before-recovery-test.sql
```

**Phase 2: Simulate Disaster**
4. Add new test data (known records)
5. Document what was added
6. Simulate data loss scenario

**Phase 3: Recovery**
7. Restore from backup
8. Verify data restored correctly
9. Verify new data not present (proves restore worked)

```bash
# Restore backup
psql $DATABASE_URL < backup-before-recovery-test.sql

# Verify record counts match baseline
psql $DATABASE_URL -c "SELECT
  (SELECT COUNT(*) FROM record_state) as record_count,
  (SELECT COUNT(*) FROM record_audit) as audit_count,
  (SELECT COUNT(*) FROM auth.users) as user_count;"

# Verify test records not present
psql $DATABASE_URL -c "SELECT * FROM record_state WHERE record_id = '<test-record-id>';"
# Expected: Empty (not found)
```

**Expected Results**:
- Backup completes without errors
- Restore completes successfully
- Data matches pre-disaster state
- Post-disaster data not present (confirms restore)
- Audit trail integrity maintained

**Evidence Required**:
- Backup file size and checksum
- Record counts before and after
- SQL verification queries
- Restore log output

**Pass Criteria**:
- Recovery successful
- Data integrity verified
- Audit trail complete

---

## Test Evidence Management

### Evidence Requirements for Each Test

**Required Documentation**:
1. **Test Case ID**: Unique identifier (e.g., OQ-AUTH-001)
2. **Date/Time Executed**: When test was performed
3. **Tester Name**: Who executed the test
4. **Test Description**: What was tested
5. **Expected Result**: What should happen
6. **Actual Result**: What actually happened
7. **Pass/Fail Status**: Test outcome
8. **Evidence**: Screenshots, logs, SQL output
9. **Tester Signature**: Electronic or handwritten
10. **Reviewer Signature**: Independent QA review

### Evidence Storage

**Directory Structure**:
```
validation/
├── evidence/
│   ├── IQ/
│   │   ├── IQ-001-infrastructure/
│   │   │   ├── screenshot-server-resources.png
│   │   │   ├── output-system-info.txt
│   │   │   └── test-results.pdf
│   │   ├── IQ-002-database/
│   │   └── ...
│   ├── OQ/
│   │   ├── OQ-AUTH-001/
│   │   ├── OQ-AUTH-002/
│   │   └── ...
│   └── PQ/
│       ├── PQ-PATIENT-001/
│       └── ...
├── protocols/
│   ├── IQ-protocol.pdf
│   ├── OQ-protocol.pdf
│   └── PQ-protocol.pdf
└── reports/
    ├── IQ-report.pdf
    ├── OQ-report.pdf
    └── PQ-report.pdf
```

**File Naming Convention**:
```
{TEST-ID}_{DESCRIPTION}_{DATE}.{ext}

Examples:
OQ-AUTH-001_valid-login_20251024.png
OQ-AUDIT-003_immutability-test_20251024.sql
PQ-LOAD-001_performance-metrics_20251024.csv
```

---

## Deviation Handling

### When Test Fails

**Immediate Actions**:
1. Document failure details
2. Capture additional evidence (error logs)
3. Do not proceed to next test
4. Notify validation team lead

**Deviation Report**:
- Deviation ID
- Test case that failed
- Description of deviation
- Root cause analysis
- Impact assessment (critical, major, minor)
- Corrective action
- Re-test plan
- Approvals

**Re-testing**:
- Fix issue
- Document fix in deviation report
- Re-execute failed test
- Document re-test results
- Obtain QA approval

---

## Sign-Off Procedures

### Test Case Sign-Off

**After Each Test**:
```
Test Case: OQ-AUTH-001
Status: PASS / FAIL

Executed By: _________________ Date: _______
              (Validation Engineer)

Reviewed By: _________________ Date: _______
              (QA Reviewer)

Approved By: _________________ Date: _______
              (Validation Lead)
```

### Phase Completion Sign-Off

**After IQ/OQ/PQ Complete**:
```
Phase: [IQ / OQ / PQ]
Total Tests: ___
Passed: ___
Failed: ___
Deviations: ___

All deviations resolved: YES / NO
All evidence collected: YES / NO
Traceability verified: YES / NO

Ready for next phase: YES / NO

Validation Lead: _________________ Date: _______

QA Manager: _________________ Date: _______

Sponsor Representative: _________________ Date: _______
```

---

## Validation Completion

### Final Validation Report

**Sections Required**:
1. Executive Summary
2. Validation Scope
3. Test Summary (IQ/OQ/PQ results)
4. Deviations Summary
5. Traceability Matrix
6. Risk Assessment Review
7. Conclusion and Recommendation
8. Approval Signatures

### Final Approval

**Required Signatures**:
- Validation Team Lead
- Quality Assurance Manager
- IT/System Owner
- Sponsor Representative
- Regulatory Affairs (if applicable)

**Upon Approval**:
- System released for production use
- Validation package archived
- Training can commence
- Clinical trial can begin enrollment

---

## Post-Validation Maintenance

### Change Control

**Any System Change Requires**:
1. Change request form
2. Impact assessment
3. Determination: requires re-validation? (partial or full)
4. If re-validation needed: execute affected tests
5. Update validation documentation
6. Approval before deployment

### Periodic Review

**Annual Validation Review**:
- Review deviation log
- Review change control log
- Assess if re-validation needed
- Update risk assessment
- Document review and conclusions

---

## Appendix: Useful SQL Queries

### Verify RLS Enabled

```sql
SELECT
  schemaname,
  tablename,
  rowsecurity as rls_enabled,
  (SELECT COUNT(*)
   FROM pg_policies
   WHERE schemaname = pt.schemaname
   AND tablename = pt.tablename) as policy_count
FROM pg_tables pt
WHERE schemaname = 'public'
ORDER BY tablename;
```

### Check Audit Trail Completeness

```sql
-- Compare record_state to record_audit
SELECT
  (SELECT COUNT(*) FROM record_state) as current_records,
  (SELECT COUNT(DISTINCT record_id) FROM record_audit) as audited_records,
  (SELECT COUNT(*) FROM record_audit WHERE action = 'CREATE') as create_events,
  (SELECT COUNT(*) FROM record_audit WHERE action = 'UPDATE') as update_events;
```

### Verify User Roles

```sql
SELECT
  email,
  role,
  created_at,
  last_sign_in_at
FROM auth.users
WHERE email LIKE '%test%'
ORDER BY role, email;
```

### Check Session Activity

```sql
SELECT
  u.email,
  u.role,
  s.created_at,
  s.expires_at,
  CASE
    WHEN s.expires_at > NOW() THEN 'Active'
    ELSE 'Expired'
  END as status
FROM auth.sessions s
JOIN auth.users u ON s.user_id = u.id
ORDER BY s.created_at DESC
LIMIT 20;
```

---

## References

- **Validation Requirements**: spec/prd-validation.md
- **Validation Checklist**: validation/checklist.md
- **Vendor Evaluation**: validation/vendor-scorecard.md
- **Regulatory Context**: spec/prd-clinical-trials.md

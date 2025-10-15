# Logging Strategy

## Overview

This system implements **TWO separate and distinct logging systems** that must never be confused:

1. **Audit Trail** (Compliance & Data Integrity)
2. **Operational Logging** (Debugging & Performance)

**CRITICAL**: These systems serve different purposes, have different retention policies, and contain different types of information. Never log operational debugging information in the audit trail, and never log PII/PHI in operational logs.

---

## Audit Trail (Compliance)

### Purpose
- **Regulatory compliance** (FDA 21 CFR Part 11, HIPAA)
- **Data integrity verification** and forensic investigation
- **Legal evidence** for regulatory inspections
- **Complete change history** for all clinical data

### Implementation
- **Storage**: PostgreSQL `record_audit` table
- **Retention**: **Permanent** (minimum 7 years for FDA compliance)
- **Immutability**: Enforced by database rules (no updates/deletes)
- **Format**: Structured database records with cryptographic hashes

### What to Log (✅)
✅ All data create/update/delete operations
✅ User identification and role
✅ Timestamps (both client and server)
✅ Change reason (required field)
✅ Device and IP information
✅ Session identifiers
✅ Cryptographic signatures (tamper detection)
✅ Parent audit references (change chains)

### What NOT to Log (❌)
❌ System debugging information
❌ Performance metrics
❌ Transient application errors
❌ Cache operations
❌ API request/response details
❌ Stack traces

### Data Structure
```sql
record_audit:
- audit_id (sequence number)
- event_uuid (event identifier)
- patient_id (de-identified)
- site_id (clinical site)
- operation (USER_CREATE, USER_UPDATE, etc.)
- data (JSONB - the actual change)
- created_by (user ID)
- role (USER, INVESTIGATOR, ANALYST, ADMIN)
- client_timestamp, server_timestamp
- change_reason (required - why was this changed)
- device_info, ip_address, session_id
- signature_hash (SHA-256 tamper detection)
- parent_audit_id (change chain)
```

### Access Pattern
```sql
-- Query audit history for an event
SELECT * FROM record_audit
WHERE event_uuid = '...'
ORDER BY audit_id;

-- Verify audit chain integrity
SELECT * FROM validate_audit_chain('event-uuid');

-- Check ALCOA+ compliance
SELECT * FROM validate_alcoa_compliance(audit_id);
```

---

## Operational Logging (Debugging)

### Purpose
- **Troubleshooting** and debugging application issues
- **Performance monitoring** and optimization
- **System health monitoring** and alerting
- **Error tracking** and resolution
- **Usage analytics** (non-compliance)

### Implementation
- **Storage**: Application-layer logging service (NOT database)
  - Options: CloudWatch, Datadog, Elastic Stack, Grafana Loki
- **Retention**: 30-90 days (configurable based on needs)
- **Format**: Structured JSON with correlation IDs
- **Levels**: DEBUG, INFO, WARN, ERROR, FATAL

### What to Log (✅)
✅ System startup/shutdown events
✅ API request/response times
✅ Database query performance
✅ Error stack traces
✅ Cache hits/misses
✅ External service calls
✅ Authentication attempts (success/failure)
✅ Rate limit hits
✅ Background job execution
✅ Configuration changes

### What NOT to Log (❌)
❌ **Passwords** or credentials
❌ **PII** (names, emails, addresses in plain text)
❌ **PHI** (health information, clinical data)
❌ **Complete audit trail data** (use audit table instead)
❌ **API keys** or tokens
❌ **Session tokens** or JWTs
❌ **Encryption keys**
❌ **Credit card numbers** or financial data

### Log Levels

**DEBUG** (Development only):
- Detailed diagnostic information
- Variable values, execution paths
- Never enabled in production

**INFO** (Normal operations):
- System startup/shutdown
- User login (user ID only, not credentials)
- Successful operations
- Background jobs completed

**WARN** (Unexpected but handled):
- Deprecated API usage
- Approaching rate limits
- Retry attempts
- Configuration issues

**ERROR** (Operation failures):
- Failed API requests
- Database connection issues
- Invalid user input
- External service failures

**FATAL** (System failures):
- Database unavailable
- Critical service dependencies down
- Out of memory errors
- Unrecoverable errors

### Structured Format

```json
{
  "timestamp": "2025-10-15T14:23:45.123Z",
  "level": "INFO",
  "component": "api.diary",
  "correlation_id": "req_7f3d9a8b",
  "user_id": "user_123",
  "user_role": "INVESTIGATOR",
  "message": "Diary entry created successfully",
  "operation": "create_diary_entry",
  "duration_ms": 45,
  "context": {
    "site_id": "site_001",
    "event_type": "USER_CREATE",
    "conflicts_detected": 0
  }
}
```

### Correlation IDs

Use correlation IDs to track requests across services:

```javascript
// Generate correlation ID per request
const correlationId = `req_${uuidv4()}`;

// Include in all logs for this request
logger.info({
  correlation_id: correlationId,
  message: "Processing diary entry",
  // ...
});

// Pass to audit trail in metadata
await insertAudit({
  // ... audit fields
  metadata: { correlation_id: correlationId }
});
```

This allows linking operational logs to audit trail entries for investigation.

---

## Separation of Concerns

| Aspect | Audit Trail | Operational Logs |
|--------|-------------|------------------|
| **Purpose** | Compliance, legal evidence | Debugging, monitoring |
| **Storage** | PostgreSQL database | Log aggregation service |
| **Retention** | 7+ years (permanent) | 30-90 days |
| **Immutable** | Yes (enforced by DB) | No (rotated out) |
| **Contains PII/PHI** | Yes (de-identified) | **NO** (never) |
| **Query Method** | SQL | Log search tool |
| **Audience** | Regulators, auditors, compliance | Developers, operations |
| **Format** | Database records | Structured JSON |
| **Compliance** | FDA, HIPAA, GDPR | Internal use only |
| **Encryption** | Database encryption | Transport encryption only |

---

## Examples

### ✅ CORRECT: Audit Trail Usage

```sql
-- Recording a patient diary entry
INSERT INTO record_audit (
    event_uuid,
    patient_id,
    site_id,
    operation,
    data,
    created_by,
    role,
    client_timestamp,
    change_reason,
    device_info,
    ip_address,
    session_id
) VALUES (
    gen_random_uuid(),
    'patient_001',
    'site_001',
    'USER_CREATE',
    '{"symptoms": ["headache", "nausea"], "severity": 7}'::jsonb,
    'user_123',
    'USER',
    now(),
    'Daily symptom log entry',
    '{"device": "iPhone", "os": "iOS 17", "app_version": "1.2.3"}'::jsonb,
    '192.168.1.100'::inet,
    'sess_abc123'
);
```

### ✅ CORRECT: Operational Logging

```javascript
// Logging API request
logger.info({
  correlation_id: "req_abc123",
  component: "api.diary",
  user_id: "user_123",  // ID only, not PII
  user_role: "USER",
  operation: "create_entry",
  duration_ms: 45,
  status: "success",
  message: "Diary entry created"
});

// Logging error
logger.error({
  correlation_id: "req_abc123",
  component: "api.sync",
  user_id: "user_123",
  operation: "sync_offline_data",
  error_type: "ConflictDetected",
  error_message: "Multiple devices modified same entry",
  stack: error.stack,
  message: "Conflict resolution required"
});
```

### ❌ INCORRECT: Don't Mix These Up

```javascript
// ❌ WRONG: Operational debug in audit trail
INSERT INTO record_audit (..., change_reason)
VALUES (..., 'API request took 450ms, retried twice');
// This is operational info, not a compliance reason

// ❌ WRONG: PII in operational logs
logger.info({
  message: "User logged in",
  email: "john.doe@example.com",  // ❌ PII
  full_name: "John Doe",           // ❌ PII
  patient_symptoms: ["headache"]   // ❌ PHI
});
// Use user_id instead, not email or name

// ❌ WRONG: Complete data payloads in logs
logger.debug({
  message: "Received data",
  payload: req.body  // ❌ May contain PHI/PII
});
// Log metadata only, not actual data
```

---

## Application Layer Responsibilities

### Backend API

1. **Audit Trail**:
   - Capture all data modifications
   - Populate all required fields
   - Never allow bypass of audit trail
   - Validate change_reason is meaningful

2. **Operational Logging**:
   - Generate correlation IDs
   - Log request/response times
   - Never log PII/PHI
   - Use structured logging

### Mobile App

1. **Audit Trail**:
   - Generate event_uuid client-side
   - Capture client_timestamp accurately
   - Include device_info
   - Queue audit entries for offline sync

2. **Operational Logging**:
   - Log app crashes and errors
   - Track sync performance
   - Never log patient data locally
   - Send anonymized analytics only

---

## Compliance Implications

### FDA 21 CFR Part 11

**Audit Trail Requirements**:
- ✅ 11.10(e): Generate audit trails
- ✅ 11.10(e)(1): Date/time stamps
- ✅ 11.10(e)(2): Operator identification
- ✅ 11.10(e)(3): Action taken

**Operational Logs**: Not subject to Part 11 (not compliance records)

### HIPAA

**Audit Trail**:
- De-identified data (not PHI)
- Encrypted at rest and in transit
- Access controls enforced
- 7+ year retention

**Operational Logs**:
- **MUST NOT contain PHI**
- Can be deleted after 90 days
- Used for security monitoring only

### GDPR

**Audit Trail**:
- De-identified data (not personal data)
- Retention justified by compliance needs
- Access restricted

**Operational Logs**:
- Minimize personal data
- Short retention (30-90 days)
- Include in privacy impact assessment

---

## Monitoring & Alerting

### Audit Trail Monitoring

```sql
-- Daily compliance check
SELECT * FROM generate_compliance_report(
    now() - interval '1 day',
    now()
);

-- Alert if missing metadata
SELECT COUNT(*) FROM record_audit
WHERE created_at > now() - interval '1 hour'
AND (change_reason IS NULL OR signature_hash IS NULL);
-- Alert if > 0
```

### Operational Log Monitoring

```javascript
// Alert on error rate
if (errorRate > 1% over 5min) {
  alert('High error rate detected');
}

// Alert on slow API responses
if (p95ResponseTime > 1000ms) {
  alert('Slow API performance');
}

// Alert on failed authentication
if (failedLogins > 5 for same IP) {
  alert('Possible brute force attack');
}
```

---

## Testing

### Audit Trail Tests

```sql
-- Test: Audit entries are immutable
BEGIN;
INSERT INTO record_audit (...) VALUES (...);
UPDATE record_audit SET data = '{}' WHERE audit_id = 1;
-- Should fail (rule prevents updates)
ROLLBACK;

-- Test: Required fields enforced
INSERT INTO record_audit (...) VALUES (...); -- Missing change_reason
-- Should fail with constraint violation
```

### Operational Logging Tests

```javascript
// Test: PII not logged
const result = captureLog(() => {
  logger.info({ user_id: "123", name: "John" });
});
assert(!result.includes("John"));

// Test: Correlation IDs propagate
const correlationId = generateCorrelationId();
await processRequest(correlationId);
const logs = await queryLogs({ correlation_id: correlationId });
assert(logs.length > 0);
```

---

## Team Training

### For Developers

1. **Always ask**: Is this compliance data or operational data?
2. **Audit trail**: Use for all data changes only
3. **Operational logs**: Use for everything else
4. **Never**: Log passwords, PHI, or complete data payloads
5. **Always**: Use correlation IDs to link logs

### For Operations

1. **Audit trail**: Query via SQL, retain permanently
2. **Operational logs**: Use log aggregation tools, rotate after 90 days
3. **Monitoring**: Set up alerts for both systems
4. **Incidents**: Use correlation IDs to trace requests

### For Compliance

1. **Audit trail**: This is your compliance record
2. **Operational logs**: Not for regulatory inspection
3. **Reports**: Generate from audit trail only
4. **Validation**: Verify audit trail completeness regularly

---

## Summary

| What are you logging? | Use This |
|----------------------|----------|
| User created/updated/deleted data | **Audit Trail** |
| API request took 200ms | **Operational Log** |
| Authentication succeeded | **Both** (different details) |
| Database query was slow | **Operational Log** |
| Change reason: "Correcting typo" | **Audit Trail** |
| Stack trace from exception | **Operational Log** |
| Cryptographic hash verification | **Audit Trail** |
| Cache miss | **Operational Log** |
| Regulatory inspector request | **Audit Trail** |
| Developer debugging | **Operational Log** |

---

## References

- **Audit Trail Implementation**: `database/schema.sql` (record_audit table)
- **Compliance Requirements**: `spec/compliance-practices.md:11-20, 383-501`
- **ALCOA+ Principles**: `spec/compliance-practices.md:120-167`
- **Authentication Logging**: `database/auth_audit.sql`

---

**Version**: 1.0
**Last Updated**: 2025-10-15
**Status**: Design Stage
**Review Required**: Technical Lead, Compliance Officer

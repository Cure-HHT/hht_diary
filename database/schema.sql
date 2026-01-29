-- =====================================================
-- Clinical Trial Diary Database Schema
-- Target: Supabase (PostgreSQL 15+)
-- Compliance: FDA 21 CFR Part 11, HIPAA, GDPR
-- Version: 1.0
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00003: Separate Database Per Sponsor
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
--   REQ-p00013: Complete Change History
--   REQ-p00016: Separation of Identity and Clinical Data
--   REQ-p00017: Data Encryption
--   REQ-p00018: Multi-Site Support Per Sponsor
--   REQ-p00035: Patient Data Isolation
--   REQ-p00036: Investigator Site-Scoped Access
--   REQ-p00037: Investigator Annotation Restrictions
--   REQ-p00022: Analyst Read-Only Site-Scoped Access
--   REQ-p00023: Sponsor Global Read Access
--   REQ-p00038: Auditor Compliance Access
--   REQ-p00039: Administrator Break-Glass Access
--   REQ-p00040: Event Sourcing State Protection
--   REQ-o00004: Database Schema Deployment
--   REQ-o00011: Multi-Site Data Configuration Per Sponsor
--   REQ-o00020: Patient Data Isolation Policy Deployment
--   REQ-o00021: Investigator Site-Scoped Access Policy Deployment
--   REQ-o00022: Investigator Annotation Access Policy Deployment
--   REQ-o00023: Analyst Read-Only Access Policy Deployment
--   REQ-o00024: Sponsor Global Access Policy Deployment
--   REQ-o00025: Auditor Compliance Access Policy Deployment
--   REQ-o00026: Administrator Access Policy Deployment
--   REQ-o00027: Event Sourcing State Protection Policy Deployment
--   REQ-d00011: Multi-Site Schema Implementation
--   REQ-d00019: Patient Data Isolation RLS Implementation
--   REQ-d00020: Investigator Site-Scoped Access RLS Implementation
--   REQ-d00021: Investigator Annotation RLS Implementation
--   REQ-d00022: Analyst Read-Only RLS Implementation
--   REQ-d00023: Sponsor Global Access RLS Implementation
--   REQ-d00024: Auditor Compliance Access RLS Implementation
--   REQ-d00025: Administrator Break-Glass RLS Implementation
--   REQ-d00026: Event Sourcing State Protection Implementation
--
-- MULTI-SPONSOR ARCHITECTURE:
--   This schema is deployed ONCE PER SPONSOR in separate Supabase instances.
--   Each sponsor operates an independent database with their own sites table.
--   Multi-sponsor isolation achieved via separate Supabase projects (REQ-p00003),
--   not database-level separation.
--
--   Within each sponsor's database:
--   - Sites table contains that sponsor's clinical trial sites (multi-site support)
--   - All data scoped to sponsor via infrastructure isolation
--   - RLS policies enforce site-level access control within the sponsor
--
-- DATA PRIVACY ARCHITECTURE:
-- This database implements privacy-by-design with de-identified clinical data.
-- Patient identity is managed separately by Supabase Auth.
-- No PHI (Protected Health Information) or PII (Personally Identifiable Information)
-- is stored in this database.
--
-- ENCRYPTION STRATEGY:
-- - At Rest: AES-256 encryption (Supabase default, entire database)
-- - In Transit: TLS 1.3/1.2 (all connections)
-- - Field-Level: NOT REQUIRED (data is de-identified, see DATA_CLASSIFICATION.md)
-- - Key Management: Automatic rotation via Supabase infrastructure
--
-- DATA CLASSIFICATION:
-- - Patient IDs: De-identified study participant IDs (not real names)
-- - Diary Data: Clinical observations (no identifying information)
-- - Site Info: Business contact information (not personal health data)
-- - Audit Trail: Complete change history for compliance
--
-- SENSITIVE FIELDS (Business Information Only):
-- - sites.contact_info: Business contact information for clinical sites
-- - sites.address: Business addresses for clinical sites
-- - user_profiles.email: Professional email addresses
--
-- NO PHI/PII STORED:
-- This database does NOT contain:
-- ❌ Patient real names
-- ❌ Social Security Numbers
-- ❌ Dates of birth
-- ❌ Medical record numbers
-- ❌ Home addresses or personal contact information
-- ❌ Re-identification keys
--
-- See spec/DATA_CLASSIFICATION.md for complete privacy architecture
-- See spec/SECURITY.md for security controls and compliance details
--
-- =====================================================
-- EVENT STORE vs OPERATIONAL LOGGING
-- =====================================================
--
-- This system uses TWO SEPARATE logging systems. Never confuse them.
--
-- EVENT STORE (Event Sourcing + Compliance Audit Trail):
--   Purpose: Source of truth for data + regulatory compliance + data integrity
--   Table: record_audit (event store for Event Sourcing pattern)
--   Retention: PERMANENT (7+ years minimum for FDA compliance)
--   Content: All data modifications as immutable events with full metadata
--   Immutability: Enforced by database rules (no updates/deletes allowed)
--   Audience: Application (event replay), regulators, auditors, compliance officers
--   Pattern: Event Sourcing - all changes captured as events, state derived
--
-- OPERATIONAL LOGGING (Debugging & Performance):
--   Purpose: System monitoring, troubleshooting, performance analysis
--   Location: Application-layer logging system (NOT this database)
--   Retention: 30-90 days (configurable, rotated out)
--   Content: System events, errors, performance metrics, API calls
--   Format: Structured JSON logs with correlation IDs
--   Audience: Developers, operations team
--
-- CRITICAL RULES:
-- ❌ NEVER log operational/debugging info in event store (change_reason field)
-- ❌ NEVER log PII/PHI in operational logs (use user IDs only)
-- ❌ NEVER use event store for debugging (query performance, error tracking)
-- ❌ NEVER store operational logs in this database (use log aggregation service)
-- ✅ ALWAYS write data changes to event store (record_audit), never directly to read model
--
-- See spec/LOGGING_STRATEGY.md for complete documentation
--
-- =====================================================

-- Enable required extensions
-- Set timeouts for safety during extension creation
SET statement_timeout = '30s';
SET lock_timeout = '10s';
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
RESET statement_timeout;
RESET lock_timeout;

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Sites Table
-- Stores clinical trial site information synced from EDC (RAVE)
CREATE TABLE sites (
    site_id TEXT PRIMARY KEY,
    site_name TEXT NOT NULL,
    site_number TEXT NOT NULL UNIQUE,
    address JSONB,
    contact_info JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb,
    -- EDC sync tracking
    edc_oid TEXT,  -- Original OID from RAVE EDC
    edc_synced_at TIMESTAMPTZ  -- Last sync from EDC
);

COMMENT ON TABLE sites IS 'Clinical trial site information synced from EDC';
COMMENT ON COLUMN sites.site_id IS 'Unique site identifier (typically matches EDC OID)';
COMMENT ON COLUMN sites.metadata IS 'Additional site-specific configuration';
COMMENT ON COLUMN sites.edc_oid IS 'Original OID from RAVE EDC system';
COMMENT ON COLUMN sites.edc_synced_at IS 'Timestamp of last sync from EDC';

-- =====================================================
-- PATIENTS TABLE (REQ-CAL-p00063, REQ-CAL-p00073)
-- =====================================================
-- Stores patient (subject) records synced from EDC (RAVE)
-- One-way sync: portal reads from EDC, does not write back

-- Mobile linking status enum (REQ-CAL-p00073)
CREATE TYPE mobile_linking_status AS ENUM (
    'not_connected',
    'linking_in_progress',
    'connected',
    'disconnected'
);

CREATE TABLE patients (
    patient_id TEXT PRIMARY KEY,
    site_id TEXT NOT NULL REFERENCES sites(site_id),
    edc_subject_key TEXT NOT NULL,
    mobile_linking_status mobile_linking_status NOT NULL DEFAULT 'not_connected',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    edc_synced_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_patients_site_id ON patients(site_id);
CREATE INDEX idx_patients_linking_status ON patients(mobile_linking_status);
CREATE INDEX idx_patients_edc_synced_at ON patients(edc_synced_at);

COMMENT ON TABLE patients IS 'Patient (subject) records synced from EDC (REQ-CAL-p00063). One-way sync from RAVE.';
COMMENT ON COLUMN patients.patient_id IS 'RAVE SubjectKey (e.g., "840-001-001") used as primary identifier';
COMMENT ON COLUMN patients.site_id IS 'FK to sites table, derived from SiteRef.LocationOID in RAVE';
COMMENT ON COLUMN patients.edc_subject_key IS 'Original SubjectKey from RAVE EDC (same as patient_id, kept for traceability)';
COMMENT ON COLUMN patients.mobile_linking_status IS 'Patient mobile app linking status (REQ-CAL-p00073)';
COMMENT ON COLUMN patients.edc_synced_at IS 'Timestamp of last sync from EDC';
COMMENT ON COLUMN patients.metadata IS 'Additional patient metadata from EDC';

-- =====================================================
-- PATIENT LINKING CODES (REQ-p70007, REQ-d00078, REQ-d00079)
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p70007: Linking Code Lifecycle Management
--   REQ-d00078: Linking Code Validation
--   REQ-d00079: Linking Code Pattern Matching
--   REQ-CAL-p00049: Mobile Linking Codes
--
-- Stores time-limited linking codes for patient mobile app enrollment
-- Codes are displayed once at generation (stored plaintext) and hashed for secure validation

CREATE TABLE patient_linking_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    code TEXT NOT NULL UNIQUE,              -- Full 10-char code (2-char prefix + 8 random)
    code_hash TEXT NOT NULL,                -- SHA-256 hash for secure validation lookup
    generated_by UUID NOT NULL REFERENCES portal_users(id),
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,        -- 72-hour expiration
    used_at TIMESTAMPTZ,                    -- NULL until code is validated by mobile app
    used_by_user_id TEXT REFERENCES app_users(user_id), -- App user who validated the code
    used_by_app_uuid TEXT,                  -- App/device UUID that validated the code
    revoked_at TIMESTAMPTZ,                 -- If manually revoked before use
    revoked_by UUID REFERENCES portal_users(id),
    revoke_reason TEXT,
    ip_address INET,                        -- IP address of generator (audit)
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_patient_linking_patient ON patient_linking_codes(patient_id);
CREATE INDEX idx_patient_linking_code_hash ON patient_linking_codes(code_hash);
CREATE INDEX idx_patient_linking_user ON patient_linking_codes(used_by_user_id)
    WHERE used_by_user_id IS NOT NULL;
CREATE INDEX idx_patient_linking_expires ON patient_linking_codes(expires_at)
    WHERE used_at IS NULL AND revoked_at IS NULL;
CREATE INDEX idx_patient_linking_cleanup ON patient_linking_codes(generated_at)
    WHERE used_at IS NOT NULL OR revoked_at IS NOT NULL;

ALTER TABLE patient_linking_codes ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE patient_linking_codes IS 'Time-limited linking codes for patient mobile app enrollment (REQ-p70007)';
COMMENT ON COLUMN patient_linking_codes.code IS '10-character code: 2-char sponsor prefix + 8-char random (REQ-d00079)';
COMMENT ON COLUMN patient_linking_codes.code_hash IS 'SHA-256 hash for secure validation from mobile app';
COMMENT ON COLUMN patient_linking_codes.expires_at IS '72-hour expiration from generation';
COMMENT ON COLUMN patient_linking_codes.used_at IS 'Timestamp when code was validated - codes are single-use';
COMMENT ON COLUMN patient_linking_codes.used_by_user_id IS 'App user (patient) who validated the code - establishes patient-app link';
COMMENT ON COLUMN patient_linking_codes.used_by_app_uuid IS 'Mobile app/device UUID that validated the code';
COMMENT ON COLUMN patient_linking_codes.revoked_at IS 'Manual revocation timestamp (e.g., patient disconnect)';

-- =====================================================
-- EDC SYNC LOG (REQ-CAL-p00010, REQ-CAL-p00011)
-- =====================================================
-- Tracks all synchronization events from EDC systems
-- Provides audit trail for compliance and debugging

CREATE TABLE edc_sync_log (
    sync_id BIGSERIAL PRIMARY KEY,
    sync_timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_system TEXT NOT NULL CHECK (source_system IN ('RAVE', 'MEDIDATA', 'OTHER')),
    operation TEXT NOT NULL CHECK (operation IN ('SITES_SYNC', 'PATIENTS_SYNC', 'METADATA_SYNC', 'FULL_SYNC')),
    sites_created INTEGER NOT NULL DEFAULT 0,
    sites_updated INTEGER NOT NULL DEFAULT 0,
    sites_deactivated INTEGER NOT NULL DEFAULT 0,
    content_hash TEXT NOT NULL,
    chain_hash TEXT,  -- Chained hash for tamper-evident audit trail (computed by trigger)
    duration_ms INTEGER,
    success BOOLEAN NOT NULL DEFAULT true,
    error_message TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Index for querying by timestamp and success status
CREATE INDEX idx_edc_sync_log_timestamp ON edc_sync_log(sync_timestamp DESC);
CREATE INDEX idx_edc_sync_log_source ON edc_sync_log(source_system, operation);

-- Immutability rules - sync log is append-only for non-repudiation
CREATE RULE edc_sync_log_no_update AS ON UPDATE TO edc_sync_log DO INSTEAD NOTHING;
CREATE RULE edc_sync_log_no_delete AS ON DELETE TO edc_sync_log DO INSTEAD NOTHING;

COMMENT ON TABLE edc_sync_log IS 'Tamper-evident audit log of EDC sync events with chained hashing for non-repudiation (REQ-CAL-p00010, REQ-CAL-p00011)';
COMMENT ON COLUMN edc_sync_log.sync_id IS 'Unique identifier for each sync event';
COMMENT ON COLUMN edc_sync_log.sync_timestamp IS 'Timestamp when sync was performed';
COMMENT ON COLUMN edc_sync_log.source_system IS 'Source EDC system (RAVE, MEDIDATA, etc.)';
COMMENT ON COLUMN edc_sync_log.operation IS 'Type of sync operation performed';
COMMENT ON COLUMN edc_sync_log.content_hash IS 'SHA-256 hash of synced content for integrity verification';
COMMENT ON COLUMN edc_sync_log.chain_hash IS 'Chained hash: SHA256(previous_chain_hash || content_hash || timestamp) for tamper evidence';
COMMENT ON COLUMN edc_sync_log.duration_ms IS 'Duration of sync operation in milliseconds';
COMMENT ON COLUMN edc_sync_log.success IS 'Whether sync completed successfully';
COMMENT ON COLUMN edc_sync_log.error_message IS 'Error details if sync failed';
COMMENT ON COLUMN edc_sync_log.metadata IS 'Additional sync metadata (study OID, site count, etc.)';

-- =====================================================
-- EVENT STORE (Event Sourcing Pattern)
-- =====================================================
-- Source of truth for all diary data changes
-- Immutable append-only event log - INSERT ONLY

-- Event store table - no updates or deletes allowed
CREATE TABLE record_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    event_uuid UUID NOT NULL,
    patient_id TEXT NOT NULL,
    site_id TEXT NOT NULL REFERENCES sites(site_id),
    operation TEXT NOT NULL CHECK (operation IN (
        'USER_CREATE', 'USER_UPDATE', 'USER_DELETE',
        'INVESTIGATOR_CREATE', 'INVESTIGATOR_UPDATE', 'INVESTIGATOR_ANNOTATE',
        'ADMIN_CREATE', 'ADMIN_UPDATE', 'ADMIN_DELETE', 'ADMIN_CORRECTION'
    )),
    data JSONB NOT NULL,
    created_by TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('USER', 'INVESTIGATOR', 'ANALYST', 'ADMIN')),
    client_timestamp TIMESTAMPTZ NOT NULL,
    server_timestamp TIMESTAMPTZ DEFAULT now() NOT NULL,
    parent_audit_id BIGINT REFERENCES record_audit(audit_id),
    change_reason TEXT NOT NULL,
    conflict_resolved BOOLEAN DEFAULT false,
    conflict_metadata JSONB,
    signature_hash TEXT,
    device_info JSONB,
    ip_address INET,
    session_id TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Prevent updates and deletes on event store
CREATE RULE audit_no_update AS ON UPDATE TO record_audit DO INSTEAD NOTHING;
CREATE RULE audit_no_delete AS ON DELETE TO record_audit DO INSTEAD NOTHING;

COMMENT ON TABLE record_audit IS 'Event Store (Event Sourcing pattern) - Immutable event log capturing all diary data changes (INSERT only). Provides audit trail for FDA 21 CFR Part 11 compliance.';
COMMENT ON COLUMN record_audit.audit_id IS 'Auto-incrementing event ID establishing chronological order in event store';
COMMENT ON COLUMN record_audit.event_uuid IS 'Client-generated UUID for diary event (same across all database instances for offline-first sync)';
COMMENT ON COLUMN record_audit.parent_audit_id IS 'Links to previous event for version tracking and conflict detection (Event Sourcing lineage)';
COMMENT ON COLUMN record_audit.signature_hash IS 'Cryptographic signature for tamper detection and 21 CFR Part 11 compliance';
COMMENT ON COLUMN record_audit.device_info IS 'Device and platform information for ALCOA+ compliance (device_type, os, browser, app_version)';
COMMENT ON COLUMN record_audit.ip_address IS 'Source IP address for compliance tracking and security monitoring';
COMMENT ON COLUMN record_audit.session_id IS 'Session identifier for event correlation and security tracking';

-- =====================================================
-- READ MODEL (CQRS Pattern)
-- =====================================================
-- Materialized view of current state - derived from event store
-- Updated automatically via triggers when events are written

-- Read model table - queries use this, writes go to event store
CREATE TABLE record_state (
    event_uuid UUID PRIMARY KEY,
    patient_id TEXT NOT NULL,
    site_id TEXT NOT NULL REFERENCES sites(site_id),
    current_data JSONB NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    last_audit_id BIGINT NOT NULL REFERENCES record_audit(audit_id),
    is_deleted BOOLEAN DEFAULT false,
    sync_metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE record_state IS 'Read Model (CQRS pattern) - Current state view derived from event store via triggers. Query this table for current data; write to record_audit for changes.';
COMMENT ON COLUMN record_state.version IS 'Number of events that modified this entry (counts updates in event store)';
COMMENT ON COLUMN record_state.last_audit_id IS 'Reference to most recent event in event store (record_audit.audit_id)';
COMMENT ON COLUMN record_state.is_deleted IS 'Soft delete flag (set via USER_DELETE event in event store)';

-- =====================================================
-- INVESTIGATOR ANNOTATIONS
-- =====================================================

-- Investigator notes and corrections (separate layer)
CREATE TABLE investigator_annotations (
    annotation_id BIGSERIAL PRIMARY KEY,
    event_uuid UUID NOT NULL REFERENCES record_state(event_uuid),
    investigator_id TEXT NOT NULL,
    site_id TEXT NOT NULL REFERENCES sites(site_id),
    annotation_text TEXT NOT NULL,
    annotation_type TEXT CHECK (annotation_type IN ('NOTE', 'QUERY', 'CORRECTION', 'CLARIFICATION')),
    requires_response BOOLEAN DEFAULT false,
    resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMPTZ,
    resolved_by TEXT,
    parent_annotation_id BIGINT REFERENCES investigator_annotations(annotation_id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE investigator_annotations IS 'Investigator notes and corrections - does not modify original patient data';
COMMENT ON COLUMN investigator_annotations.annotation_type IS 'Type of annotation for workflow management';
COMMENT ON COLUMN investigator_annotations.requires_response IS 'Flags queries requiring patient response';

-- =====================================================
-- USER-SITE ASSIGNMENTS
-- =====================================================

-- Patient enrollment at sites
CREATE TABLE user_site_assignments (
    assignment_id BIGSERIAL PRIMARY KEY,
    patient_id TEXT NOT NULL,
    site_id TEXT NOT NULL REFERENCES sites(site_id),
    study_patient_id TEXT NOT NULL,
    enrolled_at TIMESTAMPTZ DEFAULT now(),
    enrollment_status TEXT DEFAULT 'ACTIVE' CHECK (enrollment_status IN ('ACTIVE', 'COMPLETED', 'WITHDRAWN', 'SCREENING')),
    withdrawn_at TIMESTAMPTZ,
    withdrawal_reason TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    UNIQUE(patient_id, site_id)
);

COMMENT ON TABLE user_site_assignments IS 'Patient enrollment and site assignment';
COMMENT ON COLUMN user_site_assignments.study_patient_id IS 'De-identified patient ID for the study';

-- =====================================================
-- INVESTIGATOR-SITE ASSIGNMENTS
-- =====================================================

-- Investigator access to sites
CREATE TABLE investigator_site_assignments (
    assignment_id BIGSERIAL PRIMARY KEY,
    investigator_id TEXT NOT NULL,
    site_id TEXT NOT NULL REFERENCES sites(site_id),
    access_level TEXT DEFAULT 'READ_WRITE' CHECK (access_level IN ('READ_ONLY', 'READ_WRITE', 'ADMIN')),
    assigned_at TIMESTAMPTZ DEFAULT now(),
    assigned_by TEXT,
    is_active BOOLEAN DEFAULT true,
    deactivated_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    UNIQUE(investigator_id, site_id)
);

COMMENT ON TABLE investigator_site_assignments IS 'Investigator access rights per site';

-- =====================================================
-- ANALYST-SITE ASSIGNMENTS
-- =====================================================

-- Analyst access to sites (read-only)
CREATE TABLE analyst_site_assignments (
    assignment_id BIGSERIAL PRIMARY KEY,
    analyst_id TEXT NOT NULL,
    site_id TEXT NOT NULL REFERENCES sites(site_id),
    access_level TEXT DEFAULT 'READ_ONLY' CHECK (access_level IN ('READ_ONLY', 'READ_DEIDENTIFIED')),
    assigned_at TIMESTAMPTZ DEFAULT now(),
    assigned_by TEXT,
    is_active BOOLEAN DEFAULT true,
    deactivated_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    UNIQUE(analyst_id, site_id)
);

COMMENT ON TABLE analyst_site_assignments IS 'Analyst read-only access rights per site';

-- =====================================================
-- CONFLICT TRACKING
-- =====================================================

-- Track multi-device sync conflicts
CREATE TABLE sync_conflicts (
    conflict_id BIGSERIAL PRIMARY KEY,
    event_uuid UUID NOT NULL REFERENCES record_state(event_uuid),
    patient_id TEXT NOT NULL,
    site_id TEXT NOT NULL REFERENCES sites(site_id),
    client_version INTEGER NOT NULL,
    server_version INTEGER NOT NULL,
    client_data JSONB NOT NULL,
    server_data JSONB NOT NULL,
    conflict_detected_at TIMESTAMPTZ DEFAULT now(),
    resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMPTZ,
    resolution_strategy TEXT CHECK (resolution_strategy IN ('CLIENT_WINS', 'SERVER_WINS', 'MERGE', 'MANUAL')),
    resolved_data JSONB,
    resolved_by TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE sync_conflicts IS 'Multi-device synchronization conflict tracking';
COMMENT ON COLUMN sync_conflicts.resolution_strategy IS 'How the conflict was resolved';

-- =====================================================
-- ADMIN ACTION LOG
-- =====================================================

-- Special logging for admin actions (additional layer beyond audit)
CREATE TABLE admin_action_log (
    action_id BIGSERIAL PRIMARY KEY,
    admin_id TEXT NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN (
        'ASSIGN_USER', 'ASSIGN_INVESTIGATOR', 'ASSIGN_ANALYST',
        'DATA_CORRECTION', 'ROLE_CHANGE', 'SYSTEM_CONFIG',
        'EMERGENCY_ACCESS', 'BULK_OPERATION'
    )),
    target_resource TEXT,
    action_details JSONB NOT NULL,
    justification TEXT NOT NULL,
    requires_review BOOLEAN DEFAULT true,
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    approval_status TEXT CHECK (approval_status IN ('PENDING', 'APPROVED', 'REJECTED')),
    created_at TIMESTAMPTZ DEFAULT now(),
    ip_address INET,
    user_agent TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE admin_action_log IS 'Administrative actions requiring additional oversight';
COMMENT ON COLUMN admin_action_log.requires_review IS 'Whether action requires investigator review';

-- =====================================================
-- AUDITOR EXPORT LOG (REQ-d00024)
-- =====================================================

-- Tracks auditor data export activities for compliance
CREATE TABLE auditor_export_log (
    export_id BIGSERIAL PRIMARY KEY,
    auditor_id TEXT NOT NULL,
    export_timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    justification TEXT NOT NULL CHECK (length(justification) >= 10),
    case_id TEXT NOT NULL CHECK (length(case_id) >= 5),
    table_name TEXT NOT NULL,
    record_count INTEGER NOT NULL DEFAULT 0,
    export_format TEXT NOT NULL DEFAULT 'csv' CHECK (export_format IN ('csv', 'json', 'xlsx')),
    filters JSONB DEFAULT '{}'::jsonb,
    completed_at TIMESTAMPTZ,
    export_size_bytes BIGINT,
    ip_address INET,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE auditor_export_log IS 'Audit trail for all data exports performed by auditors (REQ-p00038, REQ-d00024)';
COMMENT ON COLUMN auditor_export_log.justification IS 'Business justification for the export (minimum 10 characters)';
COMMENT ON COLUMN auditor_export_log.case_id IS 'Case or audit reference identifier (minimum 5 characters)';

-- =====================================================
-- BREAK-GLASS AUTHORIZATION (REQ-d00025)
-- =====================================================

-- Tracks time-limited emergency access authorizations
CREATE TABLE break_glass_authorizations (
    authorization_id BIGSERIAL PRIMARY KEY,
    admin_id TEXT NOT NULL,
    ticket_id TEXT NOT NULL CHECK (length(ticket_id) >= 5),
    justification TEXT NOT NULL CHECK (length(justification) >= 20),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    granted_by TEXT NOT NULL,
    revoked_at TIMESTAMPTZ,
    revoked_by TEXT,
    revocation_reason TEXT,
    CONSTRAINT valid_ttl CHECK (expires_at > granted_at),
    CONSTRAINT max_ttl CHECK (expires_at <= granted_at + INTERVAL '24 hours')
);

COMMENT ON TABLE break_glass_authorizations IS 'Time-limited emergency access authorizations for administrators (REQ-p00039, REQ-d00025)';
COMMENT ON COLUMN break_glass_authorizations.ticket_id IS 'Support ticket or incident ID justifying emergency access';
COMMENT ON COLUMN break_glass_authorizations.expires_at IS 'Authorization expires after this timestamp (max 24 hours from grant)';

-- =====================================================
-- BREAK-GLASS ACCESS LOG (REQ-d00025)
-- =====================================================

-- Detailed audit trail of break-glass access usage
CREATE TABLE break_glass_access_log (
    access_id BIGSERIAL PRIMARY KEY,
    authorization_id BIGINT NOT NULL REFERENCES break_glass_authorizations(authorization_id),
    admin_id TEXT NOT NULL,
    access_timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    accessed_table TEXT NOT NULL,
    accessed_record_id TEXT,
    operation TEXT NOT NULL CHECK (operation IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')),
    query_details JSONB,
    ip_address INET,
    session_id TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE break_glass_access_log IS 'Detailed logging of all database access during break-glass sessions (REQ-p00039, REQ-d00025)';
COMMENT ON COLUMN break_glass_access_log.authorization_id IS 'Links to the break-glass authorization that permitted this access';

-- =====================================================
-- SYSTEM CONFIGURATION (REQ-d00025, REQ-d00026)
-- =====================================================

-- System-wide configuration settings
CREATE TABLE system_config (
    config_key TEXT PRIMARY KEY,
    config_value JSONB NOT NULL,
    description TEXT NOT NULL,
    last_modified_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_modified_by TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE system_config IS 'System-wide configuration settings for RLS policies and access control';
COMMENT ON COLUMN system_config.config_key IS 'Configuration parameter name (e.g., break_glass_max_ttl, export_retention_days)';

-- =====================================================
-- MOBILE APP USER TABLES
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00008: User Account Management
--
-- Mobile app user accounts - any user can use the app to track nosebleeds
-- Patient linking handled via patient_linking_codes table

CREATE TABLE app_users (
    user_id TEXT PRIMARY KEY,
    username TEXT UNIQUE,
    password_hash TEXT,
    auth_code TEXT NOT NULL UNIQUE,
    app_uuid TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_active_at TIMESTAMPTZ DEFAULT now(),
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE app_users IS 'Mobile app user accounts - any user can use the app to track nosebleeds';
COMMENT ON COLUMN app_users.auth_code IS 'Random code used in JWT for user lookup';
COMMENT ON COLUMN app_users.app_uuid IS 'Device/app instance identifier';
COMMENT ON COLUMN app_users.username IS 'Optional username for registered users';

-- Indexes
CREATE INDEX idx_app_users_username ON app_users(username);
CREATE INDEX idx_app_users_auth_code ON app_users(auth_code);

-- =====================================================
-- PORTAL USERS (STAFF)
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-d00039: Portal Users Table Schema
--   REQ-p00024: Portal User Roles and Permissions
--
-- Portal staff accounts (Investigators, Sponsors, Auditors, etc.)
-- Separate from app_users (patients using the mobile diary)

-- User roles - common roles across all sponsors
-- IMPLEMENTS REQUIREMENTS:
--   REQ-CAL-p00029: Create User Account (Study Coordinator, CRA roles)
CREATE TYPE portal_user_role AS ENUM (
    'Investigator',
    'Sponsor',
    'Auditor',
    'Analyst',
    'Administrator',
    'Developer Admin'
);

-- Portal staff users
CREATE TABLE portal_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT UNIQUE,           -- Identity Platform UID (linked after first login)
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    -- Note: role column kept for backwards compatibility; use portal_user_roles for multi-role
    role portal_user_role,              -- Primary role (optional, roles now in portal_user_roles)
    linking_code TEXT UNIQUE,           -- Device enrollment code for Investigators (XXXXX-XXXXX format)
    activation_code TEXT UNIQUE,        -- Account activation code (XXXXX-XXXXX format)
    activation_code_expires_at TIMESTAMPTZ, -- Activation code expiry (typically 14 days)
    activated_at TIMESTAMPTZ,           -- When account was activated
    password_reset_code TEXT UNIQUE,    -- Password reset code (XXXXX-XXXXX format, single-use)
    password_reset_code_expires_at TIMESTAMPTZ, -- Password reset code expiry (24 hours)
    password_reset_used_at TIMESTAMPTZ, -- When password reset was completed (audit)
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('active', 'revoked', 'pending')),
    status_change_reason TEXT,              -- Reason for last status change (deactivation/reactivation)
    status_changed_at TIMESTAMPTZ,          -- When status was last changed
    status_changed_by UUID REFERENCES portal_users(id),  -- Who changed the status
    -- MFA tracking (FDA 21 CFR Part 11 compliance)
    mfa_enrolled BOOLEAN NOT NULL DEFAULT false,
    mfa_enrolled_at TIMESTAMPTZ,
    mfa_method TEXT CHECK (mfa_method IN ('totp', 'sms', 'email')),
    mfa_type TEXT CHECK (mfa_type IN ('totp', 'email_otp', 'none')) DEFAULT 'email_otp',
    tokens_revoked_at TIMESTAMPTZ,          -- When all sessions were invalidated (edit triggers revocation)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_portal_users_firebase_uid ON portal_users(firebase_uid);
CREATE INDEX idx_portal_users_email ON portal_users(email);
CREATE INDEX idx_portal_users_linking_code ON portal_users(linking_code);
CREATE INDEX idx_portal_users_activation_code ON portal_users(activation_code);
CREATE INDEX idx_portal_users_role ON portal_users(role);
CREATE INDEX idx_portal_users_status ON portal_users(status);
CREATE INDEX idx_portal_users_mfa_enrolled ON portal_users(mfa_enrolled, status);

ALTER TABLE portal_users ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE portal_users IS 'Portal staff accounts (Investigators, Sponsors, Auditors, etc.) - separate from patient app_users';
COMMENT ON COLUMN portal_users.firebase_uid IS 'Identity Platform UID - linked after first login via email match';
COMMENT ON COLUMN portal_users.role IS 'Primary role (backwards compat) - use portal_user_roles for multi-role support';
COMMENT ON COLUMN portal_users.linking_code IS 'Device enrollment code for Investigators (XXXXX-XXXXX format)';
COMMENT ON COLUMN portal_users.activation_code IS 'Account activation code sent to new users (XXXXX-XXXXX format)';
COMMENT ON COLUMN portal_users.activation_code_expires_at IS 'Activation code expiry - typically 14 days after generation';
COMMENT ON COLUMN portal_users.activated_at IS 'When user activated their account (set password, completed 2FA)';
COMMENT ON COLUMN portal_users.password_reset_code IS 'Password reset code sent via email (XXXXX-XXXXX format, single-use)';
COMMENT ON COLUMN portal_users.password_reset_code_expires_at IS 'Password reset code expiry - typically 24 hours from generation';
COMMENT ON COLUMN portal_users.password_reset_used_at IS 'Timestamp when password reset was successfully completed (audit trail)';
COMMENT ON COLUMN portal_users.status IS 'Account status: pending (awaiting activation), active, or revoked';
COMMENT ON COLUMN portal_users.mfa_enrolled IS 'Whether user has completed MFA enrollment (FDA 21 CFR Part 11)';
COMMENT ON COLUMN portal_users.mfa_enrolled_at IS 'Timestamp when MFA was successfully enrolled';
COMMENT ON COLUMN portal_users.mfa_method IS 'Type of MFA method enrolled (totp, sms, email)';
COMMENT ON COLUMN portal_users.mfa_type IS 'MFA method to use: totp (authenticator app for Dev Admins), email_otp (email codes), none (disabled)';
COMMENT ON COLUMN portal_users.tokens_revoked_at IS 'Timestamp when all sessions were invalidated - tokens with auth_time before this are rejected';
COMMENT ON COLUMN portal_users.status_change_reason IS 'Reason for last status change (deactivation/reactivation) - REQ-CAL-p00066';
COMMENT ON COLUMN portal_users.status_changed_at IS 'Timestamp when account status was last changed';
COMMENT ON COLUMN portal_users.status_changed_by IS 'UUID of admin who last changed the account status';

-- =====================================================
-- UPDATED_AT TRIGGER FUNCTION (defined early for use by multiple tables)
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
CREATE TRIGGER update_portal_users_updated_at BEFORE UPDATE ON portal_users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- PORTAL USER SITE ACCESS
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-d00040: User Site Access Table Schema
--   REQ-d00033: Site-Based Data Isolation
--
-- Maps portal users (primarily Investigators) to their assigned sites

CREATE TABLE portal_user_site_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
    site_id TEXT NOT NULL REFERENCES sites(site_id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, site_id)
);

CREATE INDEX idx_portal_user_site_access_user ON portal_user_site_access(user_id);
CREATE INDEX idx_portal_user_site_access_site ON portal_user_site_access(site_id);

ALTER TABLE portal_user_site_access ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE portal_user_site_access IS 'Maps portal users (Investigators) to their assigned clinical sites';
COMMENT ON COLUMN portal_user_site_access.user_id IS 'Reference to portal_users.id';
COMMENT ON COLUMN portal_user_site_access.site_id IS 'Reference to sites.site_id';

-- =====================================================
-- PORTAL USER ROLES (MULTI-ROLE SUPPORT)
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00024: Portal User Roles and Permissions
--   REQ-d00032: Role-Based Access Control Implementation
--
-- Junction table allowing users to have multiple roles
-- Each role is selected as "active" during login/session

CREATE TABLE portal_user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
    role portal_user_role NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    assigned_by UUID REFERENCES portal_users(id),  -- Who assigned this role
    UNIQUE(user_id, role)
);

CREATE INDEX idx_portal_user_roles_user ON portal_user_roles(user_id);
CREATE INDEX idx_portal_user_roles_role ON portal_user_roles(role);

ALTER TABLE portal_user_roles ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE portal_user_roles IS 'Maps portal users to their roles - supports multiple roles per user';
COMMENT ON COLUMN portal_user_roles.user_id IS 'Reference to portal_users.id';
COMMENT ON COLUMN portal_user_roles.role IS 'Role from portal_user_role enum';
COMMENT ON COLUMN portal_user_roles.assigned_by IS 'Admin who assigned this role (null for seeded data)';

-- =====================================================
-- PORTAL USER AUDIT LOG (Immutable)
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-CAL-p00030: Edit User Account
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--
-- Tracks all modifications to portal user accounts
-- Immutable append-only log for compliance

CREATE TABLE portal_user_audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES portal_users(id),
    changed_by UUID NOT NULL REFERENCES portal_users(id),
    action TEXT NOT NULL CHECK (action IN (
        'update_name', 'update_email', 'update_roles',
        'update_sites', 'update_status', 'revoke_sessions'
    )),
    before_value JSONB,           -- State before the change
    after_value JSONB,            -- State after the change
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_address INET,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Immutability rules - audit log is append-only
CREATE RULE portal_user_audit_log_no_update AS ON UPDATE TO portal_user_audit_log DO INSTEAD NOTHING;
CREATE RULE portal_user_audit_log_no_delete AS ON DELETE TO portal_user_audit_log DO INSTEAD NOTHING;

CREATE INDEX idx_portal_user_audit_log_user ON portal_user_audit_log(user_id);
CREATE INDEX idx_portal_user_audit_log_changed_by ON portal_user_audit_log(changed_by);
CREATE INDEX idx_portal_user_audit_log_created ON portal_user_audit_log(created_at DESC);

ALTER TABLE portal_user_audit_log ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE portal_user_audit_log IS 'Immutable audit log of all portal user account modifications (REQ-CAL-p00030, REQ-p00010)';
COMMENT ON COLUMN portal_user_audit_log.action IS 'Type of modification performed';
COMMENT ON COLUMN portal_user_audit_log.before_value IS 'JSONB snapshot of state before change';
COMMENT ON COLUMN portal_user_audit_log.after_value IS 'JSONB snapshot of state after change';

-- =====================================================
-- PORTAL PENDING EMAIL CHANGES
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-CAL-p00030: Edit User Account
--
-- Tracks pending email address changes awaiting verification
-- Email changes require the new address to be verified before taking effect

CREATE TABLE portal_pending_email_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
    new_email TEXT NOT NULL,
    token_hash TEXT NOT NULL,            -- SHA-256 hash of verification token
    requested_by UUID NOT NULL REFERENCES portal_users(id),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,     -- 24hr expiry
    verified_at TIMESTAMPTZ,             -- NULL until verified
    CONSTRAINT email_change_expiry CHECK (expires_at > requested_at)
);

CREATE INDEX idx_pending_email_user ON portal_pending_email_changes(user_id);
CREATE INDEX idx_pending_email_expires ON portal_pending_email_changes(expires_at) WHERE verified_at IS NULL;

ALTER TABLE portal_pending_email_changes ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE portal_pending_email_changes IS 'Pending email address changes awaiting verification (REQ-CAL-p00030)';
COMMENT ON COLUMN portal_pending_email_changes.token_hash IS 'SHA-256 hash of the verification token sent via email';
COMMENT ON COLUMN portal_pending_email_changes.expires_at IS '24-hour expiration from request time';

-- =====================================================
-- SPONSOR ROLE MAPPING
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-d00041: Sponsor Role Mapping Schema
--
-- Maps sponsor-specific role names to common portal_user_role enum
-- Each sponsor can define their own role terminology

CREATE TABLE sponsor_role_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sponsor_id TEXT NOT NULL,
    sponsor_role_name TEXT NOT NULL,
    mapped_role portal_user_role NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(sponsor_id, sponsor_role_name)
);

CREATE INDEX idx_sponsor_role_mapping_sponsor ON sponsor_role_mapping(sponsor_id);

COMMENT ON TABLE sponsor_role_mapping IS 'Maps sponsor-specific role names to common portal_user_role enum';
COMMENT ON COLUMN sponsor_role_mapping.sponsor_id IS 'Sponsor identifier (e.g., curehht, callisto)';
COMMENT ON COLUMN sponsor_role_mapping.sponsor_role_name IS 'Sponsor internal role name (e.g., CRA, Study Coordinator)';
COMMENT ON COLUMN sponsor_role_mapping.mapped_role IS 'Common role this maps to in portal_user_role enum';

-- =====================================================
-- EMAIL OTP CODES (2FA via Email)
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00002: Multi-Factor Authentication for Staff
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--
-- Stores time-limited email OTP codes for non-admin users
-- Codes are SHA-256 hashed, never stored in plaintext

CREATE TABLE email_otp_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
    code_hash TEXT NOT NULL,              -- SHA-256 hash of the 6-digit code
    expires_at TIMESTAMPTZ NOT NULL,      -- 10-minute expiration window
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    used_at TIMESTAMPTZ,                  -- NULL until code is verified
    ip_address INET,                      -- IP address that requested the code
    attempts INTEGER NOT NULL DEFAULT 0,  -- Track failed verification attempts
    CONSTRAINT max_attempts CHECK (attempts <= 5)
);

CREATE INDEX idx_email_otp_user_id ON email_otp_codes(user_id);
CREATE INDEX idx_email_otp_expires ON email_otp_codes(expires_at) WHERE used_at IS NULL;
CREATE INDEX idx_email_otp_cleanup ON email_otp_codes(created_at) WHERE used_at IS NOT NULL;

ALTER TABLE email_otp_codes ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE email_otp_codes IS 'Time-limited email OTP codes for 2FA (non-admin users)';
COMMENT ON COLUMN email_otp_codes.code_hash IS 'SHA-256 hash of 6-digit code - never store plaintext';
COMMENT ON COLUMN email_otp_codes.expires_at IS '10-minute expiration from creation';
COMMENT ON COLUMN email_otp_codes.used_at IS 'Timestamp when code was successfully verified';
COMMENT ON COLUMN email_otp_codes.attempts IS 'Failed verification attempts - max 5 before lockout';

-- =====================================================
-- EMAIL RATE LIMITS
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00002: Multi-Factor Authentication for Staff
--
-- Prevents email abuse (spam, brute force attacks)
-- Rate limit: max 3 emails per address per 15 minutes

CREATE TABLE email_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    email_type TEXT NOT NULL CHECK (email_type IN ('otp', 'activation', 'password_reset')),
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_address INET
);

CREATE INDEX idx_email_rate_limits_email ON email_rate_limits(email, email_type, sent_at);
CREATE INDEX idx_email_rate_limits_cleanup ON email_rate_limits(sent_at);

COMMENT ON TABLE email_rate_limits IS 'Track email sends for rate limiting - max 3 per email per 15 min';
COMMENT ON COLUMN email_rate_limits.email_type IS 'Type of email: otp (login codes), activation (new user codes)';

-- =====================================================
-- EMAIL AUDIT LOG (FDA Compliance - Immutable)
-- =====================================================
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00002: Multi-Factor Authentication for Staff
--
-- FDA compliance requires logging all communications
-- This table is immutable - no updates or deletes allowed

CREATE TABLE email_audit_log (
    id BIGSERIAL PRIMARY KEY,
    recipient_email TEXT NOT NULL,
    email_type TEXT NOT NULL CHECK (email_type IN ('otp', 'activation', 'notification', 'password_reset', 'email_change')),
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_by UUID REFERENCES portal_users(id),  -- NULL for system-generated emails
    status TEXT NOT NULL CHECK (status IN ('sent', 'failed', 'bounced', 'console')),
    gmail_message_id TEXT,                -- Gmail API message ID for tracking
    error_message TEXT,                   -- Error details if status is 'failed'
    metadata JSONB DEFAULT '{}'::jsonb    -- Additional context (masked email, etc.)
);

-- Make this table immutable for FDA compliance
CREATE RULE email_audit_log_no_update AS ON UPDATE TO email_audit_log DO INSTEAD NOTHING;
CREATE RULE email_audit_log_no_delete AS ON DELETE TO email_audit_log DO INSTEAD NOTHING;

CREATE INDEX idx_email_audit_recipient ON email_audit_log(recipient_email, sent_at);
CREATE INDEX idx_email_audit_type ON email_audit_log(email_type, sent_at);
CREATE INDEX idx_email_audit_status ON email_audit_log(status, sent_at);

ALTER TABLE email_audit_log ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE email_audit_log IS 'Immutable audit log of all system emails for FDA compliance';
COMMENT ON COLUMN email_audit_log.sent_by IS 'Portal user who triggered the email (NULL for system)';
COMMENT ON COLUMN email_audit_log.gmail_message_id IS 'Gmail API message ID for delivery tracking';
COMMENT ON COLUMN email_audit_log.metadata IS 'Additional context: masked email, request IP, etc.';

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to get current user ID from JWT claims (Supabase context)
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(
        current_setting('request.jwt.claims', true)::json->>'sub',
        current_user
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION current_user_id() IS 'Extract user ID from Supabase JWT token';

-- Function to get current user role from JWT claims
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(
        current_setting('request.jwt.claims', true)::json->>'role',
        'anon'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION current_user_role() IS 'Extract user role from Supabase JWT token';

-- =====================================================
-- RLS HELPER FUNCTIONS (REQ-d00025)
-- =====================================================

-- Check if current user has active break-glass authorization
CREATE OR REPLACE FUNCTION has_break_glass_auth()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM break_glass_authorizations
        WHERE admin_id = current_user_id()
          AND revoked_at IS NULL
          AND expires_at > now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION has_break_glass_auth() IS 'Check if current admin has active break-glass authorization (REQ-d00025)';

-- Export clinical data with audit logging (REQ-d00024)
CREATE OR REPLACE FUNCTION export_clinical_data(
    p_table_name TEXT,
    p_justification TEXT,
    p_case_id TEXT,
    p_export_format TEXT DEFAULT 'csv',
    p_filters JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE (
    export_id BIGINT,
    message TEXT
) AS $$
DECLARE
    v_export_id BIGINT;
    v_auditor_id TEXT;
BEGIN
    -- Get current user ID
    v_auditor_id := current_user_id();

    -- Verify user has AUDITOR role
    IF current_user_role() != 'AUDITOR' THEN
        RAISE EXCEPTION 'Only AUDITOR role can export clinical data';
    END IF;

    -- Validate justification length
    IF length(p_justification) < 10 THEN
        RAISE EXCEPTION 'Justification must be at least 10 characters';
    END IF;

    -- Validate case_id length
    IF length(p_case_id) < 5 THEN
        RAISE EXCEPTION 'Case ID must be at least 5 characters';
    END IF;

    -- Log the export attempt
    INSERT INTO auditor_export_log (
        auditor_id,
        justification,
        case_id,
        table_name,
        export_format,
        filters
    ) VALUES (
        v_auditor_id,
        p_justification,
        p_case_id,
        p_table_name,
        p_export_format,
        p_filters
    ) RETURNING auditor_export_log.export_id INTO v_export_id;

    RETURN QUERY SELECT v_export_id, 'Export logged successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION export_clinical_data IS 'Export clinical data with mandatory audit logging (REQ-p00038, REQ-d00024)';

-- Cleanup expired break-glass authorizations (maintenance function)
CREATE OR REPLACE FUNCTION cleanup_expired_break_glass()
RETURNS TABLE (
    cleaned_count INTEGER
) AS $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Count expired authorizations that aren't already marked as revoked
    SELECT COUNT(*) INTO v_count
    FROM break_glass_authorizations
    WHERE expires_at < now()
      AND revoked_at IS NULL;

    -- No actual deletion - just return count for monitoring
    -- Expired authorizations automatically become invalid via has_break_glass_auth()

    RETURN QUERY SELECT v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION cleanup_expired_break_glass IS 'Report count of expired break-glass authorizations (for monitoring)';

-- Validate event sourcing state integrity (REQ-d00026)
CREATE OR REPLACE FUNCTION validate_state_integrity()
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    details TEXT
) AS $$
BEGIN
    -- Check 1: All record_state entries have corresponding audit events
    RETURN QUERY
    SELECT
        'state_audit_consistency'::TEXT,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END::TEXT,
        'Found ' || COUNT(*) || ' record_state entries without corresponding audit events'::TEXT
    FROM record_state rs
    LEFT JOIN record_audit ra ON rs.last_audit_id = ra.audit_id
    WHERE ra.audit_id IS NULL;

    -- Check 2: No orphaned audit events (should have record_state)
    RETURN QUERY
    SELECT
        'audit_state_consistency'::TEXT,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END::TEXT,
        'Found ' || COUNT(*) || ' audit events without corresponding record_state'::TEXT
    FROM record_audit ra
    LEFT JOIN record_state rs ON ra.event_uuid = rs.event_uuid
    WHERE rs.event_uuid IS NULL;

    -- Check 3: Version counts match event counts
    RETURN QUERY
    SELECT
        'version_count_consistency'::TEXT,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END::TEXT,
        'Found ' || COUNT(*) || ' record_state entries with version mismatch'::TEXT
    FROM (
        SELECT
            rs.event_uuid,
            rs.version,
            COUNT(ra.audit_id) as event_count
        FROM record_state rs
        JOIN record_audit ra ON ra.event_uuid = rs.event_uuid
        GROUP BY rs.event_uuid, rs.version
        HAVING rs.version != COUNT(ra.audit_id)
    ) mismatches;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION validate_state_integrity IS 'Validate event sourcing consistency between record_audit and record_state (REQ-d00026)';

-- =====================================================
-- JSONB VALIDATION FUNCTIONS
-- =====================================================
-- See spec/JSONB_SCHEMA.md for complete schema documentation

-- Helper function to validate UUID format
CREATE OR REPLACE FUNCTION is_valid_uuid(uuid_string TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if string matches UUID format (8-4-4-4-12 hex digits)
    RETURN uuid_string ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION is_valid_uuid(TEXT) IS 'Validates UUID format (supports v4 and v7)';

-- Helper function to validate ISO 8601 timestamp format
CREATE OR REPLACE FUNCTION is_valid_iso8601(timestamp_string TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Try to cast to timestamptz; if it fails, it's not valid ISO 8601
    PERFORM timestamp_string::timestamptz;
    RETURN true;
EXCEPTION
    WHEN OTHERS THEN
        RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION is_valid_iso8601(TEXT) IS 'Validates ISO 8601 timestamp format with timezone';

-- Validate epistaxis event data
CREATE OR REPLACE FUNCTION validate_epistaxis_data(event_data JSONB)
RETURNS BOOLEAN AS $$
DECLARE
    severity_value TEXT;
    valid_severities TEXT[] := ARRAY['minimal', 'mild', 'moderate', 'severe', 'very_severe', 'extreme'];
    is_no_nosebleeds BOOLEAN;
    is_unknown BOOLEAN;
    is_incomplete BOOLEAN;
BEGIN
    -- Required fields
    IF NOT (event_data ? 'id') THEN
        RAISE EXCEPTION 'epistaxis: Missing required field: event_data.id';
    END IF;

    IF NOT (event_data ? 'startTime') THEN
        RAISE EXCEPTION 'epistaxis: Missing required field: event_data.startTime';
    END IF;

    IF NOT (event_data ? 'lastModified') THEN
        RAISE EXCEPTION 'epistaxis: Missing required field: event_data.lastModified';
    END IF;

    -- Validate UUID format
    IF NOT is_valid_uuid(event_data->>'id') THEN
        RAISE EXCEPTION 'epistaxis: Invalid UUID format in event_data.id';
    END IF;

    -- Validate timestamp formats
    IF NOT is_valid_iso8601(event_data->>'startTime') THEN
        RAISE EXCEPTION 'epistaxis: Invalid ISO 8601 format in event_data.startTime';
    END IF;

    IF NOT is_valid_iso8601(event_data->>'lastModified') THEN
        RAISE EXCEPTION 'epistaxis: Invalid ISO 8601 format in event_data.lastModified';
    END IF;

    -- Validate endTime if present
    IF event_data ? 'endTime' AND event_data->>'endTime' IS NOT NULL THEN
        IF NOT is_valid_iso8601(event_data->>'endTime') THEN
            RAISE EXCEPTION 'epistaxis: Invalid ISO 8601 format in event_data.endTime';
        END IF;
    END IF;

    -- Get boolean flags (default to false if not present)
    is_no_nosebleeds := COALESCE((event_data->>'isNoNosebleedsEvent')::boolean, false);
    is_unknown := COALESCE((event_data->>'isUnknownNosebleedsEvent')::boolean, false);
    is_incomplete := COALESCE((event_data->>'isIncomplete')::boolean, false);

    -- Validate mutual exclusivity: isNoNosebleedsEvent and isUnknownNosebleedsEvent cannot both be true
    IF is_no_nosebleeds AND is_unknown THEN
        RAISE EXCEPTION 'epistaxis: isNoNosebleedsEvent and isUnknownNosebleedsEvent cannot both be true';
    END IF;

    -- Validate severity enum if present (must be string, not number)
    IF event_data ? 'severity' AND event_data->>'severity' IS NOT NULL THEN
        severity_value := event_data->>'severity';

        -- Check if severity is a valid string enum
        IF NOT (severity_value = ANY(valid_severities)) THEN
            RAISE EXCEPTION 'epistaxis: Invalid severity value "%". Must be one of: %',
                severity_value, array_to_string(valid_severities, ', ');
        END IF;

        -- Special events should not have severity
        IF is_no_nosebleeds OR is_unknown THEN
            RAISE EXCEPTION 'epistaxis: severity must be omitted when isNoNosebleedsEvent or isUnknownNosebleedsEvent is true';
        END IF;
    END IF;

    -- Validate endTime rules for special events
    IF (is_no_nosebleeds OR is_unknown) AND (event_data ? 'endTime') THEN
        RAISE EXCEPTION 'epistaxis: endTime must be omitted when isNoNosebleedsEvent or isUnknownNosebleedsEvent is true';
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_epistaxis_data(JSONB) IS 'Validates epistaxis event data structure (v1.0)';

-- Validate survey event data
CREATE OR REPLACE FUNCTION validate_survey_data(event_data JSONB)
RETURNS BOOLEAN AS $$
DECLARE
    survey_array JSONB;
    question JSONB;
    has_response BOOLEAN;
    is_skipped BOOLEAN;
BEGIN
    -- Required fields
    IF NOT (event_data ? 'id') THEN
        RAISE EXCEPTION 'survey: Missing required field: event_data.id';
    END IF;

    IF NOT (event_data ? 'completedAt') THEN
        RAISE EXCEPTION 'survey: Missing required field: event_data.completedAt';
    END IF;

    IF NOT (event_data ? 'survey') THEN
        RAISE EXCEPTION 'survey: Missing required field: event_data.survey';
    END IF;

    IF NOT (event_data ? 'lastModified') THEN
        RAISE EXCEPTION 'survey: Missing required field: event_data.lastModified';
    END IF;

    -- Validate UUID format
    IF NOT is_valid_uuid(event_data->>'id') THEN
        RAISE EXCEPTION 'survey: Invalid UUID format in event_data.id';
    END IF;

    -- Validate timestamp formats
    IF NOT is_valid_iso8601(event_data->>'completedAt') THEN
        RAISE EXCEPTION 'survey: Invalid ISO 8601 format in event_data.completedAt';
    END IF;

    IF NOT is_valid_iso8601(event_data->>'lastModified') THEN
        RAISE EXCEPTION 'survey: Invalid ISO 8601 format in event_data.lastModified';
    END IF;

    -- Validate survey is an array
    IF jsonb_typeof(event_data->'survey') != 'array' THEN
        RAISE EXCEPTION 'survey: event_data.survey must be an array';
    END IF;

    survey_array := event_data->'survey';

    -- Validate survey is non-empty
    IF jsonb_array_length(survey_array) = 0 THEN
        RAISE EXCEPTION 'survey: event_data.survey must be non-empty';
    END IF;

    -- Validate each question in the survey
    FOR question IN SELECT * FROM jsonb_array_elements(survey_array)
    LOOP
        -- Check required fields
        IF NOT (question ? 'question_id') THEN
            RAISE EXCEPTION 'survey: Missing required field: question_id in survey question';
        END IF;

        IF NOT (question ? 'question_text') THEN
            RAISE EXCEPTION 'survey: Missing required field: question_text in survey question';
        END IF;

        -- Validate question_text is non-empty
        IF LENGTH(question->>'question_text') = 0 THEN
            RAISE EXCEPTION 'survey: question_text cannot be empty';
        END IF;

        -- Check response/skipped logic
        has_response := question ? 'response';
        is_skipped := COALESCE((question->>'skipped')::boolean, false);

        -- If skipped=true, response must be omitted
        IF is_skipped AND has_response THEN
            RAISE EXCEPTION 'survey: response must be omitted when skipped=true for question_id "%"',
                question->>'question_id';
        END IF;

        -- If skipped=false or omitted, response should be present
        IF NOT is_skipped AND NOT has_response THEN
            RAISE EXCEPTION 'survey: response is required when skipped is false for question_id "%"',
                question->>'question_id';
        END IF;
    END LOOP;

    -- Validate score if present
    IF event_data ? 'score' AND event_data->'score' IS NOT NULL THEN
        IF NOT (event_data->'score' ? 'total') THEN
            RAISE EXCEPTION 'survey: score.total is required when score is present';
        END IF;

        IF NOT (event_data->'score' ? 'rubric_version') THEN
            RAISE EXCEPTION 'survey: score.rubric_version is required when score is present';
        END IF;

        -- Validate rubric_version format (v1.0, v2.1, etc.)
        IF NOT (event_data->'score'->>'rubric_version' ~ '^v\d+\.\d+$') THEN
            RAISE EXCEPTION 'survey: score.rubric_version must match format v{major}.{minor}';
        END IF;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_survey_data(JSONB) IS 'Validates survey event data structure (v1.0)';

-- Main validation function for EventRecord
CREATE OR REPLACE FUNCTION validate_diary_data(data JSONB)
RETURNS BOOLEAN AS $$
DECLARE
    versioned_type TEXT;
    event_type TEXT;
    version TEXT;
BEGIN
    -- Check top-level required fields
    IF NOT (data ? 'id') THEN
        RAISE EXCEPTION 'Missing required field: id';
    END IF;

    IF NOT (data ? 'versioned_type') THEN
        RAISE EXCEPTION 'Missing required field: versioned_type';
    END IF;

    IF NOT (data ? 'event_data') THEN
        RAISE EXCEPTION 'Missing required field: event_data';
    END IF;

    -- Validate id is a UUID
    IF NOT is_valid_uuid(data->>'id') THEN
        RAISE EXCEPTION 'Invalid UUID format in id field';
    END IF;

    -- Validate versioned_type format: {type}-v{major}.{minor}
    versioned_type := data->>'versioned_type';
    IF NOT (versioned_type ~ '^[a-z_]+-v\d+\.\d+$') THEN
        RAISE EXCEPTION 'Invalid versioned_type format: "%". Expected format: {type}-v{major}.{minor}',
            versioned_type;
    END IF;

    -- Validate event_data is an object
    IF jsonb_typeof(data->'event_data') != 'object' THEN
        RAISE EXCEPTION 'event_data must be an object';
    END IF;

    -- Extract event type and version
    event_type := split_part(versioned_type, '-v', 1);
    version := split_part(versioned_type, '-v', 2);

    -- Delegate to type-specific validator
    CASE event_type
        WHEN 'epistaxis' THEN
            RETURN validate_epistaxis_data(data->'event_data');
        WHEN 'survey' THEN
            RETURN validate_survey_data(data->'event_data');
        ELSE
            RAISE EXCEPTION 'Unknown event type: "%". Supported types: epistaxis, survey', event_type;
    END CASE;

    RETURN true;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_diary_data(JSONB) IS 'Validates EventRecord structure and delegates to type-specific validators. See spec/JSONB_SCHEMA.md';

-- =====================================================
-- UPDATED_AT TRIGGER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_sites_updated_at BEFORE UPDATE ON sites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_record_state_updated_at BEFORE UPDATE ON record_state
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_investigator_annotations_updated_at BEFORE UPDATE ON investigator_annotations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_users_updated_at BEFORE UPDATE ON app_users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON patients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

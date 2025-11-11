-- =====================================================
-- Callisto Portal Database Schema
-- =====================================================
--
-- STANDALONE SCHEMA (Not Inherited)
-- Initially copied from: database/schema.sql
-- Maintained independently by Callisto sponsor
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-CAL-d00001: Callisto portal schema
--
-- NOTE: This schema is a standalone copy. Bugfixes to the core schema
-- must be manually applied here. See docs/schema-maintenance.md for process.
--
-- =====================================================

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
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Sites Table
-- Stores clinical trial site information
CREATE TABLE sites (
    site_id TEXT PRIMARY KEY,
    site_name TEXT NOT NULL,
    site_number TEXT NOT NULL UNIQUE,
    address JSONB,
    contact_info JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE sites IS 'Clinical trial site information';
COMMENT ON COLUMN sites.site_id IS 'Unique site identifier';
COMMENT ON COLUMN sites.metadata IS 'Additional site-specific configuration';

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

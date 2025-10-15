-- =====================================================
-- Clinical Trial Diary Database Schema
-- Target: Supabase (PostgreSQL 15+)
-- Compliance: FDA 21 CFR Part 11
-- Version: 1.0
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
-- AUDIT TABLE (Immutable Event Log)
-- =====================================================

-- Main audit table - INSERT ONLY, no updates or deletes
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

-- Prevent updates and deletes on audit table
CREATE RULE audit_no_update AS ON UPDATE TO record_audit DO INSTEAD NOTHING;
CREATE RULE audit_no_delete AS ON DELETE TO record_audit DO INSTEAD NOTHING;

COMMENT ON TABLE record_audit IS 'Immutable audit log - all changes recorded here (INSERT only)';
COMMENT ON COLUMN record_audit.audit_id IS 'Auto-incrementing audit ID establishing order';
COMMENT ON COLUMN record_audit.event_uuid IS 'Client-generated UUID for the diary event';
COMMENT ON COLUMN record_audit.parent_audit_id IS 'Links to previous version for change tracking';
COMMENT ON COLUMN record_audit.signature_hash IS 'Cryptographic signature for 21 CFR Part 11 compliance';
COMMENT ON COLUMN record_audit.device_info IS 'Device and platform information for ALCOA+ compliance (device_type, os, browser, app_version)';
COMMENT ON COLUMN record_audit.ip_address IS 'Source IP address for compliance tracking and security monitoring';
COMMENT ON COLUMN record_audit.session_id IS 'Session identifier for audit correlation and security tracking';

-- =====================================================
-- STATE TABLE (Current View)
-- =====================================================

-- Current state of diary entries - derived from audit table
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

COMMENT ON TABLE record_state IS 'Current state of diary entries - updated via triggers only';
COMMENT ON COLUMN record_state.version IS 'Number of modifications to this entry';
COMMENT ON COLUMN record_state.last_audit_id IS 'Reference to most recent audit entry';
COMMENT ON COLUMN record_state.is_deleted IS 'Soft delete flag';

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

-- Function to validate JSONB data schema
CREATE OR REPLACE FUNCTION validate_diary_data(data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check required fields exist
    IF NOT (data ? 'event_type') THEN
        RAISE EXCEPTION 'Missing required field: event_type';
    END IF;

    IF NOT (data ? 'date') THEN
        RAISE EXCEPTION 'Missing required field: date';
    END IF;

    -- Validate event_type is a string
    IF jsonb_typeof(data->'event_type') != 'string' THEN
        RAISE EXCEPTION 'event_type must be a string';
    END IF;

    -- Additional validation can be added here
    RETURN true;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_diary_data(JSONB) IS 'Validates diary entry data structure';

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

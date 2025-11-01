-- =====================================================
-- Indexes and Performance Optimizations
-- Optimized for clinical trial diary workload
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00018: Multi-Site Support Per Sponsor
--   REQ-p00038: Auditor Compliance Access
--   REQ-p00039: Administrator Break-Glass Access
--   REQ-d00011: Multi-Site Schema Implementation
--   REQ-d00024: Auditor Compliance Access RLS Implementation
--   REQ-d00025: Administrator Break-Glass RLS Implementation
--
-- PERFORMANCE OPTIMIZATION:
--   Indexes designed for multi-site clinical trial query patterns:
--   - Site-based data access (investigators viewing assigned sites)
--   - Patient-based queries (users viewing own diary entries)
--   - Time-series reporting (audit trail chronological access)
--
-- =====================================================

-- =====================================================
-- SITES TABLE INDEXES
-- =====================================================

CREATE INDEX idx_sites_active ON sites(is_active) WHERE is_active = true;
CREATE INDEX idx_sites_site_number ON sites(site_number);

-- =====================================================
-- EVENT STORE (record_audit) INDEXES
-- =====================================================

-- Primary lookup patterns
CREATE INDEX idx_audit_event_uuid ON record_audit(event_uuid);
CREATE INDEX idx_audit_patient_id ON record_audit(patient_id);
CREATE INDEX idx_audit_site_id ON record_audit(site_id);
CREATE INDEX idx_audit_created_by ON record_audit(created_by);
CREATE INDEX idx_audit_parent_id ON record_audit(parent_audit_id);

-- Time-based queries (common for reporting)
CREATE INDEX idx_audit_server_timestamp ON record_audit(server_timestamp DESC);
CREATE INDEX idx_audit_client_timestamp ON record_audit(client_timestamp DESC);

-- Composite indexes for common query patterns
CREATE INDEX idx_audit_patient_site ON record_audit(patient_id, site_id);
CREATE INDEX idx_audit_site_timestamp ON record_audit(site_id, server_timestamp DESC);
CREATE INDEX idx_audit_patient_timestamp ON record_audit(patient_id, server_timestamp DESC);

-- JSONB GIN index for flexible querying of diary data
CREATE INDEX idx_audit_data_gin ON record_audit USING GIN (data);

-- Index for conflict detection queries
CREATE INDEX idx_audit_event_parent ON record_audit(event_uuid, parent_audit_id);

-- Role-based query optimization
CREATE INDEX idx_audit_role_operation ON record_audit(role, operation);

-- Partial index for unresolved conflicts
CREATE INDEX idx_audit_conflicts ON record_audit(event_uuid)
    WHERE conflict_resolved = false;

-- Indexes for new ALCOA+ compliance fields (TICKET-001)
CREATE INDEX idx_audit_session_id ON record_audit(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX idx_audit_ip_address ON record_audit(ip_address) WHERE ip_address IS NOT NULL;
CREATE INDEX idx_audit_device_info_gin ON record_audit USING GIN (device_info) WHERE device_info IS NOT NULL;

-- =====================================================
-- READ MODEL (record_state) INDEXES
-- =====================================================

-- Foreign key indexes
CREATE INDEX idx_state_patient_id ON record_state(patient_id);
CREATE INDEX idx_state_site_id ON record_state(site_id);
CREATE INDEX idx_state_last_audit_id ON record_state(last_audit_id);

-- Common query patterns
CREATE INDEX idx_state_patient_site ON record_state(patient_id, site_id);
CREATE INDEX idx_state_site_updated ON record_state(site_id, updated_at DESC);

-- JSONB GIN index for current data
CREATE INDEX idx_state_data_gin ON record_state USING GIN (current_data);

-- Partial index for active records (not deleted)
CREATE INDEX idx_state_active ON record_state(patient_id, site_id)
    WHERE is_deleted = false;

-- Partial index for sync metadata queries
CREATE INDEX idx_state_sync_gin ON record_state USING GIN (sync_metadata)
    WHERE sync_metadata != '{}'::jsonb;

-- =====================================================
-- INVESTIGATOR_ANNOTATIONS TABLE INDEXES
-- =====================================================

CREATE INDEX idx_annotations_event_uuid ON investigator_annotations(event_uuid);
CREATE INDEX idx_annotations_investigator ON investigator_annotations(investigator_id);
CREATE INDEX idx_annotations_site ON investigator_annotations(site_id);
CREATE INDEX idx_annotations_created ON investigator_annotations(created_at DESC);

-- Composite for common queries
CREATE INDEX idx_annotations_site_created ON investigator_annotations(site_id, created_at DESC);
CREATE INDEX idx_annotations_investigator_created ON investigator_annotations(investigator_id, created_at DESC);

-- Partial index for unresolved annotations
CREATE INDEX idx_annotations_unresolved ON investigator_annotations(event_uuid, investigator_id)
    WHERE resolved = false;

-- Partial index for queries requiring response
CREATE INDEX idx_annotations_requires_response ON investigator_annotations(event_uuid)
    WHERE requires_response = true AND resolved = false;

-- Parent annotation tracking
CREATE INDEX idx_annotations_parent ON investigator_annotations(parent_annotation_id)
    WHERE parent_annotation_id IS NOT NULL;

-- =====================================================
-- USER_SITE_ASSIGNMENTS TABLE INDEXES
-- =====================================================

CREATE INDEX idx_user_site_patient ON user_site_assignments(patient_id);
CREATE INDEX idx_user_site_site ON user_site_assignments(site_id);
CREATE INDEX idx_user_site_enrolled ON user_site_assignments(enrolled_at DESC);

-- Partial index for active enrollments
CREATE INDEX idx_user_site_active ON user_site_assignments(patient_id, site_id)
    WHERE enrollment_status = 'ACTIVE';

-- Study patient ID lookup
CREATE INDEX idx_user_site_study_id ON user_site_assignments(study_patient_id);

-- =====================================================
-- INVESTIGATOR_SITE_ASSIGNMENTS TABLE INDEXES
-- =====================================================

CREATE INDEX idx_inv_site_investigator ON investigator_site_assignments(investigator_id);
CREATE INDEX idx_inv_site_site ON investigator_site_assignments(site_id);
CREATE INDEX idx_inv_site_assigned ON investigator_site_assignments(assigned_at DESC);

-- Partial index for active assignments
CREATE INDEX idx_inv_site_active ON investigator_site_assignments(investigator_id, site_id)
    WHERE is_active = true;

-- =====================================================
-- ANALYST_SITE_ASSIGNMENTS TABLE INDEXES
-- =====================================================

CREATE INDEX idx_analyst_site_analyst ON analyst_site_assignments(analyst_id);
CREATE INDEX idx_analyst_site_site ON analyst_site_assignments(site_id);
CREATE INDEX idx_analyst_site_assigned ON analyst_site_assignments(assigned_at DESC);

-- Partial index for active assignments
CREATE INDEX idx_analyst_site_active ON analyst_site_assignments(analyst_id, site_id)
    WHERE is_active = true;

-- =====================================================
-- SYNC_CONFLICTS TABLE INDEXES
-- =====================================================

CREATE INDEX idx_conflicts_event_uuid ON sync_conflicts(event_uuid);
CREATE INDEX idx_conflicts_patient ON sync_conflicts(patient_id);
CREATE INDEX idx_conflicts_site ON sync_conflicts(site_id);
CREATE INDEX idx_conflicts_detected ON sync_conflicts(conflict_detected_at DESC);

-- Partial index for unresolved conflicts
CREATE INDEX idx_conflicts_unresolved ON sync_conflicts(event_uuid, patient_id)
    WHERE resolved = false;

-- JSONB indexes for conflict data analysis
CREATE INDEX idx_conflicts_client_data ON sync_conflicts USING GIN (client_data);
CREATE INDEX idx_conflicts_server_data ON sync_conflicts USING GIN (server_data);

-- =====================================================
-- ADMIN_ACTION_LOG TABLE INDEXES
-- =====================================================

CREATE INDEX idx_admin_log_admin ON admin_action_log(admin_id);
CREATE INDEX idx_admin_log_action_type ON admin_action_log(action_type);
CREATE INDEX idx_admin_log_created ON admin_action_log(created_at DESC);
CREATE INDEX idx_admin_log_target ON admin_action_log(target_resource);

-- Partial index for pending reviews
CREATE INDEX idx_admin_log_pending_review ON admin_action_log(created_at DESC)
    WHERE requires_review = true AND approval_status = 'PENDING';

-- JSONB index for action details
CREATE INDEX idx_admin_log_details_gin ON admin_action_log USING GIN (action_details);

-- =====================================================
-- USER_PROFILES TABLE INDEXES
-- =====================================================

CREATE INDEX idx_profiles_email ON user_profiles(email);
CREATE INDEX idx_profiles_role ON user_profiles(role);
CREATE INDEX idx_profiles_last_login ON user_profiles(last_login_at DESC NULLS LAST);

-- Partial index for active users
CREATE INDEX idx_profiles_active ON user_profiles(role, email)
    WHERE is_active = true;

-- Partial index for users requiring 2FA
CREATE INDEX idx_profiles_2fa ON user_profiles(user_id)
    WHERE two_factor_enabled = true;

-- =====================================================
-- ROLE_CHANGE_LOG TABLE INDEXES
-- =====================================================

CREATE INDEX idx_role_changes_user ON role_change_log(user_id);
CREATE INDEX idx_role_changes_changed_by ON role_change_log(changed_by);
CREATE INDEX idx_role_changes_created ON role_change_log(created_at DESC);

-- Partial index for pending approvals
CREATE INDEX idx_role_changes_pending ON role_change_log(created_at DESC)
    WHERE approval_status = 'PENDING';

-- =====================================================
-- USER_SESSIONS TABLE INDEXES
-- =====================================================

CREATE INDEX idx_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at);
CREATE INDEX idx_sessions_last_activity ON user_sessions(last_activity_at DESC);

-- Partial index for active sessions
CREATE INDEX idx_sessions_active ON user_sessions(user_id, last_activity_at DESC)
    WHERE is_active = true AND expires_at > now();

-- =====================================================
-- TABLE PARTITIONING (for record_audit)
-- =====================================================

-- Create function to automatically create partitions
CREATE OR REPLACE FUNCTION create_audit_partition(partition_date DATE)
RETURNS void AS $$
DECLARE
    partition_name TEXT;
    start_date TEXT;
    end_date TEXT;
BEGIN
    partition_name := 'record_audit_' || to_char(partition_date, 'YYYY_MM');
    start_date := to_char(date_trunc('month', partition_date), 'YYYY-MM-DD');
    end_date := to_char(date_trunc('month', partition_date) + interval '1 month', 'YYYY-MM-DD');

    -- Check if partition already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = partition_name AND n.nspname = 'public'
    ) THEN
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF record_audit
             FOR VALUES FROM (%L) TO (%L)',
            partition_name, start_date, end_date
        );

        RAISE NOTICE 'Created partition: %', partition_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_audit_partition(DATE) IS 'Create monthly partition for event store (record_audit table) - Event Sourcing pattern supports time-based partitioning for scalability';

-- Note: To enable partitioning, you would need to:
-- 1. Recreate record_audit as a partitioned table
-- 2. This is commented out to avoid breaking the existing schema
-- 3. Uncomment and modify if you want to implement partitioning

/*
-- Example of converting to partitioned table (requires table recreation):
ALTER TABLE record_audit RENAME TO record_audit_old;

CREATE TABLE record_audit (
    LIKE record_audit_old INCLUDING ALL
) PARTITION BY RANGE (server_timestamp);

-- Create initial partitions
SELECT create_audit_partition(date_trunc('month', now())::date);
SELECT create_audit_partition(date_trunc('month', now() - interval '1 month')::date);
SELECT create_audit_partition(date_trunc('month', now() + interval '1 month')::date);

-- Migrate data (would need to be done carefully in production)
-- INSERT INTO record_audit SELECT * FROM record_audit_old;
*/

-- =====================================================
-- MATERIALIZED VIEWS FOR REPORTING
-- =====================================================

-- Daily summary by site
CREATE MATERIALIZED VIEW daily_site_summary AS
SELECT
    site_id,
    DATE(server_timestamp) as summary_date,
    COUNT(DISTINCT patient_id) as active_patients,
    COUNT(DISTINCT event_uuid) as total_events,
    COUNT(*) as total_changes,
    COUNT(*) FILTER (WHERE operation LIKE 'USER_%') as user_actions,
    COUNT(*) FILTER (WHERE operation LIKE 'INVESTIGATOR_%') as investigator_actions,
    MAX(server_timestamp) as last_activity
FROM record_audit
GROUP BY site_id, DATE(server_timestamp);

CREATE UNIQUE INDEX idx_daily_site_summary ON daily_site_summary(site_id, summary_date);

COMMENT ON MATERIALIZED VIEW daily_site_summary IS 'Daily activity summary by site - refresh periodically';

-- Patient activity summary
CREATE MATERIALIZED VIEW patient_activity_summary AS
SELECT
    patient_id,
    site_id,
    COUNT(DISTINCT event_uuid) as total_entries,
    MAX(server_timestamp) as last_entry_time,
    COUNT(*) FILTER (WHERE server_timestamp > now() - interval '7 days') as entries_last_7_days,
    COUNT(*) FILTER (WHERE server_timestamp > now() - interval '30 days') as entries_last_30_days
FROM record_audit
WHERE operation LIKE 'USER_%'
GROUP BY patient_id, site_id;

CREATE UNIQUE INDEX idx_patient_activity_summary ON patient_activity_summary(patient_id, site_id);

COMMENT ON MATERIALIZED VIEW patient_activity_summary IS 'Patient activity metrics - refresh periodically';

-- =====================================================
-- REFRESH FUNCTIONS FOR MATERIALIZED VIEWS
-- =====================================================

CREATE OR REPLACE FUNCTION refresh_reporting_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY daily_site_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY patient_activity_summary;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_reporting_views() IS 'Refresh all materialized views - schedule this to run periodically';

-- =====================================================
-- VACUUM AND ANALYZE SETTINGS
-- =====================================================

-- Configure autovacuum for high-churn tables
ALTER TABLE record_audit SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);

ALTER TABLE record_state SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

ALTER TABLE sync_conflicts SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- =====================================================
-- STATISTICS TARGETS
-- =====================================================

-- Increase statistics for commonly filtered columns
ALTER TABLE record_audit ALTER COLUMN patient_id SET STATISTICS 1000;
ALTER TABLE record_audit ALTER COLUMN site_id SET STATISTICS 1000;
ALTER TABLE record_audit ALTER COLUMN server_timestamp SET STATISTICS 1000;

ALTER TABLE record_state ALTER COLUMN patient_id SET STATISTICS 1000;
ALTER TABLE record_state ALTER COLUMN site_id SET STATISTICS 1000;

-- =====================================================
-- AUDITOR_EXPORT_LOG TABLE INDEXES (REQ-d00024)
-- =====================================================

CREATE INDEX idx_export_log_auditor ON auditor_export_log(auditor_id);
CREATE INDEX idx_export_log_timestamp ON auditor_export_log(export_timestamp DESC);
CREATE INDEX idx_export_log_case_id ON auditor_export_log(case_id);
CREATE INDEX idx_export_log_table ON auditor_export_log(table_name);

-- Composite index for auditor activity reports
CREATE INDEX idx_export_log_auditor_timestamp ON auditor_export_log(auditor_id, export_timestamp DESC);

-- JSONB index for filter queries
CREATE INDEX idx_export_log_filters_gin ON auditor_export_log USING GIN (filters)
    WHERE filters != '{}'::jsonb;

-- =====================================================
-- BREAK_GLASS_AUTHORIZATIONS TABLE INDEXES (REQ-d00025)
-- =====================================================

CREATE INDEX idx_breakglass_admin ON break_glass_authorizations(admin_id);
CREATE INDEX idx_breakglass_granted_at ON break_glass_authorizations(granted_at DESC);
CREATE INDEX idx_breakglass_expires_at ON break_glass_authorizations(expires_at);
CREATE INDEX idx_breakglass_granted_by ON break_glass_authorizations(granted_by);
CREATE INDEX idx_breakglass_ticket ON break_glass_authorizations(ticket_id);

-- Partial index for active (non-revoked, non-expired) authorizations
CREATE INDEX idx_breakglass_active ON break_glass_authorizations(admin_id, expires_at DESC)
    WHERE revoked_at IS NULL AND expires_at > now();

-- =====================================================
-- BREAK_GLASS_ACCESS_LOG TABLE INDEXES (REQ-d00025)
-- =====================================================

CREATE INDEX idx_breakglass_log_authorization ON break_glass_access_log(authorization_id);
CREATE INDEX idx_breakglass_log_admin ON break_glass_access_log(admin_id);
CREATE INDEX idx_breakglass_log_timestamp ON break_glass_access_log(access_timestamp DESC);
CREATE INDEX idx_breakglass_log_table ON break_glass_access_log(accessed_table);

-- Composite index for admin activity tracking
CREATE INDEX idx_breakglass_log_admin_timestamp ON break_glass_access_log(admin_id, access_timestamp DESC);

-- JSONB index for query details analysis
CREATE INDEX idx_breakglass_log_query_gin ON break_glass_access_log USING GIN (query_details)
    WHERE query_details IS NOT NULL;

-- =====================================================
-- SYSTEM_CONFIG TABLE INDEXES
-- =====================================================

-- Primary key already provides index on config_key
CREATE INDEX idx_config_modified_at ON system_config(last_modified_at DESC);
CREATE INDEX idx_config_modified_by ON system_config(last_modified_by);

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON INDEX idx_audit_data_gin IS 'GIN index for JSONB queries on event store (record_audit) data';
COMMENT ON INDEX idx_state_active IS 'Partial index for active (non-deleted) records in read model (record_state)';
COMMENT ON INDEX idx_annotations_unresolved IS 'Partial index for unresolved annotations requiring action';
COMMENT ON INDEX idx_breakglass_active IS 'Partial index for active break-glass authorizations (not revoked or expired)';
COMMENT ON INDEX idx_export_log_auditor_timestamp IS 'Composite index for auditor activity reports and compliance monitoring';

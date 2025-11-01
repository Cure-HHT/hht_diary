-- =====================================================
-- Row-Level Security (RLS) Policies
-- Implements access control based on user roles and site assignments
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00005: Role-Based Access Control
--   REQ-p00014: Least Privilege Access
--   REQ-p00015: Database-Level Access Enforcement
--   REQ-p00035: Patient Data Isolation
--   REQ-p00036: Investigator Site-Scoped Access
--   REQ-p00037: Investigator Annotation Restrictions
--   REQ-p00022: Analyst Read-Only Site-Scoped Access
--   REQ-p00023: Sponsor Global Read Access
--   REQ-p00038: Auditor Compliance Access
--   REQ-p00039: Administrator Break-Glass Access
--   REQ-p00040: Event Sourcing State Protection
--   REQ-o00007: Role-Based Permission Configuration
--   REQ-o00020: Patient Data Isolation Policy Deployment
--   REQ-o00021: Investigator Site-Scoped Access Policy Deployment
--   REQ-o00022: Investigator Annotation Access Policy Deployment
--   REQ-o00023: Analyst Read-Only Access Policy Deployment
--   REQ-o00024: Sponsor Global Access Policy Deployment
--   REQ-o00025: Auditor Compliance Access Policy Deployment
--   REQ-o00026: Administrator Access Policy Deployment
--   REQ-o00027: Event Sourcing State Protection Policy Deployment
--   REQ-d00019: Patient Data Isolation RLS Implementation
--   REQ-d00020: Investigator Site-Scoped Access RLS Implementation
--   REQ-d00021: Investigator Annotation RLS Implementation
--   REQ-d00022: Analyst Read-Only RLS Implementation
--   REQ-d00023: Sponsor Global Access RLS Implementation
--   REQ-d00024: Auditor Compliance Access RLS Implementation
--   REQ-d00025: Administrator Break-Glass RLS Implementation
--   REQ-d00026: Event Sourcing State Protection Implementation
--
-- MULTI-SPONSOR CONTEXT:
--   These RLS policies enforce SITE-LEVEL access control within a single sponsor.
--   SPONSOR-LEVEL isolation is enforced by separate database instances (REQ-p00003).
--   Each sponsor's database contains only their sites and users.
--
-- ROLE-BASED ACCESS:
--   - USER: Access only their own diary entries (REQ-p00035)
--   - INVESTIGATOR: Access data for assigned sites within this sponsor (REQ-p00036)
--   - ANALYST: Read-only access to assigned sites within this sponsor (REQ-p00022)
--   - SPONSOR: Read access to all data within this sponsor's database (REQ-p00023)
--   - AUDITOR: Read access to all data including audit logs (REQ-p00038)
--   - ADMIN: Full access with break-glass controls for PHI (REQ-p00039)
--
-- =====================================================

-- =====================================================
-- ENABLE RLS ON ALL TABLES
-- =====================================================

ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE record_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE record_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE investigator_annotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_site_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE investigator_site_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE analyst_site_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_conflicts ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_action_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE auditor_export_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE break_glass_authorizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE break_glass_access_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- SITES TABLE POLICIES
-- =====================================================

-- All authenticated users can view active sites
CREATE POLICY sites_select_all ON sites
    FOR SELECT
    TO authenticated
    USING (is_active = true);

-- Only admins can insert/update/delete sites
CREATE POLICY sites_admin_all ON sites
    FOR ALL
    TO authenticated
    USING (current_user_role() = 'ADMIN')
    WITH CHECK (current_user_role() = 'ADMIN');

-- =====================================================
-- RECORD_AUDIT TABLE POLICIES (Event Store)
-- =====================================================

-- Users can view their own events in the event store
CREATE POLICY audit_user_select ON record_audit
    FOR SELECT
    TO authenticated
    USING (
        patient_id = current_user_id()
        OR current_user_role() IN ('ADMIN', 'INVESTIGATOR', 'ANALYST')
    );

-- Users can insert their own events into the event store
CREATE POLICY audit_user_insert ON record_audit
    FOR INSERT
    TO authenticated
    WITH CHECK (
        patient_id = current_user_id()
        AND role = 'USER'
        AND created_by = current_user_id()
    );

-- Investigators can view event store entries for their assigned sites
CREATE POLICY audit_investigator_select ON record_audit
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

-- Investigators can insert events into event store (for transcription, annotations)
CREATE POLICY audit_investigator_insert ON record_audit
    FOR INSERT
    TO authenticated
    WITH CHECK (
        current_user_role() = 'INVESTIGATOR'
        AND created_by = current_user_id()
        AND role = 'INVESTIGATOR'
        AND site_id IN (
            SELECT site_id
            FROM investigator_site_assignments
            WHERE investigator_id = current_user_id()
            AND is_active = true
            AND access_level IN ('READ_WRITE', 'ADMIN')
        )
    );

-- Analysts can view event store entries for their assigned sites
CREATE POLICY audit_analyst_select ON record_audit
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'ANALYST'
        AND site_id IN (
            SELECT site_id
            FROM analyst_site_assignments
            WHERE analyst_id = current_user_id()
            AND is_active = true
        )
    );

-- Admins have full access to event store
CREATE POLICY audit_admin_all ON record_audit
    FOR ALL
    TO authenticated
    USING (current_user_role() = 'ADMIN')
    WITH CHECK (current_user_role() = 'ADMIN');

-- SPONSOR ROLE: Read-only access to all event store entries (REQ-d00023)
CREATE POLICY audit_sponsor_select ON record_audit
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'SPONSOR');

-- AUDITOR ROLE: Read-only access to all event store entries (REQ-d00024)
CREATE POLICY audit_auditor_select ON record_audit
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'AUDITOR');

-- =====================================================
-- RECORD_STATE TABLE POLICIES (Read Model)
-- =====================================================

-- Users can view their own records in the read model
CREATE POLICY state_user_select ON record_state
    FOR SELECT
    TO authenticated
    USING (
        patient_id = current_user_id()
        AND NOT is_deleted
    );

-- Users cannot directly insert/update/delete read model
-- (must go through event store)
-- These policies effectively prevent direct manipulation
CREATE POLICY state_user_insert ON record_state
    FOR INSERT
    TO authenticated
    WITH CHECK (false);  -- No direct inserts allowed

CREATE POLICY state_user_update ON record_state
    FOR UPDATE
    TO authenticated
    USING (false)  -- No direct updates allowed
    WITH CHECK (false);

CREATE POLICY state_user_delete ON record_state
    FOR DELETE
    TO authenticated
    USING (false);  -- No direct deletes allowed

-- Investigators can view read model records at their sites
CREATE POLICY state_investigator_select ON record_state
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

-- Analysts can view read model records at their sites (including deleted for analysis)
CREATE POLICY state_analyst_select ON record_state
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'ANALYST'
        AND site_id IN (
            SELECT site_id
            FROM analyst_site_assignments
            WHERE analyst_id = current_user_id()
            AND is_active = true
        )
    );

-- Admins have full read access
CREATE POLICY state_admin_select ON record_state
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'ADMIN');

-- ADMIN BREAK-GLASS: Full read access with break-glass authorization (REQ-d00025)
CREATE POLICY state_admin_breakglass ON record_state
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'ADMIN'
        AND has_break_glass_auth()
    );

-- SPONSOR ROLE: Read-only access to all current state (REQ-d00023)
CREATE POLICY state_sponsor_select ON record_state
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'SPONSOR');

-- AUDITOR ROLE: Read-only access to all current state including deleted (REQ-d00024)
CREATE POLICY state_auditor_select ON record_state
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'AUDITOR');

-- Backend service role can modify read model (for triggers)
CREATE POLICY state_service_all ON record_state
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- INVESTIGATOR_ANNOTATIONS TABLE POLICIES
-- =====================================================

-- Users can view annotations on their own records
CREATE POLICY annotations_user_select ON investigator_annotations
    FOR SELECT
    TO authenticated
    USING (
        event_uuid IN (
            SELECT event_uuid
            FROM record_state
            WHERE patient_id = current_user_id()
        )
    );

-- Investigators can view annotations at their sites
CREATE POLICY annotations_investigator_select ON investigator_annotations
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

-- Investigators can create annotations at their sites
CREATE POLICY annotations_investigator_insert ON investigator_annotations
    FOR INSERT
    TO authenticated
    WITH CHECK (
        current_user_role() = 'INVESTIGATOR'
        AND investigator_id = current_user_id()
        AND site_id IN (
            SELECT site_id
            FROM investigator_site_assignments
            WHERE investigator_id = current_user_id()
            AND is_active = true
            AND access_level IN ('READ_WRITE', 'ADMIN')
        )
    );

-- Investigators can update their own annotations
CREATE POLICY annotations_investigator_update ON investigator_annotations
    FOR UPDATE
    TO authenticated
    USING (
        current_user_role() = 'INVESTIGATOR'
        AND investigator_id = current_user_id()
    )
    WITH CHECK (
        current_user_role() = 'INVESTIGATOR'
        AND investigator_id = current_user_id()
    );

-- Admins have full access
CREATE POLICY annotations_admin_all ON investigator_annotations
    FOR ALL
    TO authenticated
    USING (current_user_role() = 'ADMIN')
    WITH CHECK (current_user_role() = 'ADMIN');

-- =====================================================
-- USER_SITE_ASSIGNMENTS TABLE POLICIES
-- =====================================================

-- Users can view their own site assignments
CREATE POLICY user_assignments_select ON user_site_assignments
    FOR SELECT
    TO authenticated
    USING (
        patient_id = current_user_id()
        OR current_user_role() IN ('ADMIN', 'INVESTIGATOR')
    );

-- Investigators can view assignments at their sites
CREATE POLICY user_assignments_investigator_select ON user_site_assignments
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

-- Only admins can insert/update/delete user assignments
CREATE POLICY user_assignments_admin_all ON user_site_assignments
    FOR ALL
    TO authenticated
    USING (current_user_role() = 'ADMIN')
    WITH CHECK (current_user_role() = 'ADMIN');

-- =====================================================
-- INVESTIGATOR_SITE_ASSIGNMENTS TABLE POLICIES
-- =====================================================

-- Investigators can view their own assignments
CREATE POLICY investigator_assignments_select ON investigator_site_assignments
    FOR SELECT
    TO authenticated
    USING (
        investigator_id = current_user_id()
        OR current_user_role() = 'ADMIN'
    );

-- Only admins can manage investigator assignments
CREATE POLICY investigator_assignments_admin_all ON investigator_site_assignments
    FOR ALL
    TO authenticated
    USING (current_user_role() = 'ADMIN')
    WITH CHECK (current_user_role() = 'ADMIN');

-- =====================================================
-- ANALYST_SITE_ASSIGNMENTS TABLE POLICIES
-- =====================================================

-- Analysts can view their own assignments
CREATE POLICY analyst_assignments_select ON analyst_site_assignments
    FOR SELECT
    TO authenticated
    USING (
        analyst_id = current_user_id()
        OR current_user_role() = 'ADMIN'
    );

-- Only admins can manage analyst assignments
CREATE POLICY analyst_assignments_admin_all ON analyst_site_assignments
    FOR ALL
    TO authenticated
    USING (current_user_role() = 'ADMIN')
    WITH CHECK (current_user_role() = 'ADMIN');

-- =====================================================
-- SYNC_CONFLICTS TABLE POLICIES
-- =====================================================

-- Users can view their own conflicts
CREATE POLICY conflicts_user_select ON sync_conflicts
    FOR SELECT
    TO authenticated
    USING (patient_id = current_user_id());

-- Users can update resolution of their own conflicts
CREATE POLICY conflicts_user_update ON sync_conflicts
    FOR UPDATE
    TO authenticated
    USING (patient_id = current_user_id())
    WITH CHECK (patient_id = current_user_id());

-- Investigators can view conflicts at their sites
CREATE POLICY conflicts_investigator_select ON sync_conflicts
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

-- Admins have full access
CREATE POLICY conflicts_admin_all ON sync_conflicts
    FOR ALL
    TO authenticated
    USING (current_user_role() = 'ADMIN')
    WITH CHECK (current_user_role() = 'ADMIN');

-- Service role can insert conflicts (from triggers)
CREATE POLICY conflicts_service_insert ON sync_conflicts
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- =====================================================
-- ADMIN_ACTION_LOG TABLE POLICIES
-- =====================================================

-- Only admins can view and insert admin action logs
CREATE POLICY admin_log_select ON admin_action_log
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'ADMIN');

CREATE POLICY admin_log_insert ON admin_action_log
    FOR INSERT
    TO authenticated
    WITH CHECK (
        current_user_role() = 'ADMIN'
        AND admin_id = current_user_id()
    );

-- Investigators can view admin actions requiring review
CREATE POLICY admin_log_investigator_select ON admin_action_log
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'INVESTIGATOR'
        AND requires_review = true
    );

-- Investigators can update review status
CREATE POLICY admin_log_investigator_review ON admin_action_log
    FOR UPDATE
    TO authenticated
    USING (
        current_user_role() = 'INVESTIGATOR'
        AND requires_review = true
    )
    WITH CHECK (
        current_user_role() = 'INVESTIGATOR'
        AND reviewed_by = current_user_id()
    );

-- AUDITOR ROLE: Can view admin action log (REQ-d00024)
CREATE POLICY admin_log_auditor_select ON admin_action_log
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'AUDITOR');

-- SPONSOR ROLE: Can view admin action log (REQ-d00023)
CREATE POLICY admin_log_sponsor_select ON admin_action_log
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'SPONSOR');

-- =====================================================
-- AUDITOR_EXPORT_LOG TABLE POLICIES (REQ-d00024)
-- =====================================================

-- AUDITOR ROLE: Can view and insert export logs
CREATE POLICY export_log_auditor_select ON auditor_export_log
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'AUDITOR'
        AND auditor_id = current_user_id()
    );

CREATE POLICY export_log_auditor_insert ON auditor_export_log
    FOR INSERT
    TO authenticated
    WITH CHECK (
        current_user_role() = 'AUDITOR'
        AND auditor_id = current_user_id()
    );

-- ADMIN ROLE: Can view all export logs
CREATE POLICY export_log_admin_select ON auditor_export_log
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'ADMIN');

-- =====================================================
-- BREAK_GLASS_AUTHORIZATIONS TABLE POLICIES (REQ-d00025)
-- =====================================================

-- ADMIN ROLE: Can view their own authorizations
CREATE POLICY breakglass_admin_select ON break_glass_authorizations
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'ADMIN'
        AND (admin_id = current_user_id() OR granted_by = current_user_id())
    );

-- ADMIN ROLE: Can insert authorizations (granting to others)
CREATE POLICY breakglass_admin_insert ON break_glass_authorizations
    FOR INSERT
    TO authenticated
    WITH CHECK (
        current_user_role() = 'ADMIN'
        AND granted_by = current_user_id()
    );

-- ADMIN ROLE: Can revoke authorizations they granted
CREATE POLICY breakglass_admin_update ON break_glass_authorizations
    FOR UPDATE
    TO authenticated
    USING (
        current_user_role() = 'ADMIN'
        AND granted_by = current_user_id()
    )
    WITH CHECK (
        current_user_role() = 'ADMIN'
        AND granted_by = current_user_id()
    );

-- AUDITOR ROLE: Can view all authorizations (REQ-d00024)
CREATE POLICY breakglass_auditor_select ON break_glass_authorizations
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'AUDITOR');

-- =====================================================
-- BREAK_GLASS_ACCESS_LOG TABLE POLICIES (REQ-d00025)
-- =====================================================

-- ADMIN ROLE: Can view their own access log
CREATE POLICY breakglass_log_admin_select ON break_glass_access_log
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'ADMIN'
        AND admin_id = current_user_id()
    );

-- Service role can insert access logs (from triggers)
CREATE POLICY breakglass_log_service_insert ON break_glass_access_log
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- AUDITOR ROLE: Can view all access logs (REQ-d00024)
CREATE POLICY breakglass_log_auditor_select ON break_glass_access_log
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'AUDITOR');

-- =====================================================
-- SYSTEM_CONFIG TABLE POLICIES
-- =====================================================

-- ADMIN ROLE: Can view and modify system configuration
CREATE POLICY config_admin_all ON system_config
    FOR ALL
    TO authenticated
    USING (current_user_role() = 'ADMIN')
    WITH CHECK (current_user_role() = 'ADMIN');

-- AUDITOR ROLE: Can view system configuration (REQ-d00024)
CREATE POLICY config_auditor_select ON system_config
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'AUDITOR');

-- =====================================================
-- GRANT BASIC PERMISSIONS
-- =====================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;

-- Grant select on all tables to authenticated users (RLS will filter)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;

-- Grant insert on event store to authenticated users (RLS will filter)
GRANT INSERT ON record_audit TO authenticated;

-- Grant insert/update on annotations to authenticated users (RLS will filter)
GRANT INSERT, UPDATE ON investigator_annotations TO authenticated;

-- Grant update on conflicts to authenticated users (RLS will filter)
GRANT UPDATE ON sync_conflicts TO authenticated;

-- Grant insert on admin action log to authenticated users (RLS will filter)
GRANT INSERT, UPDATE ON admin_action_log TO authenticated;

-- Service role needs full access for triggers
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

-- Grant sequence usage
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON POLICY audit_user_select ON record_audit IS 'Users can view their own events in event store';
COMMENT ON POLICY audit_investigator_select ON record_audit IS 'Investigators can view event store entries at assigned sites';
COMMENT ON POLICY state_user_select ON record_state IS 'Users can view their own entries in read model';
COMMENT ON POLICY state_investigator_select ON record_state IS 'Investigators can view read model entries at assigned sites';
COMMENT ON POLICY annotations_user_select ON investigator_annotations IS 'Users can see annotations on their entries';
COMMENT ON POLICY annotations_investigator_insert ON investigator_annotations IS 'Investigators can create annotations at their sites';

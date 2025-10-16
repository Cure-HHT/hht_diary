-- =====================================================
-- Row-Level Security (RLS) Policies
-- Implements access control based on user roles and site assignments
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
-- RECORD_AUDIT TABLE POLICIES
-- =====================================================

-- Users can view their own audit entries
CREATE POLICY audit_user_select ON record_audit
    FOR SELECT
    TO authenticated
    USING (
        patient_id = current_user_id()
        OR current_user_role() IN ('ADMIN', 'INVESTIGATOR', 'ANALYST')
    );

-- Users can insert their own audit entries
CREATE POLICY audit_user_insert ON record_audit
    FOR INSERT
    TO authenticated
    WITH CHECK (
        patient_id = current_user_id()
        AND role = 'USER'
        AND created_by = current_user_id()
    );

-- Investigators can view audit entries for their assigned sites
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

-- Investigators can insert audit entries (for transcription, annotations)
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

-- Analysts can view audit entries for their assigned sites
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

-- =====================================================
-- RECORD_STATE TABLE POLICIES
-- =====================================================

-- Users can view and modify their own records
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

-- Investigators can view records at their sites
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

-- Analysts can view records at their sites (including deleted for analysis)
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

COMMENT ON POLICY audit_user_select ON record_audit IS 'Users can view their own audit entries';
COMMENT ON POLICY audit_investigator_select ON record_audit IS 'Investigators can view audit at assigned sites';
COMMENT ON POLICY state_user_select ON record_state IS 'Users can view their own diary entries';
COMMENT ON POLICY state_investigator_select ON record_state IS 'Investigators can view entries at assigned sites';
COMMENT ON POLICY annotations_user_select ON investigator_annotations IS 'Users can see annotations on their entries';
COMMENT ON POLICY annotations_investigator_insert ON investigator_annotations IS 'Investigators can create annotations at their sites';

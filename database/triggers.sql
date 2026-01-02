-- =====================================================
-- Event Sourcing Triggers
-- Event Store → Read Model Synchronization (CQRS Pattern)
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
--   REQ-p00013: Complete Change History
--   REQ-p00039: Administrator Break-Glass Access
--   REQ-p00040: Event Sourcing State Protection
--   REQ-d00025: Administrator Break-Glass RLS Implementation
--   REQ-d00026: Event Sourcing State Protection Implementation
--
-- EVENT SOURCING PATTERN:
--   - record_audit (event store): Immutable source of truth
--   - record_state (read model): Derived state for queries
--   - Triggers automatically update read model from event store
--   - Direct writes to record_state blocked in production (REQ-p00004)
--
-- COMPLIANCE:
--   Ensures all data changes flow through immutable audit trail,
--   maintaining complete change history for FDA 21 CFR Part 11.
--
-- =====================================================

-- =====================================================
-- TRIGGER: Auto-update read model from event store
-- =====================================================

-- Function to update read model (record_state) when new event is written to event store (record_audit)
CREATE OR REPLACE FUNCTION update_record_state_from_audit()
RETURNS TRIGGER AS $$
DECLARE
    current_version INTEGER;
BEGIN
    -- Check if this is a deletion operation
    IF NEW.operation LIKE '%DELETE%' THEN
        -- Soft delete: mark as deleted but keep the record
        UPDATE record_state
        SET
            is_deleted = true,
            version = version + 1,
            last_audit_id = NEW.audit_id,
            updated_at = now()
        WHERE event_uuid = NEW.event_uuid;

        IF NOT FOUND THEN
            -- If record doesn't exist, this is an error
            RAISE EXCEPTION 'Cannot delete non-existent record: %', NEW.event_uuid;
        END IF;
    ELSE
        -- Insert or update the read model
        INSERT INTO record_state (
            event_uuid,
            patient_id,
            site_id,
            current_data,
            version,
            last_audit_id,
            is_deleted,
            created_at,
            updated_at
        )
        VALUES (
            NEW.event_uuid,
            NEW.patient_id,
            NEW.site_id,
            NEW.data,
            1,
            NEW.audit_id,
            false,
            NEW.server_timestamp,
            NEW.server_timestamp
        )
        ON CONFLICT (event_uuid) DO UPDATE
        SET
            current_data = NEW.data,
            version = record_state.version + 1,
            last_audit_id = NEW.audit_id,
            is_deleted = false,
            updated_at = NEW.server_timestamp;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION update_record_state_from_audit() IS 'Event Sourcing: Automatically updates read model (record_state) when events are written to event store (record_audit)';

-- Apply trigger to event store
CREATE TRIGGER sync_state_from_audit
    AFTER INSERT ON record_audit
    FOR EACH ROW
    EXECUTE FUNCTION update_record_state_from_audit();

-- =====================================================
-- TRIGGER: Validate event before writing to event store
-- =====================================================

CREATE OR REPLACE FUNCTION validate_audit_entry()
RETURNS TRIGGER AS $$
BEGIN
    -- Validate JSONB data structure
    PERFORM validate_diary_data(NEW.data);

    -- Ensure patient is enrolled at the site
    IF NOT EXISTS (
        SELECT 1 FROM user_site_assignments
        WHERE patient_id = NEW.patient_id
        AND site_id = NEW.site_id
        AND enrollment_status = 'ACTIVE'
    ) THEN
        -- Only enforce for USER operations (admin can create for any site)
        IF NEW.role = 'USER' THEN
            RAISE EXCEPTION 'Patient % is not enrolled at site %', NEW.patient_id, NEW.site_id;
        END IF;
    END IF;

    -- Validate parent_audit_id exists if provided
    IF NEW.parent_audit_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM record_audit WHERE audit_id = NEW.parent_audit_id) THEN
            RAISE EXCEPTION 'Invalid parent_audit_id: %', NEW.parent_audit_id;
        END IF;

        -- Check for conflicts: if parent_audit_id doesn't match current state
        IF EXISTS (
            SELECT 1 FROM record_state
            WHERE event_uuid = NEW.event_uuid
            AND last_audit_id != NEW.parent_audit_id
        ) THEN
            -- Create conflict record
            INSERT INTO sync_conflicts (
                event_uuid,
                patient_id,
                site_id,
                client_version,
                server_version,
                client_data,
                server_data
            )
            SELECT
                NEW.event_uuid,
                NEW.patient_id,
                NEW.site_id,
                (SELECT COUNT(*) FROM record_audit WHERE event_uuid = NEW.event_uuid AND audit_id <= NEW.parent_audit_id),
                rs.version,
                NEW.data,
                rs.current_data
            FROM record_state rs
            WHERE rs.event_uuid = NEW.event_uuid;

            -- For non-conflict-resolved entries, reject
            IF NOT COALESCE(NEW.conflict_resolved, false) THEN
                RAISE EXCEPTION 'Conflict detected for event %. Client must resolve before update.', NEW.event_uuid
                    USING HINT = 'Check sync_conflicts table for details';
            END IF;
        END IF;
    END IF;

    -- Ensure change_reason is provided
    IF NEW.change_reason IS NULL OR trim(NEW.change_reason) = '' THEN
        RAISE EXCEPTION 'change_reason is required for all events in event store';
    END IF;

    -- Set server timestamp if not already set
    IF NEW.server_timestamp IS NULL THEN
        NEW.server_timestamp = now();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_audit_entry() IS 'Event Sourcing: Validates events before writing to event store (record_audit). Enforces data integrity, enrollment checks, conflict detection, and compliance requirements.';

-- Apply validation trigger
CREATE TRIGGER validate_audit_before_insert
    BEFORE INSERT ON record_audit
    FOR EACH ROW
    EXECUTE FUNCTION validate_audit_entry();

-- =====================================================
-- TRIGGER: Log admin actions
-- =====================================================

CREATE OR REPLACE FUNCTION log_admin_action()
RETURNS BOOLEAN AS $$
DECLARE
    v_user_role TEXT;
BEGIN
    v_user_role := current_user_role();

    -- If user is admin, require logging (this is a stub - actual logging done in application layer)
    IF v_user_role = 'ADMIN' THEN
        -- Admin actions are allowed but should be logged
        -- In practice, the application layer will create admin_action_log entries
        RETURN true;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION log_admin_action() IS 'Helper function for admin action logging in RLS policies';

-- =====================================================
-- TRIGGER: Prevent direct read model modifications
-- =====================================================

-- Event Sourcing enforcement: Prevents direct modifications to read model
-- Read model (record_state) should ONLY be updated via event store triggers

CREATE OR REPLACE FUNCTION prevent_direct_state_modification()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if this is being called from the audit trigger
    -- We allow updates from the trigger function itself
    IF current_setting('app.updating_from_audit', true) = 'true' THEN
        RETURN NEW;
    END IF;

    -- Otherwise, reject direct modifications
    RAISE EXCEPTION 'Direct modification of read model (record_state) is not allowed. Write events to event store (record_audit) instead.'
        USING HINT = 'Event Sourcing pattern: All data changes must go through the event store';
END;
$$ LANGUAGE plpgsql;

-- Note: We'll modify the audit trigger to set the session variable
CREATE OR REPLACE FUNCTION update_record_state_from_audit_v2()
RETURNS TRIGGER AS $$
DECLARE
    current_version INTEGER;
BEGIN
    -- Set session variable to allow read model updates from event store trigger
    PERFORM set_config('app.updating_from_audit', 'true', true);

    -- Check if this is a deletion operation
    IF NEW.operation LIKE '%DELETE%' THEN
        -- Soft delete: mark as deleted but keep the record
        UPDATE record_state
        SET
            is_deleted = true,
            version = version + 1,
            last_audit_id = NEW.audit_id,
            updated_at = now()
        WHERE event_uuid = NEW.event_uuid;

        IF NOT FOUND THEN
            -- If record doesn't exist, this is an error
            RAISE EXCEPTION 'Cannot delete non-existent record: %', NEW.event_uuid;
        END IF;
    ELSE
        -- Insert or update the read model
        INSERT INTO record_state (
            event_uuid,
            patient_id,
            site_id,
            current_data,
            version,
            last_audit_id,
            is_deleted,
            created_at,
            updated_at
        )
        VALUES (
            NEW.event_uuid,
            NEW.patient_id,
            NEW.site_id,
            NEW.data,
            1,
            NEW.audit_id,
            false,
            NEW.server_timestamp,
            NEW.server_timestamp
        )
        ON CONFLICT (event_uuid) DO UPDATE
        SET
            current_data = NEW.data,
            version = record_state.version + 1,
            last_audit_id = NEW.audit_id,
            is_deleted = false,
            updated_at = NEW.server_timestamp;
    END IF;

    -- Reset session variable
    PERFORM set_config('app.updating_from_audit', 'false', true);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Replace the original trigger with the new version
DROP TRIGGER IF EXISTS sync_state_from_audit ON record_audit;
CREATE TRIGGER sync_state_from_audit
    AFTER INSERT ON record_audit
    FOR EACH ROW
    EXECUTE FUNCTION update_record_state_from_audit_v2();

-- =====================================================
-- TRIGGER: Prevent Direct State Modifications (Production Only)
-- =====================================================
--
-- This trigger enforces that record_state can only be modified
-- through the audit trail system. It's disabled in development
-- for testing convenience but MUST be enabled in production.
--
-- TICKET-007: Environment-aware state modification prevention
--

DO $$
BEGIN
    -- Check if we're in production environment
    IF current_setting('app.environment', true) = 'production' THEN
        -- Enable state modification prevention in production
        CREATE TRIGGER prevent_direct_state_update
            BEFORE UPDATE ON record_state
            FOR EACH ROW
            EXECUTE FUNCTION prevent_direct_state_modification();

        CREATE TRIGGER prevent_direct_state_insert
            BEFORE INSERT ON record_state
            FOR EACH ROW
            EXECUTE FUNCTION prevent_direct_state_modification();

        RAISE NOTICE 'Production mode: State modification prevention ENABLED';
    ELSE
        RAISE NOTICE 'Development mode: State modification prevention DISABLED';
        RAISE NOTICE 'Direct state modifications are allowed for testing';
    END IF;
END $$;

-- =====================================================
-- TRIGGER: Auto-resolve conflicts when marked
-- =====================================================

CREATE OR REPLACE FUNCTION auto_resolve_conflict()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.resolved = true AND OLD.resolved = false THEN
        NEW.resolved_at = now();

        -- If resolution strategy and data are provided, create new audit entry
        IF NEW.resolution_strategy IS NOT NULL AND NEW.resolved_data IS NOT NULL THEN
            -- The application layer should handle creating the new audit entry
            -- This trigger just marks the conflict as resolved
            NULL;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_resolve_conflict_trigger
    BEFORE UPDATE ON sync_conflicts
    FOR EACH ROW
    WHEN (NEW.resolved = true)
    EXECUTE FUNCTION auto_resolve_conflict();

-- =====================================================
-- TRIGGER: Auto-update annotation timestamps
-- =====================================================

CREATE OR REPLACE FUNCTION update_annotation_resolved()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.resolved = true AND OLD.resolved = false THEN
        NEW.resolved_at = now();

        -- Get the resolver from current user if not set
        IF NEW.resolved_by IS NULL THEN
            NEW.resolved_by = current_user_id();
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_annotation_resolved_trigger
    BEFORE UPDATE ON investigator_annotations
    FOR EACH ROW
    WHEN (NEW.resolved = true)
    EXECUTE FUNCTION update_annotation_resolved();

-- =====================================================
-- TRIGGER: Validate site assignments
-- =====================================================

CREATE OR REPLACE FUNCTION validate_site_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure site exists and is active
    IF NOT EXISTS (SELECT 1 FROM sites WHERE site_id = NEW.site_id AND is_active = true) THEN
        RAISE EXCEPTION 'Cannot assign to inactive or non-existent site: %', NEW.site_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_user_site_assignment
    BEFORE INSERT OR UPDATE ON user_site_assignments
    FOR EACH ROW
    EXECUTE FUNCTION validate_site_assignment();

CREATE TRIGGER validate_investigator_site_assignment
    BEFORE INSERT OR UPDATE ON investigator_site_assignments
    FOR EACH ROW
    EXECUTE FUNCTION validate_site_assignment();

CREATE TRIGGER validate_analyst_site_assignment
    BEFORE INSERT OR UPDATE ON analyst_site_assignments
    FOR EACH ROW
    EXECUTE FUNCTION validate_site_assignment();

-- =====================================================
-- TRIGGER: Break-Glass Access Logging (REQ-d00025)
-- =====================================================

-- Function to log break-glass access to sensitive tables
CREATE OR REPLACE FUNCTION log_break_glass_access()
RETURNS TRIGGER AS $$
DECLARE
    v_authorization_id BIGINT;
    v_admin_id TEXT;
    v_operation TEXT;
BEGIN
    -- Get current user ID and role
    v_admin_id := current_user_id();

    -- Only log if user has ADMIN role and active break-glass authorization
    IF current_user_role() = 'ADMIN' AND has_break_glass_auth() THEN
        -- Get the active authorization ID
        SELECT authorization_id INTO v_authorization_id
        FROM break_glass_authorizations
        WHERE admin_id = v_admin_id
          AND revoked_at IS NULL
          AND expires_at > now()
        ORDER BY granted_at DESC
        LIMIT 1;

        -- Determine operation type
        v_operation := TG_OP; -- INSERT, UPDATE, DELETE, or SELECT (if supported)

        -- Log the access
        INSERT INTO break_glass_access_log (
            authorization_id,
            admin_id,
            accessed_table,
            accessed_record_id,
            operation,
            query_details,
            ip_address,
            session_id
        ) VALUES (
            v_authorization_id,
            v_admin_id,
            TG_TABLE_NAME,
            CASE
                WHEN TG_OP = 'DELETE' THEN OLD.event_uuid::TEXT
                ELSE NEW.event_uuid::TEXT
            END,
            v_operation,
            jsonb_build_object(
                'table', TG_TABLE_NAME,
                'operation', TG_OP,
                'trigger_name', TG_NAME
            ),
            inet_client_addr(),
            current_setting('request.jwt.claims', true)::json->>'session_id'
        );
    END IF;

    -- Always return the appropriate record to allow the operation to proceed
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION log_break_glass_access() IS 'Logs all break-glass access to sensitive tables for compliance monitoring (REQ-p00039, REQ-d00025)';

-- Apply break-glass logging to sensitive tables
-- Note: These triggers log access when break-glass authorization is active

CREATE TRIGGER log_breakglass_state_access
    AFTER INSERT OR UPDATE OR DELETE ON record_state
    FOR EACH ROW
    EXECUTE FUNCTION log_break_glass_access();

CREATE TRIGGER log_breakglass_audit_access
    AFTER INSERT ON record_audit
    FOR EACH ROW
    EXECUTE FUNCTION log_break_glass_access();

-- =====================================================
-- TRIGGER: Expire Break-Glass Authorizations
-- =====================================================

-- Function to automatically mark expired authorizations
CREATE OR REPLACE FUNCTION check_authorization_expiry()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if authorization has expired
    IF NEW.expires_at <= now() AND NEW.revoked_at IS NULL THEN
        RAISE WARNING 'Break-glass authorization % has expired', NEW.authorization_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_authorization_expiry() IS 'Validates break-glass authorization expiry on access (REQ-d00025)';

-- Trigger to check expiry on SELECT (via RLS policy evaluation)
-- Note: This is more for monitoring; actual expiry enforcement happens in has_break_glass_auth() function

-- =====================================================
-- TRIGGER: Log Auditor Exports
-- =====================================================

-- Function to validate and complete export log entries
CREATE OR REPLACE FUNCTION complete_export_log()
RETURNS TRIGGER AS $$
BEGIN
    -- When completed_at is set, validate that export was successful
    IF NEW.completed_at IS NOT NULL AND OLD.completed_at IS NULL THEN
        -- Ensure record_count is set
        IF NEW.record_count = 0 THEN
            RAISE WARNING 'Export % completed with 0 records', NEW.export_id;
        END IF;

        -- Log the completion
        RAISE NOTICE 'Export % completed: % records from % by auditor %',
            NEW.export_id, NEW.record_count, NEW.table_name, NEW.auditor_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION complete_export_log() IS 'Validates export completion and logs activity (REQ-p00038, REQ-d00024)';

CREATE TRIGGER validate_export_completion
    BEFORE UPDATE ON auditor_export_log
    FOR EACH ROW
    WHEN (NEW.completed_at IS NOT NULL)
    EXECUTE FUNCTION complete_export_log();

-- =====================================================
-- Event Sourcing Triggers
-- Event Store → Read Model Synchronization (CQRS Pattern)
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
    current_role TEXT;
BEGIN
    current_role := current_user_role();

    -- If user is admin, require logging (this is a stub - actual logging done in application layer)
    IF current_role = 'ADMIN' THEN
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

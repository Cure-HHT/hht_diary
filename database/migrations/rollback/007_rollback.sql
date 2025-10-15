-- =====================================================
-- Rollback: 007_enable_state_protection
-- Description: Remove environment-aware state protection triggers
-- Ticket: TICKET-007
-- Date: 2025-10-14
-- =====================================================

-- Remove triggers
DROP TRIGGER IF EXISTS prevent_direct_state_update ON record_state;
DROP TRIGGER IF EXISTS prevent_direct_state_insert ON record_state;

-- Verify rollback
DO $$
DECLARE
    v_trigger_count INTEGER;
BEGIN
    -- Count remaining protection triggers
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger
    WHERE tgname LIKE 'prevent_direct_state%';

    IF v_trigger_count > 0 THEN
        RAISE EXCEPTION 'Rollback failed: % triggers still exist', v_trigger_count;
    END IF;

    RAISE NOTICE '✓ Rollback 007 completed successfully';
    RAISE NOTICE '✓ All state protection triggers removed';
    RAISE NOTICE 'Note: Direct state modifications are now allowed in all environments';
    RAISE NOTICE 'To restore: Rerun migration 007_enable_state_protection.sql';
END $$;

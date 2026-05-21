-- =====================================================
-- Migration: Create rave_sync_lockout state table
-- Number: 013
-- Date: 2026-05-19
-- Description: Persistent state for the Rave sync lockout feature
--   (CUR-1361). Single-row table per env. Tracks consecutive
--   auth failures, hard-lockout marker, last-failure timestamp
--   (drives cooldown), and last-unwedge audit info.
--
--   See spec/prd-rave-sync.md for the normative REQs (DIARY-OPS-rave-sync-*,
--   DIARY-DEV-rave-auth-failure-classification).
-- =====================================================

set lock_timeout = '2s';
set statement_timeout = '10s';

BEGIN;

-- Implements: DIARY-OPS-rave-sync-hard-lockout/A+C, DIARY-OPS-rave-sync-cooldown/B
CREATE TABLE rave_sync_lockout (
    id                          smallint    PRIMARY KEY CHECK (id = 1),
    consecutive_auth_failures   integer     NOT NULL DEFAULT 0
                                            CHECK (consecutive_auth_failures >= 0),
    locked_at                   timestamptz NULL,
    last_failure_at             timestamptz NULL,
    last_failure_reason_code    text        NULL,
    last_success_at             timestamptz NULL,
    last_unwedged_by_user_id    uuid        NULL REFERENCES portal_users(id),
    last_unwedged_at            timestamptz NULL,
    updated_at                  timestamptz NOT NULL DEFAULT now()
);

-- Singleton seed row so UPDATEs against id=1 always hit
INSERT INTO rave_sync_lockout (id) VALUES (1);

COMMENT ON TABLE rave_sync_lockout IS
  'Live decision state for Rave sync lockout (CUR-1361). Single row, id=1.';
COMMENT ON COLUMN rave_sync_lockout.locked_at IS
  'Non-NULL = hard lockout. Cleared only by the Unwedge endpoint.';
COMMENT ON COLUMN rave_sync_lockout.last_failure_at IS
  'Drives soft cooldown: now() - last_failure_at < RAVE_AUTH_COOLDOWN_HOURS = paused.';

COMMIT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM rave_sync_lockout WHERE id = 1) THEN
        RAISE EXCEPTION 'rave_sync_lockout seed row missing';
    END IF;
    RAISE NOTICE 'Migration 013 verified successfully';
END $$;

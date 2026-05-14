-- =====================================================
-- Migration: Create notifications table for envelope-pattern push delivery
-- Number: 011
-- Date: 2026-05-08
-- Description: Phase 1B introduces an outbox/envelope pattern. Server
--   writes a row to `notifications` BEFORE dispatching FCM; the row is
--   the durable record (status pending → sent → delivered | failed),
--   the audit trail (replaces the FCM_NOTIFICATION admin_action_log
--   row from migration 010), and the polling source (mobile app fetches
--   /api/v1/notifications?since=<cursor> to reconcile state).
--
--   Compliance / REQ-d00194: payload column never carries PHI — it is
--   structured opaque IDs. PayloadGuard runs before any insert in the
--   `comms` package's OutboxWriter.
--
--   Mobile fetches via the EnvelopeFetcher. The fetch handler stamps
--   delivered_at idempotently on first read (REQ-d00195) — fetching IS
--   acknowledgement; no separate /ack endpoint.
--
--   (Linear: CUR-1311)
-- Dependencies: Requires the `patients` table from earlier migrations.
-- Reference: docs/comms-implementation-plan.md (Phase 1B), spec/dev-notifications.md
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-d00193: FCM Dispatch via cure-hht-admin Project
--   REQ-d00194: PHI-Safe FCM Payload
--   REQ-d00195: Mobile Notifications Polling
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
-- =====================================================

-- =====================================================
-- SAFE MIGRATION STRATEGY
-- =====================================================
-- Greenfield table — no existing data, no locks on production traffic.
-- The CREATE TYPE / CREATE TABLE / CREATE INDEX statements are wrapped
-- in a single transaction so a partial failure rolls back cleanly.
--
-- The RLS policy reads `app.current_patient_id`, a session variable
-- the application sets via Database.executeWithContext when run with
-- UserContext.patient(patientId). Service-role connections bypass
-- RLS via the BYPASSRLS attribute granted to `service_role` in the
-- existing roles config.
-- =====================================================

set lock_timeout = '2s';
set statement_timeout = '10s';

BEGIN;

-- Step 1: Notification type enum — the 3-value protocol vocabulary.
-- Sub-actions (questionnaire_sent vs. _deleted vs. _finalized;
-- disconnect vs. reconnect) live in the row's payload->>'action'.
CREATE TYPE notification_type AS ENUM (
  'questionnaire_update',
  'patient_status_update',
  'reminder'
);

-- Step 2: Notifications table.
CREATE TABLE notifications (
    notification_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id        TEXT NOT NULL
                      REFERENCES patients(patient_id) ON DELETE CASCADE,
    notification_type notification_type NOT NULL,
    title             TEXT NOT NULL,
    body              TEXT,
    -- user_visible drives the APNS priority split when FcmChannel
    -- builds the message (priority 10 + alert vs. priority 5 +
    -- content-available). Stored on the row so a reconciler can
    -- re-dispatch with the original intent.
    user_visible      BOOLEAN NOT NULL DEFAULT true,
    payload           JSONB NOT NULL DEFAULT '{}'::jsonb,
    status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'sent', 'delivered', 'failed')),
    -- FCM resource name (`projects/cure-hht-admin/messages/0:...`)
    -- captured when status flips from pending → sent.
    message_id        TEXT,
    -- Failure reason when status='failed'. The literal `'UNREGISTERED'`
    -- triggers patient_fcm_tokens deactivation via the OutboxWriter's
    -- onUnregistered callback.
    last_error        TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at           TIMESTAMPTZ,
    delivered_at      TIMESTAMPTZ
);

-- Step 3: Polling-friendly index. Predicate on `delivered_at IS NULL`
-- keeps the index small — once a row is fetched, it falls out of the
-- working set. The mobile app's GET /notifications?since=<cursor>
-- query uses (patient_id, created_at DESC) so the cursor advances
-- monotonically.
CREATE INDEX notifications_patient_pending_idx
    ON notifications (patient_id, created_at DESC)
    WHERE delivered_at IS NULL;

-- Step 4: RLS — defense in depth. The repository's queries always
-- include `WHERE patient_id = ?`, but RLS guarantees a forgotten
-- predicate cannot leak another patient's rows.
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Patient session: SELECT and UPDATE only their own rows. The session
-- variable `app.current_patient_id` is set by Database.executeWithContext
-- when called with UserContext.patient(patientId).
CREATE POLICY notifications_patient_select ON notifications
    FOR SELECT
    USING (patient_id = current_setting('app.current_patient_id', true));

CREATE POLICY notifications_patient_update ON notifications
    FOR UPDATE
    USING (patient_id = current_setting('app.current_patient_id', true));

-- Service writes: insertPending and markSent/markFailed run with
-- service_role. We register an explicit ALL policy (rather than rely
-- on BYPASSRLS alone) so the audit trail of which role wrote each
-- row is unambiguous in pg_policies.
CREATE POLICY notifications_service_all ON notifications
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Step 5: GRANTs. RLS is moot without table-level privileges — the
-- query fails with `permission denied for table notifications`
-- before any policy is consulted.
GRANT SELECT, UPDATE ON notifications TO authenticated;
GRANT ALL ON notifications TO service_role;

COMMENT ON TABLE notifications IS
    'Outbox / envelope record for push notifications. Written by server before FCM dispatch (REQ-d00194), polled by mobile via GET /api/v1/notifications (REQ-d00195).';
COMMENT ON COLUMN notifications.patient_id IS
    'FK to patients (RAVE SubjectKey). RLS scope key.';
COMMENT ON COLUMN notifications.notification_type IS
    '3-value enum: questionnaire_update / patient_status_update / reminder. Sub-action lives in payload->>"action".';
COMMENT ON COLUMN notifications.user_visible IS
    'True for alerts (priority 10 + lock-screen). False for silent data pushes (priority 5 + content-available).';
COMMENT ON COLUMN notifications.payload IS
    'Opaque IDs + categorical sub-action only — never PHI. Enforced by PayloadGuard in comms.OutboxWriter before insert.';
COMMENT ON COLUMN notifications.status IS
    'State machine: pending → sent → delivered, with failed as terminal.';
COMMENT ON COLUMN notifications.message_id IS
    'FCM resource name from a successful dispatch (e.g. projects/cure-hht-admin/messages/0:...).';
COMMENT ON COLUMN notifications.last_error IS
    'Failure reason when status=failed. The literal "UNREGISTERED" triggers patient_fcm_tokens row deactivation.';
COMMENT ON COLUMN notifications.delivered_at IS
    'Stamped when the mobile fetches the envelope. Idempotent — a duplicate fetch does not bump the timestamp.';

COMMIT;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    -- Table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'notifications'
    ) THEN
        RAISE EXCEPTION 'Migration 011 failed: notifications table was not created';
    END IF;

    -- Type exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'notification_type'
    ) THEN
        RAISE EXCEPTION 'Migration 011 failed: notification_type enum was not created';
    END IF;

    -- Index exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'notifications_patient_pending_idx'
    ) THEN
        RAISE EXCEPTION 'Migration 011 failed: notifications_patient_pending_idx was not created';
    END IF;

    -- RLS enabled
    IF NOT (
        SELECT relrowsecurity
        FROM pg_class
        WHERE relname = 'notifications'
    ) THEN
        RAISE EXCEPTION 'Migration 011 failed: RLS not enabled on notifications';
    END IF;

    -- Policies exist
    IF (
        SELECT COUNT(*) FROM pg_policies
        WHERE tablename = 'notifications'
    ) < 3 THEN
        RAISE EXCEPTION 'Migration 011 failed: expected ≥3 RLS policies on notifications (patient_select, patient_update, service_all)';
    END IF;

    -- GRANTs in place
    IF NOT has_table_privilege('authenticated', 'notifications', 'SELECT') THEN
        RAISE EXCEPTION 'Migration 011 failed: authenticated role lacks SELECT on notifications';
    END IF;
    IF NOT has_table_privilege('service_role', 'notifications', 'INSERT') THEN
        RAISE EXCEPTION 'Migration 011 failed: service_role lacks INSERT on notifications';
    END IF;

    RAISE NOTICE 'Migration 011 verified successfully: notifications table + RLS + grants in place';
END $$;

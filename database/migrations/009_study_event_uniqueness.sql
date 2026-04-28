-- =====================================================
-- Migration: Add study_event uniqueness constraint and end_event column
-- Number: 009
-- Date: 2026-04-02
-- Description: Adds a partial unique index to prevent duplicate study_event
--   values for the same patient + questionnaire type (non-deleted instances).
--   Also adds an end_event column for Phase 2 terminal event tracking
--   (End of Treatment / End of Study), separate from study_event to preserve
--   the cycle number.
--   (Linear: CUR-856)
-- Dependencies: Requires migration 004 (questionnaire_instances table)
-- Reference: spec/prd-questionnaire-system.md
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-CAL-p00080: Questionnaire Study Event Association
--     Assertion E: No two non-deleted questionnaires of the same type for the
--       same patient may share a StudyEvent value.
--     Assertion F (Phase 2 prep): End of Treatment / End of Study column.
-- =====================================================

-- =====================================================
-- 1. PARTIAL UNIQUE INDEX ON study_event (Assertion E)
-- =====================================================
-- Ensures no two non-deleted instances of the same type for the same patient
-- share a study_event value. Deleted (revoked) instances are excluded — their
-- cycle numbers are "freed" and can be reused by a subsequent send.
--
-- Uses CONCURRENTLY to avoid locking the table in production (required by Squawk).

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_qi_unique_study_event
  ON questionnaire_instances (patient_id, questionnaire_type, study_event)
  WHERE deleted_at IS NULL AND study_event IS NOT NULL;

-- =====================================================
-- 2. END_EVENT COLUMN (Phase 2 prep — Assertion F)
-- =====================================================
-- Nullable column to record terminal events separately from study_event.
-- This preserves the cycle number ("Cycle 5 Day 1") while also recording
-- HOW the questionnaire ended ("End of Treatment" or "End of Study").
-- Without this, overwriting study_event would lose the cycle number.
--
-- Example after finalization:
--   study_event = "Cycle 5 Day 1"      ← which cycle
--   end_event   = "End of Treatment"   ← how it ended
--
-- Phase 1: always NULL. Phase 2: set during finalization when SC selects
-- an end event.

-- Create enum type for end events
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'end_event_type') THEN
        CREATE TYPE end_event_type AS ENUM ('end_of_treatment', 'end_of_study');
    END IF;
END $$;

ALTER TABLE questionnaire_instances
  ADD COLUMN IF NOT EXISTS end_event end_event_type;

-- =====================================================
-- 3. PARTIAL UNIQUE INDEX ON end_event (Assertion G)
-- =====================================================
-- Ensures at most one non-deleted questionnaire instance per patient + type
-- carries a non-null end_event (End of Treatment / End of Study).
--
-- Application logic already blocks a second terminal send, but for 21 CFR
-- Part 11 defence-in-depth the database must enforce this independently.
--
-- Soft-deleted instances are excluded so a deleted terminal-cycle
-- questionnaire does not permanently block the type.
--
-- Uses CONCURRENTLY to avoid locking the table in production (required by Squawk).

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_qi_unique_end_event
  ON questionnaire_instances (patient_id, questionnaire_type)
  WHERE end_event IS NOT NULL AND deleted_at IS NULL;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    -- Verify study_event unique index exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_qi_unique_study_event'
    ) THEN
        RAISE EXCEPTION 'idx_qi_unique_study_event index was not created';
    END IF;

    -- Verify end_event column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'questionnaire_instances'
          AND column_name = 'end_event'
    ) THEN
        RAISE EXCEPTION 'end_event column was not added';
    END IF;

    -- Verify terminal cycle uniqueness index exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_qi_unique_end_event'
    ) THEN
        RAISE EXCEPTION 'idx_qi_unique_end_event index was not created';
    END IF;

    RAISE NOTICE 'Migration 009 complete: study_event uniqueness index, end_event column, and terminal cycle uniqueness index added';
END $$;

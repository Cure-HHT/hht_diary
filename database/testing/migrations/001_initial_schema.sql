-- =====================================================
-- Migration: 001 - Initial Schema
-- Ticket: Initial Project Setup
-- Author: Database Team
-- Date: 2025-10-14
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00003: Separate Database Per Sponsor
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00018: Multi-Site Support Per Sponsor
--   REQ-o00004: Database Schema Deployment
--
-- Purpose:
-- Establishes the initial database schema for the Clinical Trial Diary Database.
-- This migration creates all core tables, indexes, triggers, and RLS policies.
--
-- Dependencies:
-- - PostgreSQL 15+
-- - Extensions: uuid-ossp, pgcrypto
--
-- Notes:
-- This is a reference migration. The actual initial schema is applied via
-- database/init.sql which includes all core tables. This migration serves as
-- documentation and establishes the migration baseline.

BEGIN;

-- Log migration start
DO $$
BEGIN
    RAISE NOTICE 'Starting migration 001: Initial Schema';
    RAISE NOTICE 'Timestamp: %', now();
END $$;

-- Verify required extensions are installed
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp') THEN
        RAISE EXCEPTION 'Required extension uuid-ossp is not installed';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
        RAISE EXCEPTION 'Required extension pgcrypto is not installed';
    END IF;

    RAISE NOTICE 'Required extensions verified';
END $$;

-- Verify core tables exist
DO $$
DECLARE
    required_tables TEXT[] := ARRAY[
        'sites',
        'user_profiles',
        'record_state',
        'record_audit',
        'investigator_annotations',
        'sync_metadata'
    ];
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY required_tables
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_name = tbl
        ) THEN
            RAISE EXCEPTION 'Required table % does not exist', tbl;
        END IF;
    END LOOP;

    RAISE NOTICE 'All required tables verified';
END $$;

-- Verify critical indexes exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_audit_event_uuid'
    ) THEN
        RAISE NOTICE 'Creating missing index: idx_audit_event_uuid';
        CREATE INDEX idx_audit_event_uuid ON record_audit(event_uuid);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_state_patient_site'
    ) THEN
        RAISE NOTICE 'Creating missing index: idx_state_patient_site';
        CREATE INDEX idx_state_patient_site ON record_state(patient_id, site_id);
    END IF;

    RAISE NOTICE 'Critical indexes verified';
END $$;

-- Verify triggers exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_record_state_from_audit'
    ) THEN
        RAISE EXCEPTION 'Critical trigger update_record_state_from_audit does not exist';
    END IF;

    RAISE NOTICE 'Critical triggers verified';
END $$;

-- Migration verification complete
DO $$
BEGIN
    RAISE NOTICE 'Migration 001 verification complete';
    RAISE NOTICE 'Database schema is properly initialized';
END $$;

COMMIT;

-- Post-migration notes
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Migration 001: Initial Schema - COMPLETED';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE 'Next migration: 002_add_audit_metadata.sql';
    RAISE NOTICE '================================================';
END $$;

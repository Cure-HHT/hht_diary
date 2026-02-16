-- IMPLEMENTS REQUIREMENTS:
--   REQ-o00004: Database Schema Deployment
--
-- =====================================================
-- Clinical Trial Diary Database - Complete Initialization
-- For Supabase Deployment
-- =====================================================
--
-- This script initializes the complete database schema
-- Run this in order via Supabase SQL Editor or migrations
--
-- =====================================================

\echo 'Starting Clinical Trial Diary Database Initialization...'

-- =====================================================
-- STEP 1: Schema and Extensions
-- =====================================================

\echo 'Step 1: Creating schema and enabling extensions...'

\ir schema.sql

-- =====================================================
-- STEP 2: Triggers and Automation
-- =====================================================

\echo 'Step 2: Creating triggers and audit automation...'

\ir triggers.sql

-- =====================================================
-- STEP 3: Roles and Permissions
-- =====================================================

\echo 'Step 3: Setting up roles and permissions...'

\ir roles.sql

-- =====================================================
-- STEP 4: Row-Level Security Policies
-- =====================================================

\echo 'Step 4: Enabling Row-Level Security policies...'

\ir rls_policies.sql

-- =====================================================
-- STEP 5: Indexes and Performance Optimizations
-- =====================================================

\echo 'Step 5: Creating indexes and performance optimizations...'

\ir indexes.sql

-- =====================================================
-- STEP 5.5: Tamper Detection
-- =====================================================

\echo 'Step 5.5: Setting up cryptographic tamper detection...'

\ir tamper_detection.sql

-- =====================================================
-- STEP 5.6: Authentication Audit Logging
-- =====================================================

\echo 'Step 5.6: Setting up authentication audit logging...'

\ir auth_audit.sql

-- =====================================================
-- STEP 5.7: Compliance Verification Functions
-- =====================================================

\echo 'Step 5.7: Creating compliance verification functions...'

\ir compliance_verification.sql

-- =====================================================
-- STEP 6: Validation and Health Checks
-- =====================================================

\echo 'Step 6: Running validation checks...'

-- Verify all tables exist
DO $$
DECLARE
    table_count INTEGER;
    expected_tables TEXT[] := ARRAY[
        'sites',
        'record_audit',
        'record_state',
        'investigator_annotations',
        'user_site_assignments',
        'investigator_site_assignments',
        'analyst_site_assignments',
        'sync_conflicts',
        'admin_action_log',
        'user_profiles',
        'role_change_log',
        'user_sessions',
        'auth_audit_log',
        'questionnaire_instances',
        'patient_fcm_tokens'
    ];
    missing_tables TEXT[];
BEGIN
    SELECT array_agg(t)
    INTO missing_tables
    FROM unnest(expected_tables) AS t
    WHERE NOT EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public' AND tablename = t
    );

    IF missing_tables IS NOT NULL THEN
        RAISE EXCEPTION 'Missing tables: %', array_to_string(missing_tables, ', ');
    END IF;

    RAISE NOTICE 'All % expected tables created successfully', array_length(expected_tables, 1);
END $$;

-- Verify RLS is enabled
DO $$
DECLARE
    tables_without_rls TEXT[];
BEGIN
    SELECT array_agg(tablename)
    INTO tables_without_rls
    FROM pg_tables t
    WHERE schemaname = 'public'
    AND tablename NOT LIKE 'pg_%'
    AND NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = t.tablename
        AND n.nspname = t.schemaname
        AND c.relrowsecurity = true
    );

    IF tables_without_rls IS NOT NULL THEN
        RAISE WARNING 'Tables without RLS enabled: %', array_to_string(tables_without_rls, ', ');
    ELSE
        RAISE NOTICE 'RLS enabled on all tables';
    END IF;
END $$;

-- Verify triggers exist
DO $$
DECLARE
    trigger_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO trigger_count
    FROM pg_trigger
    WHERE NOT tgisinternal;

    IF trigger_count < 6 THEN
        RAISE WARNING 'Only % triggers found - expected at least 6', trigger_count;
    ELSE
        RAISE NOTICE '% triggers created successfully', trigger_count;
    END IF;
END $$;

-- =====================================================
-- STEP 7: Create System User and Initial Admin
-- =====================================================

\echo 'Step 7: Setting up system configuration...'

-- Note: The first admin user should be created via the application
-- This is just a placeholder for documentation

-- Add database comment (use dynamic SQL since COMMENT ON DATABASE needs literal name)
DO $$
BEGIN
    EXECUTE format('COMMENT ON DATABASE %I IS %L',
        current_database(),
        'Clinical Trial Diary Database - FDA 21 CFR Part 11 Compliant');
END $$;

-- =====================================================
-- COMPLETION
-- =====================================================

\echo '====================================================='
\echo 'Database Initialization Complete!'
\echo '====================================================='
\echo ''
\echo 'Next Steps:'
\echo '1. Create your first admin user via Supabase Auth'
\echo '2. Add an entry to user_profiles table for the admin'
\echo '3. Create initial sites via the sites table'
\echo '4. Assign investigators and users to sites'
\echo '5. Configure periodic refresh of materialized views'
\echo ''
\echo 'Security Checklist:'
\echo '[ ] Enable SSL/TLS for all connections'
\echo '[ ] Configure JWT secret in Supabase'
\echo '[ ] Set up 2FA for admin users'
\echo '[ ] Configure backup schedule'
\echo '[ ] Review and test RLS policies'
\echo '[ ] Set up monitoring and alerts'
\echo ''
\echo '====================================================='

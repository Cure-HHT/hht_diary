-- TEST FIXTURE - No production requirements
-- Used for: Development and testing environments only
--
-- =====================================================
-- Seed Data for Testing and Development
-- Clinical Trial Diary Database
-- =====================================================
--
-- This script populates the database with sample data
-- for testing and development purposes
--
-- WARNING: DO NOT run this in production!
-- =====================================================

-- =====================================================
-- SEED DATA: Sites
-- =====================================================

INSERT INTO sites (site_id, site_name, site_number, address, contact_info, metadata) VALUES
    ('site_001', 'Stanford Medical Center', 'SMC-001',
     '{"street": "450 Serra Mall", "city": "Stanford", "state": "CA", "zip": "94305"}'::jsonb,
     '{"phone": "650-723-2300", "email": "trials@stanford.edu"}'::jsonb,
     '{"timezone": "America/Los_Angeles", "capacity": 50}'::jsonb),

    ('site_002', 'Mayo Clinic Rochester', 'MCR-002',
     '{"street": "200 First St SW", "city": "Rochester", "state": "MN", "zip": "55905"}'::jsonb,
     '{"phone": "507-284-2511", "email": "trials@mayo.edu"}'::jsonb,
     '{"timezone": "America/Chicago", "capacity": 75}'::jsonb),

    ('site_003', 'Johns Hopkins Hospital', 'JHH-003',
     '{"street": "1800 Orleans St", "city": "Baltimore", "state": "MD", "zip": "21287"}'::jsonb,
     '{"phone": "410-955-5000", "email": "trials@jhmi.edu"}'::jsonb,
     '{"timezone": "America/New_York", "capacity": 60}'::jsonb);

-- =====================================================
-- SEED DATA: User Profiles
-- =====================================================

-- Note: In Supabase, these user_ids would come from auth.users
-- For testing, we'll use placeholder UUIDs

INSERT INTO user_profiles (user_id, email, full_name, role, two_factor_enabled, metadata) VALUES
    -- Admin users
    ('admin_001', 'admin@clinical-trial.org', 'Dr. Sarah Administrator', 'ADMIN', true,
     '{"department": "Clinical Operations", "phone": "555-0100"}'::jsonb),

    -- Investigators
    ('inv_001', 'investigator1@stanford.edu', 'Dr. James Researcher', 'INVESTIGATOR', true,
     '{"specialty": "Cardiology", "license": "CA-12345"}'::jsonb),
    ('inv_002', 'investigator2@mayo.edu', 'Dr. Emily Scientist', 'INVESTIGATOR', true,
     '{"specialty": "Neurology", "license": "MN-67890"}'::jsonb),
    ('inv_003', 'investigator3@jhmi.edu', 'Dr. Michael Clinical', 'INVESTIGATOR', true,
     '{"specialty": "Oncology", "license": "MD-54321"}'::jsonb),

    -- Analysts
    ('analyst_001', 'analyst1@clinical-trial.org', 'Jane Data', 'ANALYST', false,
     '{"department": "Biostatistics"}'::jsonb),
    ('analyst_002', 'analyst2@clinical-trial.org', 'Bob Analytics', 'ANALYST', false,
     '{"department": "Data Science"}'::jsonb),

    -- Patients (Users)
    ('patient_001', 'patient001@example.com', 'Patient A', 'USER', false,
     '{"enrollment_date": "2025-01-15"}'::jsonb),
    ('patient_002', 'patient002@example.com', 'Patient B', 'USER', false,
     '{"enrollment_date": "2025-01-20"}'::jsonb),
    ('patient_003', 'patient003@example.com', 'Patient C', 'USER', false,
     '{"enrollment_date": "2025-02-01"}'::jsonb),
    ('patient_004', 'patient004@example.com', 'Patient D', 'USER', false,
     '{"enrollment_date": "2025-02-05"}'::jsonb),
    ('patient_005', 'patient005@example.com', 'Patient E', 'USER', false,
     '{"enrollment_date": "2025-02-10"}'::jsonb);

-- =====================================================
-- SEED DATA: Investigator Site Assignments
-- =====================================================

INSERT INTO investigator_site_assignments (investigator_id, site_id, access_level, assigned_by) VALUES
    ('inv_001', 'site_001', 'ADMIN', 'admin_001'),
    ('inv_002', 'site_002', 'ADMIN', 'admin_001'),
    ('inv_003', 'site_003', 'ADMIN', 'admin_001');

-- =====================================================
-- SEED DATA: Analyst Site Assignments
-- =====================================================

INSERT INTO analyst_site_assignments (analyst_id, site_id, access_level, assigned_by) VALUES
    ('analyst_001', 'site_001', 'READ_ONLY', 'admin_001'),
    ('analyst_001', 'site_002', 'READ_ONLY', 'admin_001'),
    ('analyst_002', 'site_002', 'READ_ONLY', 'admin_001'),
    ('analyst_002', 'site_003', 'READ_ONLY', 'admin_001');

-- =====================================================
-- SEED DATA: User Site Assignments (Patient Enrollment)
-- =====================================================

INSERT INTO user_site_assignments (patient_id, site_id, study_patient_id, enrollment_status) VALUES
    ('patient_001', 'site_001', 'STUDY-001-0001', 'ACTIVE'),
    ('patient_002', 'site_001', 'STUDY-001-0002', 'ACTIVE'),
    ('patient_003', 'site_002', 'STUDY-002-0001', 'ACTIVE'),
    ('patient_004', 'site_002', 'STUDY-002-0002', 'ACTIVE'),
    ('patient_005', 'site_003', 'STUDY-003-0001', 'ACTIVE');

-- =====================================================
-- SEED DATA: Sample Diary Entries (via Audit Table)
-- =====================================================

-- Patient 001 - Epistaxis event
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason
) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'patient_001', 'site_001', 'USER_CREATE',
     '{"event_type": "epistaxis", "date": "2025-02-15", "time": "14:30", "duration_minutes": 15, "intensity": "moderate", "side": "right", "notes": "Started after exercise"}'::jsonb,
     'patient_001', 'USER', '2025-02-15 14:35:00+00', 'Initial entry'),

    ('550e8400-e29b-41d4-a716-446655440002', 'patient_001', 'site_001', 'USER_CREATE',
     '{"event_type": "epistaxis", "date": "2025-02-16", "time": "09:15", "duration_minutes": 8, "intensity": "mild", "side": "left", "notes": "Morning occurrence"}'::jsonb,
     'patient_001', 'USER', '2025-02-16 09:20:00+00', 'Initial entry');

-- Patient 001 - Update to first entry
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason, parent_audit_id
) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'patient_001', 'site_001', 'USER_UPDATE',
     '{"event_type": "epistaxis", "date": "2025-02-15", "time": "14:30", "duration_minutes": 20, "intensity": "moderate", "side": "right", "notes": "Started after exercise - corrected duration"}'::jsonb,
     'patient_001', 'USER', '2025-02-15 18:00:00+00', 'Corrected duration estimate', 1);

-- Patient 002 entries
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason
) VALUES
    ('550e8400-e29b-41d4-a716-446655440003', 'patient_002', 'site_001', 'USER_CREATE',
     '{"event_type": "epistaxis", "date": "2025-02-17", "time": "20:45", "duration_minutes": 5, "intensity": "mild", "side": "right", "notes": "Brief episode"}'::jsonb,
     'patient_002', 'USER', '2025-02-17 20:50:00+00', 'Initial entry'),

    ('550e8400-e29b-41d4-a716-446655440004', 'patient_002', 'site_001', 'USER_CREATE',
     '{"event_type": "epistaxis", "date": "2025-02-18", "time": "15:20", "duration_minutes": 12, "intensity": "moderate", "side": "left", "notes": "During work"}'::jsonb,
     'patient_002', 'USER', '2025-02-18 15:30:00+00', 'Initial entry');

-- Patient 003 entries
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason
) VALUES
    ('550e8400-e29b-41d4-a716-446655440005', 'patient_003', 'site_002', 'USER_CREATE',
     '{"event_type": "epistaxis", "date": "2025-02-19", "time": "11:00", "duration_minutes": 18, "intensity": "severe", "side": "bilateral", "notes": "Significant bleeding, required medical attention"}'::jsonb,
     'patient_003', 'USER', '2025-02-19 11:25:00+00', 'Initial entry');

-- Patient 004 entries
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason
) VALUES
    ('550e8400-e29b-41d4-a716-446655440006', 'patient_004', 'site_002', 'USER_CREATE',
     '{"event_type": "epistaxis", "date": "2025-02-20", "time": "07:30", "duration_minutes": 3, "intensity": "mild", "side": "right", "notes": "Very brief"}'::jsonb,
     'patient_004', 'USER', '2025-02-20 07:35:00+00', 'Initial entry'),

    ('550e8400-e29b-41d4-a716-446655440007', 'patient_004', 'site_002', 'USER_CREATE',
     '{"event_type": "epistaxis", "date": "2025-02-21", "time": "13:45", "duration_minutes": 10, "intensity": "moderate", "side": "left", "notes": "After meal"}'::jsonb,
     'patient_004', 'USER', '2025-02-21 13:50:00+00', 'Initial entry');

-- Patient 005 entries
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason
) VALUES
    ('550e8400-e29b-41d4-a716-446655440008', 'patient_005', 'site_003', 'USER_CREATE',
     '{"event_type": "epistaxis", "date": "2025-02-22", "time": "16:00", "duration_minutes": 7, "intensity": "mild", "side": "right", "notes": "Afternoon occurrence"}'::jsonb,
     'patient_005', 'USER', '2025-02-22 16:10:00+00', 'Initial entry');

-- =====================================================
-- SEED DATA: Investigator Annotations
-- =====================================================

INSERT INTO investigator_annotations (
    event_uuid, investigator_id, site_id, annotation_text,
    annotation_type, requires_response
) VALUES
    ('550e8400-e29b-41d4-a716-446655440005', 'inv_002', 'site_002',
     'Patient reported seeking medical attention. Please confirm details of treatment received.',
     'QUERY', true),

    ('550e8400-e29b-41d4-a716-446655440001', 'inv_001', 'site_001',
     'Initial duration was 15 minutes, updated to 20 minutes. Change is reasonable and accepted.',
     'NOTE', false),

    ('550e8400-e29b-41d4-a716-446655440004', 'inv_001', 'site_001',
     'Please provide more detail about activities prior to this event.',
     'QUERY', true);

-- =====================================================
-- SEED DATA: Admin Actions
-- =====================================================

INSERT INTO admin_action_log (
    admin_id, action_type, target_resource, action_details,
    justification, approval_status
) VALUES
    ('admin_001', 'ASSIGN_INVESTIGATOR', 'inv_001',
     '{"site_id": "site_001", "access_level": "ADMIN"}'::jsonb,
     'Initial site setup - assigning principal investigator',
     'APPROVED'),

    ('admin_001', 'ASSIGN_INVESTIGATOR', 'inv_002',
     '{"site_id": "site_002", "access_level": "ADMIN"}'::jsonb,
     'Initial site setup - assigning principal investigator',
     'APPROVED'),

    ('admin_001', 'ASSIGN_INVESTIGATOR', 'inv_003',
     '{"site_id": "site_003", "access_level": "ADMIN"}'::jsonb,
     'Initial site setup - assigning principal investigator',
     'APPROVED');

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Display summary of seeded data
DO $$
DECLARE
    site_count INTEGER;
    user_count INTEGER;
    audit_count INTEGER;
    state_count INTEGER;
    annotation_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO site_count FROM sites;
    SELECT COUNT(*) INTO user_count FROM user_profiles;
    SELECT COUNT(*) INTO audit_count FROM record_audit;
    SELECT COUNT(*) INTO state_count FROM record_state;
    SELECT COUNT(*) INTO annotation_count FROM investigator_annotations;

    RAISE NOTICE '===== Seed Data Summary =====';
    RAISE NOTICE 'Sites created: %', site_count;
    RAISE NOTICE 'User profiles created: %', user_count;
    RAISE NOTICE 'Audit entries created: %', audit_count;
    RAISE NOTICE 'State records created: %', state_count;
    RAISE NOTICE 'Annotations created: %', annotation_count;
    RAISE NOTICE '============================';
END $$;

-- Sample queries to verify data
\echo ''
\echo 'Sample Query Results:'
\echo ''
\echo '1. Active Sites:'
SELECT site_id, site_name, site_number FROM sites WHERE is_active = true;

\echo ''
\echo '2. Current Diary Entries by Patient:'
SELECT
    patient_id,
    COUNT(*) as entry_count,
    MAX(updated_at) as last_entry
FROM record_state
WHERE is_deleted = false
GROUP BY patient_id
ORDER BY patient_id;

\echo ''
\echo '3. Unresolved Annotations:'
SELECT
    a.event_uuid,
    a.annotation_text,
    a.annotation_type,
    u.full_name as investigator_name
FROM investigator_annotations a
JOIN user_profiles u ON a.investigator_id = u.user_id
WHERE a.resolved = false;

\echo ''
\echo 'Seed data loaded successfully!'

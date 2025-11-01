-- =====================================================
-- Migration: Add JSONB Validation Functions
-- Number: 008
-- Date: 2025-10-15
-- Description: Implements comprehensive validation for diary event data
-- Dependencies: Requires base schema (001)
-- Reference: spec/JSONB_SCHEMA.md
-- =====================================================

-- =====================================================
-- VALIDATION HELPER FUNCTIONS
-- =====================================================

-- Helper function to validate UUID format
CREATE OR REPLACE FUNCTION is_valid_uuid(uuid_string TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if string matches UUID format (8-4-4-4-12 hex digits)
    RETURN uuid_string ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION is_valid_uuid(TEXT) IS 'Validates UUID format (supports v4 and v7)';

-- Helper function to validate ISO 8601 timestamp format
CREATE OR REPLACE FUNCTION is_valid_iso8601(timestamp_string TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Try to cast to timestamptz; if it fails, it's not valid ISO 8601
    PERFORM timestamp_string::timestamptz;
    RETURN true;
EXCEPTION
    WHEN OTHERS THEN
        RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION is_valid_iso8601(TEXT) IS 'Validates ISO 8601 timestamp format with timezone';

-- =====================================================
-- EVENT-SPECIFIC VALIDATORS
-- =====================================================

-- Validate epistaxis (nosebleed) event data
CREATE OR REPLACE FUNCTION validate_epistaxis_data(event_data JSONB)
RETURNS BOOLEAN AS $$
DECLARE
    severity_value TEXT;
    valid_severities TEXT[] := ARRAY['minimal', 'mild', 'moderate', 'severe', 'very_severe', 'extreme'];
    is_no_nosebleeds BOOLEAN;
    is_unknown BOOLEAN;
    is_incomplete BOOLEAN;
BEGIN
    -- Required fields
    IF NOT (event_data ? 'id') THEN
        RAISE EXCEPTION 'epistaxis: Missing required field: event_data.id';
    END IF;

    IF NOT (event_data ? 'startTime') THEN
        RAISE EXCEPTION 'epistaxis: Missing required field: event_data.startTime';
    END IF;

    IF NOT (event_data ? 'lastModified') THEN
        RAISE EXCEPTION 'epistaxis: Missing required field: event_data.lastModified';
    END IF;

    -- Validate UUID format
    IF NOT is_valid_uuid(event_data->>'id') THEN
        RAISE EXCEPTION 'epistaxis: Invalid UUID format in event_data.id';
    END IF;

    -- Validate timestamp formats
    IF NOT is_valid_iso8601(event_data->>'startTime') THEN
        RAISE EXCEPTION 'epistaxis: Invalid ISO 8601 format in event_data.startTime';
    END IF;

    IF NOT is_valid_iso8601(event_data->>'lastModified') THEN
        RAISE EXCEPTION 'epistaxis: Invalid ISO 8601 format in event_data.lastModified';
    END IF;

    -- Validate endTime if present
    IF event_data ? 'endTime' AND event_data->>'endTime' IS NOT NULL THEN
        IF NOT is_valid_iso8601(event_data->>'endTime') THEN
            RAISE EXCEPTION 'epistaxis: Invalid ISO 8601 format in event_data.endTime';
        END IF;
    END IF;

    -- Get boolean flags (default to false if not present)
    is_no_nosebleeds := COALESCE((event_data->>'isNoNosebleedsEvent')::boolean, false);
    is_unknown := COALESCE((event_data->>'isUnknownNosebleedsEvent')::boolean, false);
    is_incomplete := COALESCE((event_data->>'isIncomplete')::boolean, false);

    -- Validate mutual exclusivity: isNoNosebleedsEvent and isUnknownNosebleedsEvent cannot both be true
    IF is_no_nosebleeds AND is_unknown THEN
        RAISE EXCEPTION 'epistaxis: isNoNosebleedsEvent and isUnknownNosebleedsEvent cannot both be true';
    END IF;

    -- Validate severity enum if present (must be string, not number)
    IF event_data ? 'severity' AND event_data->>'severity' IS NOT NULL THEN
        severity_value := event_data->>'severity';

        -- Check if severity is a valid string enum
        IF NOT (severity_value = ANY(valid_severities)) THEN
            RAISE EXCEPTION 'epistaxis: Invalid severity value "%". Must be one of: %',
                severity_value, array_to_string(valid_severities, ', ');
        END IF;

        -- Special events should not have severity
        IF is_no_nosebleeds OR is_unknown THEN
            RAISE EXCEPTION 'epistaxis: severity must be omitted when isNoNosebleedsEvent or isUnknownNosebleedsEvent is true';
        END IF;
    END IF;

    -- Validate endTime rules for special events
    IF (is_no_nosebleeds OR is_unknown) AND (event_data ? 'endTime') THEN
        RAISE EXCEPTION 'epistaxis: endTime must be omitted when isNoNosebleedsEvent or isUnknownNosebleedsEvent is true';
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_epistaxis_data(JSONB) IS 'Validates epistaxis event data structure (v1.0)';

-- Validate survey event data
CREATE OR REPLACE FUNCTION validate_survey_data(event_data JSONB)
RETURNS BOOLEAN AS $$
DECLARE
    survey_array JSONB;
    question JSONB;
    has_response BOOLEAN;
    is_skipped BOOLEAN;
BEGIN
    -- Required fields
    IF NOT (event_data ? 'id') THEN
        RAISE EXCEPTION 'survey: Missing required field: event_data.id';
    END IF;

    IF NOT (event_data ? 'completedAt') THEN
        RAISE EXCEPTION 'survey: Missing required field: event_data.completedAt';
    END IF;

    IF NOT (event_data ? 'survey') THEN
        RAISE EXCEPTION 'survey: Missing required field: event_data.survey';
    END IF;

    IF NOT (event_data ? 'lastModified') THEN
        RAISE EXCEPTION 'survey: Missing required field: event_data.lastModified';
    END IF;

    -- Validate UUID format
    IF NOT is_valid_uuid(event_data->>'id') THEN
        RAISE EXCEPTION 'survey: Invalid UUID format in event_data.id';
    END IF;

    -- Validate timestamp formats
    IF NOT is_valid_iso8601(event_data->>'completedAt') THEN
        RAISE EXCEPTION 'survey: Invalid ISO 8601 format in event_data.completedAt';
    END IF;

    IF NOT is_valid_iso8601(event_data->>'lastModified') THEN
        RAISE EXCEPTION 'survey: Invalid ISO 8601 format in event_data.lastModified';
    END IF;

    -- Validate survey is an array
    IF jsonb_typeof(event_data->'survey') != 'array' THEN
        RAISE EXCEPTION 'survey: event_data.survey must be an array';
    END IF;

    survey_array := event_data->'survey';

    -- Validate survey is non-empty
    IF jsonb_array_length(survey_array) = 0 THEN
        RAISE EXCEPTION 'survey: event_data.survey must be non-empty';
    END IF;

    -- Validate each question in the survey
    FOR question IN SELECT * FROM jsonb_array_elements(survey_array)
    LOOP
        -- Check required fields
        IF NOT (question ? 'question_id') THEN
            RAISE EXCEPTION 'survey: Missing required field: question_id in survey question';
        END IF;

        IF NOT (question ? 'question_text') THEN
            RAISE EXCEPTION 'survey: Missing required field: question_text in survey question';
        END IF;

        -- Validate question_text is non-empty
        IF LENGTH(question->>'question_text') = 0 THEN
            RAISE EXCEPTION 'survey: question_text cannot be empty';
        END IF;

        -- Check response/skipped logic
        has_response := question ? 'response';
        is_skipped := COALESCE((question->>'skipped')::boolean, false);

        -- If skipped=true, response must be omitted
        IF is_skipped AND has_response THEN
            RAISE EXCEPTION 'survey: response must be omitted when skipped=true for question_id "%"',
                question->>'question_id';
        END IF;

        -- If skipped=false or omitted, response should be present
        IF NOT is_skipped AND NOT has_response THEN
            RAISE EXCEPTION 'survey: response is required when skipped is false for question_id "%"',
                question->>'question_id';
        END IF;
    END LOOP;

    -- Validate score if present
    IF event_data ? 'score' AND event_data->'score' IS NOT NULL THEN
        IF NOT (event_data->'score' ? 'total') THEN
            RAISE EXCEPTION 'survey: score.total is required when score is present';
        END IF;

        IF NOT (event_data->'score' ? 'rubric_version') THEN
            RAISE EXCEPTION 'survey: score.rubric_version is required when score is present';
        END IF;

        -- Validate rubric_version format (v1.0, v2.1, etc.)
        IF NOT (event_data->'score'->>'rubric_version' ~ '^v\d+\.\d+$') THEN
            RAISE EXCEPTION 'survey: score.rubric_version must match format v{major}.{minor}';
        END IF;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_survey_data(JSONB) IS 'Validates survey event data structure (v1.0)';

-- =====================================================
-- MAIN VALIDATION FUNCTION
-- =====================================================

-- Main validation function for EventRecord
-- Replaces the simple validation from initial schema
CREATE OR REPLACE FUNCTION validate_diary_data(data JSONB)
RETURNS BOOLEAN AS $$
DECLARE
    versioned_type TEXT;
    event_type TEXT;
    version TEXT;
BEGIN
    -- Check top-level required fields
    IF NOT (data ? 'id') THEN
        RAISE EXCEPTION 'Missing required field: id';
    END IF;

    IF NOT (data ? 'versioned_type') THEN
        RAISE EXCEPTION 'Missing required field: versioned_type';
    END IF;

    IF NOT (data ? 'event_data') THEN
        RAISE EXCEPTION 'Missing required field: event_data';
    END IF;

    -- Validate id is a UUID
    IF NOT is_valid_uuid(data->>'id') THEN
        RAISE EXCEPTION 'Invalid UUID format in id field';
    END IF;

    -- Validate versioned_type format: {type}-v{major}.{minor}
    versioned_type := data->>'versioned_type';
    IF NOT (versioned_type ~ '^[a-z_]+-v\d+\.\d+$') THEN
        RAISE EXCEPTION 'Invalid versioned_type format: "%". Expected format: {type}-v{major}.{minor}',
            versioned_type;
    END IF;

    -- Validate event_data is an object
    IF jsonb_typeof(data->'event_data') != 'object' THEN
        RAISE EXCEPTION 'event_data must be an object';
    END IF;

    -- Extract event type and version
    event_type := split_part(versioned_type, '-v', 1);
    version := split_part(versioned_type, '-v', 2);

    -- Delegate to type-specific validator
    CASE event_type
        WHEN 'epistaxis' THEN
            RETURN validate_epistaxis_data(data->'event_data');
        WHEN 'survey' THEN
            RETURN validate_survey_data(data->'event_data');
        ELSE
            RAISE EXCEPTION 'Unknown event type: "%". Supported types: epistaxis, survey', event_type;
    END CASE;

    RETURN true;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_diary_data(JSONB) IS 'Validates EventRecord structure and delegates to type-specific validators. See spec/JSONB_SCHEMA.md';

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Verify functions were created successfully
DO $$
BEGIN
    -- Check helper functions exist
    PERFORM 1 FROM pg_proc WHERE proname = 'is_valid_uuid';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Migration failed: is_valid_uuid function not created';
    END IF;

    PERFORM 1 FROM pg_proc WHERE proname = 'is_valid_iso8601';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Migration failed: is_valid_iso8601 function not created';
    END IF;

    -- Check event validators exist
    PERFORM 1 FROM pg_proc WHERE proname = 'validate_epistaxis_data';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Migration failed: validate_epistaxis_data function not created';
    END IF;

    PERFORM 1 FROM pg_proc WHERE proname = 'validate_survey_data';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Migration failed: validate_survey_data function not created';
    END IF;

    -- Check main validator exists
    PERFORM 1 FROM pg_proc WHERE proname = 'validate_diary_data';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Migration failed: validate_diary_data function not created';
    END IF;

    RAISE NOTICE 'Migration 008: JSONB validation functions created successfully';
END $$;

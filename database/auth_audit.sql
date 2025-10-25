-- =====================================================
-- Authentication Audit Log Enhancement
-- HIPAA and FDA 21 CFR Part 11 Compliance
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00002: Multi-Factor Authentication for Staff
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-o00006: MFA Configuration for Staff Accounts
--
-- AUTHENTICATION AUDITING:
--   Comprehensive authentication event logging required for:
--   - HIPAA: Access logging requirements (45 CFR § 164.312(b))
--   - FDA 21 CFR Part 11: User identification and audit trail (§ 11.10(e))
--   - Security monitoring and incident response
--
-- =====================================================

-- =====================================================
-- AUTHENTICATION AUDIT LOG
-- =====================================================

CREATE TABLE auth_audit_log (
    log_id BIGSERIAL PRIMARY KEY,

    -- User identification
    user_id TEXT, -- May be NULL for failed login attempts
    email TEXT,
    role TEXT, -- USER, INVESTIGATOR, ANALYST, ADMIN

    -- Event classification
    event_type TEXT NOT NULL CHECK (event_type IN (
        'LOGIN_SUCCESS',
        'LOGIN_FAILED',
        'LOGOUT',
        'PASSWORD_RESET',
        'PASSWORD_CHANGE',
        'SESSION_EXPIRED',
        'SESSION_REVOKED',
        'TWO_FACTOR_SUCCESS',
        'TWO_FACTOR_FAILED',
        'ACCOUNT_LOCKED',
        'ACCOUNT_UNLOCKED',
        'ROLE_CHANGE',
        'PERMISSION_DENIED'
    )),

    -- Authentication method
    auth_method TEXT CHECK (auth_method IN (
        'email',          -- Email/password
        'google',         -- Google OAuth
        'apple',          -- Apple Sign In
        'microsoft',      -- Microsoft OAuth
        'saml',           -- SAML SSO
        'magic_link',     -- Passwordless
        'api_key'         -- API/service authentication
    )),

    -- OAuth provider details (if applicable)
    provider_user_id TEXT,
    provider_email TEXT,

    -- Audit trail details
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    success BOOLEAN NOT NULL,
    failure_reason TEXT,

    -- Network and device information
    client_ip INET,
    user_agent TEXT,
    device_info JSONB,
    /* Structure:
    {
        "device_type": "mobile|web|desktop",
        "os": "iOS|Android|Windows|macOS|Linux",
        "browser": "Safari|Chrome|Firefox|Edge",
        "app_version": "1.2.3"
    }
    */

    -- Session tracking
    session_id TEXT,
    session_duration_seconds INTEGER, -- For logout events

    -- Geographic information (for security monitoring)
    geo_location JSONB,
    /* Structure:
    {
        "country": "US",
        "region": "California",
        "city": "San Francisco",
        "timezone": "America/Los_Angeles"
    }
    */

    -- Security flags
    is_suspicious BOOLEAN DEFAULT false,
    risk_score INTEGER CHECK (risk_score >= 0 AND risk_score <= 100),
    security_notes TEXT,

    -- Site context (for multi-site trials)
    site_id TEXT REFERENCES sites(site_id),

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX idx_auth_user_id ON auth_audit_log(user_id);
CREATE INDEX idx_auth_email ON auth_audit_log(email);
CREATE INDEX idx_auth_timestamp ON auth_audit_log(timestamp DESC);
CREATE INDEX idx_auth_event_type ON auth_audit_log(event_type);
CREATE INDEX idx_auth_success ON auth_audit_log(success);
CREATE INDEX idx_auth_session_id ON auth_audit_log(session_id);
CREATE INDEX idx_auth_client_ip ON auth_audit_log(client_ip);

-- Partial index for failed attempts (security monitoring)
CREATE INDEX idx_auth_failed ON auth_audit_log(timestamp DESC)
    WHERE success = false;

-- Partial index for suspicious activity
CREATE INDEX idx_auth_suspicious ON auth_audit_log(timestamp DESC)
    WHERE is_suspicious = true;

-- Site-based queries for multi-site monitoring
CREATE INDEX idx_auth_site ON auth_audit_log(site_id, timestamp DESC)
    WHERE site_id IS NOT NULL;

-- =====================================================
-- ROW-LEVEL SECURITY
-- =====================================================

ALTER TABLE auth_audit_log ENABLE ROW LEVEL SECURITY;

-- Users can view their own authentication logs
CREATE POLICY auth_log_select_own ON auth_audit_log
    FOR SELECT
    TO authenticated
    USING (user_id = current_user_id());

-- Investigators can view auth logs for their sites
CREATE POLICY auth_log_investigator_select ON auth_audit_log
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'INVESTIGATOR'
        AND site_id IN (
            SELECT site_id
            FROM investigator_site_assignments
            WHERE investigator_id = current_user_id()
            AND is_active = true
        )
    );

-- Admins can view all authentication logs
CREATE POLICY auth_log_admin_select ON auth_audit_log
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'ADMIN');

-- Service role can insert logs (from application layer)
CREATE POLICY auth_log_service_insert ON auth_audit_log
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to log authentication event
CREATE OR REPLACE FUNCTION log_auth_event(
    p_user_id TEXT,
    p_email TEXT,
    p_event_type TEXT,
    p_auth_method TEXT DEFAULT 'email',
    p_success BOOLEAN DEFAULT true,
    p_failure_reason TEXT DEFAULT NULL,
    p_client_ip INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_session_id TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_log_id BIGINT;
    v_role TEXT;
    v_site_id TEXT;
BEGIN
    -- Get user role if user exists
    IF p_user_id IS NOT NULL THEN
        SELECT role INTO v_role
        FROM user_profiles
        WHERE user_id = p_user_id;

        -- Get primary site for context
        SELECT site_id INTO v_site_id
        FROM user_site_assignments
        WHERE patient_id = p_user_id
        LIMIT 1;
    END IF;

    -- Insert auth log
    INSERT INTO auth_audit_log (
        user_id,
        email,
        role,
        event_type,
        auth_method,
        success,
        failure_reason,
        client_ip,
        user_agent,
        session_id,
        site_id
    ) VALUES (
        p_user_id,
        p_email,
        v_role,
        p_event_type,
        p_auth_method,
        p_success,
        p_failure_reason,
        p_client_ip,
        p_user_agent,
        p_session_id,
        v_site_id
    ) RETURNING log_id INTO v_log_id;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION log_auth_event IS 'Log authentication event for HIPAA/FDA compliance';

-- Function to detect suspicious login patterns
CREATE OR REPLACE FUNCTION detect_suspicious_login(p_user_id TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_failed_count INTEGER;
    v_ip_count INTEGER;
    v_is_suspicious BOOLEAN := false;
BEGIN
    -- Check for multiple failed attempts in last 15 minutes
    SELECT COUNT(*)
    INTO v_failed_count
    FROM auth_audit_log
    WHERE user_id = p_user_id
        AND event_type = 'LOGIN_FAILED'
        AND timestamp > now() - interval '15 minutes';

    IF v_failed_count >= 3 THEN
        v_is_suspicious := true;
    END IF;

    -- Check for logins from multiple IPs in short time
    SELECT COUNT(DISTINCT client_ip)
    INTO v_ip_count
    FROM auth_audit_log
    WHERE user_id = p_user_id
        AND event_type = 'LOGIN_SUCCESS'
        AND timestamp > now() - interval '1 hour';

    IF v_ip_count >= 3 THEN
        v_is_suspicious := true;
    END IF;

    RETURN v_is_suspicious;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION detect_suspicious_login IS 'Detect potentially suspicious login patterns';

-- Function to get failed login count
CREATE OR REPLACE FUNCTION get_failed_login_count(
    p_user_id TEXT,
    p_time_window INTERVAL DEFAULT '1 hour'
)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM auth_audit_log
    WHERE user_id = p_user_id
        AND event_type = 'LOGIN_FAILED'
        AND timestamp > now() - p_time_window;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION get_failed_login_count IS 'Get count of failed login attempts';

-- =====================================================
-- COMPLIANCE VIEWS
-- =====================================================

-- View for HIPAA access audit reports
CREATE VIEW auth_audit_report AS
SELECT
    log_id,
    user_id,
    email,
    role,
    event_type,
    auth_method,
    timestamp,
    success,
    client_ip,
    site_id,
    CASE
        WHEN is_suspicious THEN 'YES'
        ELSE 'NO'
    END as suspicious_activity
FROM auth_audit_log
ORDER BY timestamp DESC;

COMMENT ON VIEW auth_audit_report IS 'HIPAA-compliant authentication audit report';

-- View for security monitoring
CREATE VIEW security_alerts AS
SELECT
    log_id,
    user_id,
    email,
    event_type,
    timestamp,
    client_ip,
    failure_reason,
    security_notes,
    risk_score
FROM auth_audit_log
WHERE is_suspicious = true
    OR risk_score >= 50
    OR event_type IN ('ACCOUNT_LOCKED', 'PERMISSION_DENIED')
ORDER BY timestamp DESC;

COMMENT ON VIEW security_alerts IS 'Security monitoring view for suspicious activity';

-- =====================================================
-- MATERIALIZED VIEW: Daily Login Statistics
-- =====================================================

CREATE MATERIALIZED VIEW daily_login_stats AS
SELECT
    DATE(timestamp) as login_date,
    role,
    auth_method,
    COUNT(*) as total_attempts,
    COUNT(*) FILTER (WHERE success = true) as successful_logins,
    COUNT(*) FILTER (WHERE success = false) as failed_logins,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) FILTER (WHERE is_suspicious = true) as suspicious_attempts,
    AVG(risk_score) as avg_risk_score
FROM auth_audit_log
WHERE event_type IN ('LOGIN_SUCCESS', 'LOGIN_FAILED')
GROUP BY DATE(timestamp), role, auth_method
ORDER BY login_date DESC, role;

CREATE UNIQUE INDEX idx_daily_login_stats
    ON daily_login_stats(login_date, role, auth_method);

COMMENT ON MATERIALIZED VIEW daily_login_stats IS 'Daily authentication statistics for compliance reporting';

-- =====================================================
-- GRANTS
-- =====================================================

GRANT SELECT ON auth_audit_log TO authenticated;
GRANT SELECT ON auth_audit_report TO authenticated;
GRANT SELECT ON security_alerts TO authenticated;
GRANT SELECT ON daily_login_stats TO authenticated;
GRANT ALL ON auth_audit_log TO service_role;
GRANT USAGE, SELECT ON SEQUENCE auth_audit_log_log_id_seq TO service_role;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE auth_audit_log IS 'Authentication audit log for HIPAA and FDA 21 CFR Part 11 compliance';
COMMENT ON COLUMN auth_audit_log.event_type IS 'Type of authentication event';
COMMENT ON COLUMN auth_audit_log.auth_method IS 'Authentication method used (email, OAuth provider, etc.)';
COMMENT ON COLUMN auth_audit_log.is_suspicious IS 'Flagged for suspicious activity';
COMMENT ON COLUMN auth_audit_log.risk_score IS 'Security risk score (0-100)';
COMMENT ON COLUMN auth_audit_log.session_id IS 'Session identifier for tracking user sessions';

-- =====================================================
-- EXAMPLE USAGE
-- =====================================================

/*
-- Log successful login
SELECT log_auth_event(
    p_user_id := 'user_123',
    p_email := 'user@example.com',
    p_event_type := 'LOGIN_SUCCESS',
    p_auth_method := 'google',
    p_success := true,
    p_client_ip := '192.168.1.1'::inet,
    p_user_agent := 'Mozilla/5.0...',
    p_session_id := 'sess_abc123'
);

-- Log failed login
SELECT log_auth_event(
    p_user_id := 'user_123',
    p_email := 'user@example.com',
    p_event_type := 'LOGIN_FAILED',
    p_auth_method := 'email',
    p_success := false,
    p_failure_reason := 'Invalid password'
);

-- Check for suspicious activity
SELECT detect_suspicious_login('user_123');

-- Get failed login count
SELECT get_failed_login_count('user_123', '1 hour'::interval);

-- Query recent logins
SELECT * FROM auth_audit_log
WHERE user_id = 'user_123'
ORDER BY timestamp DESC
LIMIT 10;

-- Security monitoring query
SELECT * FROM security_alerts
WHERE timestamp > now() - interval '24 hours';

-- Daily statistics
SELECT * FROM daily_login_stats
WHERE login_date >= current_date - 7;
*/

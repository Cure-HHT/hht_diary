# Portal Deployment and Operations Guide

**Version**: 1.0
**Audience**: Operations (DevOps, Release Managers, Platform Engineers)
**Last Updated**: 2025-10-27
**Status**: Draft

> **See**: prd-portal.md for portal product requirements
> **See**: dev-portal.md for implementation details
> **See**: ops-deployment.md for overall deployment architecture
> **See**: ops-operations.md for daily monitoring and incident response
> **See**: ops-database-setup.md for Supabase database configuration

---

## Executive Summary

This guide covers deployment, configuration, monitoring, and operational procedures for the Clinical Trial Web Portal. The portal is a Flutter Web application deployed as a static site on Netlify, with each sponsor receiving their own isolated deployment connected to a sponsor-specific Supabase instance.

**Deployment Model**: One portal instance per sponsor
**Hosting**: Netlify (static site hosting)
**Database**: Supabase (PostgreSQL with RLS)
**Authentication**: Supabase Auth (OAuth + email/password)
**Domains**: Custom subdomain per sponsor (e.g., `portal-pfizer.example.com`)

---

## Prerequisites

Before deploying a portal instance, ensure you have:

1. **Netlify Account** with team access
2. **Supabase Project** created for sponsor (separate instance per sponsor)
3. **Domain Name** registered and DNS access
4. **SSL Certificate** (auto-provisioned by Netlify)
5. **Environment Variables** prepared (Supabase URL, Anon Key, OAuth credentials)
6. **Flutter SDK** installed (v3.24+ stable)
7. **Git Repository** access (core repo + sponsor repo)

---

# REQ-o00055: Role-Based Visual Indicator Verification

**Level**: Ops | **Implements**: p00030 | **Status**: Active

**Description**: Portal deployments SHALL include verification that role-based color banners display correctly for all user roles.

**Acceptance Criteria**:

1. ✅ Visual smoke test confirms banner appears on portal homepage
2. ✅ Banner displays correct role name after authentication
3. ✅ Banner colors match specification for each role type
4. ✅ Feature included in all sponsor portal deployments (core platform feature)

**Validation Method**: After deployment, log in as each role type and verify banner color and text

**Implementation Files**:
- Portal UI components (see dev-portal.md)

*End* *Role-Based Visual Indicator Verification* | **Hash**: b02eb8c1
---

## Build Portal

### Build Command

Portal build is executed from the core repository using the build system:

```bash
# Navigate to core repository
cd clinical-diary

# Build portal for specific sponsor
dart run tools/build_system/build_portal.dart \
  --sponsor-repo <path-to-sponsor-repo> \
  --environment production
```

**Example**:

```bash
# Build Pfizer production portal
dart run tools/build_system/build_portal.dart \
  --sponsor-repo ../clinical-diary-pfizer \
  --environment production
```

**Output Location**: `build/web/`

**Output Contents**:
- `index.html` - Main HTML entry point
- `main.dart.js` - Compiled Dart/Flutter code
- `flutter_service_worker.js` - Service worker for caching
- `assets/` - Fonts, images, sponsor branding
- `canvaskit/` - Flutter rendering engine

---

### Build Validation

After build completes, validate the output:

```bash
# Check build directory exists
ls -lah build/web/

# Verify index.html contains Supabase URL (should be redacted/templated)
grep "SUPABASE_URL" build/web/index.html

# Check asset sizes (should be optimized)
du -sh build/web/assets/

# Validate no secrets in build
grep -r "SUPABASE_SERVICE_KEY" build/web/ || echo "OK: No service keys found"
```

**Expected Output**:
- `build/web/` directory size: ~5-15 MB (depends on assets)
- No secrets or service keys in any file
- `index.html` references templated environment variables

---

## Netlify Deployment

### Initial Setup

**Step 1: Create Netlify Site**

```bash
# Install Netlify CLI (one-time)
npm install -g netlify-cli

# Login to Netlify
netlify login

# Create new site
netlify sites:create \
  --name portal-pfizer-production \
  --account-slug your-team-name
```

**Step 2: Configure Build Settings**

In Netlify dashboard (or `netlify.toml` in sponsor repo):

```toml
[build]
  base = "core/"
  publish = "build/web/"
  command = "dart run tools/build_system/build_portal.dart --sponsor-repo ../sponsor --environment production"

[build.environment]
  FLUTTER_VERSION = "3.24.0"
  DART_VERSION = "3.5.0"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
  force = false

[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
    Referrer-Policy = "no-referrer"
    Permissions-Policy = "geolocation=(), microphone=(), camera=()"
```

**Step 3: Set Environment Variables**

In Netlify dashboard → Site Settings → Environment Variables:

```bash
# Supabase Configuration
SUPABASE_URL="https://abc123.supabase.co"
SUPABASE_ANON_KEY="eyJhbGc...your-anon-key"

# OAuth Providers (if enabled)
SUPABASE_GOOGLE_CLIENT_ID="123456789.apps.googleusercontent.com"
SUPABASE_MICROSOFT_CLIENT_ID="abc123-def456-..."

# Environment Identifier
ENVIRONMENT="production"
SPONSOR_ID="pfizer"
```

**IMPORTANT**: Never use `SUPABASE_SERVICE_KEY` in Netlify environment variables (portal uses anon key + RLS).

---

### Deploy Command

**Manual Deployment**:

```bash
# Build portal first
dart run tools/build_system/build_portal.dart \
  --sponsor-repo ../clinical-diary-pfizer \
  --environment production

# Deploy to Netlify
netlify deploy \
  --prod \
  --dir build/web/ \
  --site portal-pfizer-production
```

**Automated Deployment (CI/CD)**:

Add to sponsor repository `.github/workflows/deploy_portal.yml`:

```yaml
name: Deploy Portal

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          path: sponsor

      - uses: actions/checkout@v4
        with:
          repository: yourorg/clinical-diary
          ref: v1.2.0
          path: core

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'

      - name: Build Portal
        run: |
          cd core
          dart run tools/build_system/build_portal.dart \
            --sponsor-repo ../sponsor \
            --environment production

      - name: Deploy to Netlify
        uses: nwtgck/actions-netlify@v2
        with:
          publish-dir: './core/build/web'
          production-deploy: true
          github-token: ${{ secrets.GITHUB_TOKEN }}
          deploy-message: "Deploy from GitHub Actions"
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}
```

---

### Custom Domain Configuration

**Step 1: Add Custom Domain in Netlify**

```bash
# Via CLI
netlify domains:add portal-pfizer.example.com \
  --site portal-pfizer-production

# Or via Netlify Dashboard:
# Site Settings → Domain Management → Add Custom Domain
```

**Step 2: Configure DNS**

Add DNS records in your domain registrar:

```
# If using Netlify DNS (recommended)
CNAME portal-pfizer -> apex-loadbalancer.netlify.com

# If using external DNS
A     portal-pfizer -> 75.2.60.5
AAAA  portal-pfizer -> 2600:1f18:...
```

**Step 3: Enable HTTPS**

Netlify automatically provisions SSL certificate via Let's Encrypt:

```bash
# Verify SSL certificate
netlify domains:status portal-pfizer.example.com

# Check HTTPS enforcement
netlify sites:update \
  --site portal-pfizer-production \
  --force-https
```

**Expected Result**:
- `https://portal-pfizer.example.com` resolves to portal
- SSL certificate valid and auto-renewing
- HTTP requests redirect to HTTPS
- HSTS header enabled

---

## Supabase Configuration

### Database Setup

**See**: ops-database-setup.md for complete Supabase database configuration

**Portal-Specific Requirements**:

1. **Create `portal_users` table** (see `database/schema.sql`)
2. **Create `user_site_access` table** for site assignment
3. **Configure RLS policies** for role-based access (see `database/rls_policies.sql`)
4. **Enable Row-Level Security** on all tables

**Quick Validation**:

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link to project
supabase link --project-ref abc123

# Verify RLS enabled on portal_users table
supabase db remote exec --query "
  SELECT tablename, rowsecurity
  FROM pg_tables
  WHERE schemaname = 'public'
  AND tablename IN ('portal_users', 'patients', 'sites', 'questionnaires')
"
```

**Expected Output**: All tables should have `rowsecurity = t` (true).

---

### Authentication Setup

**Step 1: Enable Auth Providers in Supabase Dashboard**

Navigate to: Authentication → Providers

**Email/Password**:
- ✅ Enable Email provider
- ✅ Confirm email required: Yes
- ✅ Secure email change: Yes
- ✅ Secure password change: Yes

**Google OAuth** (optional):
- ✅ Enable Google provider
- Add Client ID and Client Secret from Google Cloud Console
- Authorized redirect URI: `https://abc123.supabase.co/auth/v1/callback`

**Microsoft OAuth** (optional):
- ✅ Enable Azure provider
- Add Client ID and Client Secret from Azure AD
- Authorized redirect URI: `https://abc123.supabase.co/auth/v1/callback`

**Step 2: Configure Site URL**

In Supabase Dashboard → Authentication → URL Configuration:

```
Site URL: https://portal-pfizer.example.com
Redirect URLs:
  - https://portal-pfizer.example.com
  - https://portal-pfizer.example.com/auth/callback
  - http://localhost:8080 (for local development only)
```

**Step 3: Disable Public Sign-Ups**

Portals should not allow self-registration (Admins create accounts):

```sql
-- Run in Supabase SQL Editor
UPDATE auth.config
SET disable_signup = true;
```

**Validation**:

```bash
# Test OAuth flow
curl -X POST "https://abc123.supabase.co/auth/v1/signup" \
  -H "apikey: your-anon-key" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "testpass"}'

# Expected: Error response (signups disabled)
```

---

## Monitoring and Health Checks

### Netlify Monitoring

**Built-in Metrics** (Netlify Dashboard → Analytics):
- Bandwidth usage
- Request count
- Build duration
- Deploy frequency
- Error rates (4xx/5xx)

**Uptime Monitoring**:

```bash
# Add UptimeRobot or Pingdom monitor
# Endpoint: https://portal-pfizer.example.com
# Method: GET
# Expected: HTTP 200
# Interval: 5 minutes
```

**Example UptimeRobot Configuration**:
- Monitor Type: HTTPS
- URL: `https://portal-pfizer.example.com`
- Alert Contacts: devops@example.com
- Monitoring Interval: 5 minutes
- SSL Certificate Expiration Alert: 7 days before

---

### Supabase Monitoring

**Database Metrics** (Supabase Dashboard → Reports):
- Database size
- Active connections
- Query performance
- RLS policy evaluation time

**Auth Metrics**:
- Daily active users (DAU)
- Sign-ins per day
- OAuth success/failure rates

**Alerts** (Supabase Dashboard → Database → Alerts):

```sql
-- Create alert for high connection count
SELECT COUNT(*) FROM pg_stat_activity
WHERE state = 'active'
HAVING COUNT(*) > 80;  -- Alert if >80 active connections
```

---

### Application Logs

**Netlify Function Logs** (if using Netlify Functions):

```bash
# Tail logs
netlify functions:log

# Filter by function
netlify functions:log --function auth-callback
```

**Supabase Logs** (Supabase Dashboard → Logs):
- Filter by table: `portal_users`, `patients`
- Filter by severity: `ERROR`, `WARNING`
- Export logs for analysis: JSON or CSV

**Recommended Log Retention**: 90 days minimum for compliance (FDA 21 CFR Part 11)

---

## Rollback Procedures

### Netlify Rollback

Netlify maintains deployment history. To rollback:

**Via Dashboard**:
1. Navigate to Deploys tab
2. Find previous successful deploy
3. Click "Publish deploy"

**Via CLI**:

```bash
# List recent deploys
netlify deploys:list

# Restore specific deploy
netlify deploy:restore <deploy-id>

# Or rollback to previous
netlify rollback
```

**Rollback Time**: ~30 seconds (static site, instant rollback)

---

### Database Rollback

**See**: ops-database-migration.md for migration rollback procedures

**Emergency Rollback** (if migration causes portal failure):

```bash
# Connect to Supabase
supabase link --project-ref abc123

# Rollback last migration
supabase db migrations rollback

# Verify portal functionality
curl -I https://portal-pfizer.example.com
```

**Important**: Database rollbacks may cause data loss if users have created records using new schema. Test rollback in staging first.

---

## Incident Response

### Portal Unavailable (HTTP 5xx Errors)

**Step 1: Check Netlify Status**

```bash
# Check deploy status
netlify status

# Check recent deploys
netlify deploys:list | head -5
```

**Step 2: Verify Supabase Connectivity**

```bash
# Test database connection
curl -X POST "https://abc123.supabase.co/rest/v1/rpc/health_check" \
  -H "apikey: your-anon-key" \
  -H "Content-Type: application/json"

# Expected: HTTP 200
```

**Step 3: Rollback if Recent Deploy**

If issue started after recent deploy:

```bash
netlify rollback
```

**Step 4: Notify Stakeholders**

- Update status page
- Notify sponsor contacts
- Escalate to on-call engineer if >30 minutes downtime

---

### Authentication Failures

**Symptoms**: Users cannot log in, OAuth redirects fail

**Step 1: Check Supabase Auth Status**

```bash
# Verify auth service
curl "https://abc123.supabase.co/auth/v1/health" \
  -H "apikey: your-anon-key"

# Expected: {"status":"ok"}
```

**Step 2: Verify OAuth Configuration**

- Check Client IDs in Supabase Dashboard → Authentication → Providers
- Verify Redirect URLs match portal domain
- Test OAuth flow manually

**Step 3: Check RLS Policies**

```sql
-- Verify portal_users table RLS policies
SELECT tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'portal_users';
```

**Expected**: Policies for `admins_auditors_see_all_users`, `investigators_own_sites_users`, etc.

---

### Slow Page Loads

**Symptoms**: Portal takes >5 seconds to load

**Step 1: Check Netlify CDN**

```bash
# Test CDN response time
curl -w "@curl-format.txt" -o /dev/null -s https://portal-pfizer.example.com
```

**curl-format.txt**:
```
time_namelookup:  %{time_namelookup}s\n
time_connect:     %{time_connect}s\n
time_appconnect:  %{time_appconnect}s\n
time_pretransfer: %{time_pretransfer}s\n
time_starttransfer: %{time_starttransfer}s\n
time_total:       %{time_total}s\n
```

**Expected**: Total time <2 seconds

**Step 2: Check Database Query Performance**

```sql
-- Identify slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE mean_exec_time > 1000  -- >1 second
ORDER BY mean_exec_time DESC
LIMIT 10;
```

**Step 3: Optimize**

- Add database indexes if queries slow
- Reduce RLS policy complexity
- Implement pagination for large datasets

---

## Security Hardening

### Content Security Policy (CSP)

Add to `netlify.toml`:

```toml
[[headers]]
  for = "/*"
  [headers.values]
    Content-Security-Policy = """
      default-src 'self';
      script-src 'self' 'unsafe-inline' 'unsafe-eval' https://abc123.supabase.co;
      style-src 'self' 'unsafe-inline';
      img-src 'self' data: https:;
      font-src 'self' data:;
      connect-src 'self' https://abc123.supabase.co;
      frame-ancestors 'none';
    """
```

**Rationale**: CSP prevents XSS attacks by restricting resource sources. Flutter Web requires `'unsafe-eval'` for Dart runtime.

---

### Rate Limiting

Configure in Supabase Dashboard → Settings → API:

```
Anonymous Key Rate Limit: 100 requests/minute
Service Key Rate Limit: 1000 requests/minute
```

**Portal-Specific**: Increase anonymous key limit if high traffic expected.

---

### IP Allowlisting (Optional)

For highly sensitive sponsors, restrict portal access to specific IPs:

```toml
# netlify.toml
[[headers]]
  for = "/*"
  [headers.values]
    X-Robots-Tag = "noindex"  # Prevent indexing

# Add Netlify Edge Function for IP check
# functions/ip-check.ts
```

**See**: dev-portal.md for Edge Function implementation details.

---

## Compliance and Audit

### Deployment Audit Trail

**Required for FDA 21 CFR Part 11**:
- All deployments logged with timestamp, deployer, and commit SHA
- Deployment approvals tracked (if required)
- Rollback events logged

**Implementation**:

```yaml
# .github/workflows/deploy_portal.yml
- name: Log Deployment
  run: |
    echo "Deployed by: ${{ github.actor }}" >> deploy.log
    echo "Commit: ${{ github.sha }}" >> deploy.log
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> deploy.log

    # Upload to audit system
    curl -X POST "https://audit.example.com/deployments" \
      -H "Content-Type: application/json" \
      -d @deploy.log
```

---

### Environment Validation

Before production deployment, validate:

```bash
# Check environment variables set
netlify env:list --site portal-pfizer-production | grep SUPABASE_URL

# Verify SSL certificate
openssl s_client -connect portal-pfizer.example.com:443 -servername portal-pfizer.example.com

# Test authentication flow
curl -X POST "https://portal-pfizer.example.com/api/test-auth" \
  -H "Content-Type: application/json"
```

**Checklist**:
- ✅ SUPABASE_URL set correctly
- ✅ SUPABASE_ANON_KEY set correctly
- ✅ SSL certificate valid and not expiring within 30 days
- ✅ OAuth providers configured (if enabled)
- ✅ Site URL matches portal domain
- ✅ RLS policies enabled on all tables
- ✅ Public sign-ups disabled
- ✅ HTTPS enforced
- ✅ Security headers configured

---

## Troubleshooting Reference

### Common Issues

**Issue**: Portal shows blank white screen
**Cause**: JavaScript error during Flutter initialization
**Solution**: Check browser console for errors, verify `main.dart.js` loaded correctly

**Issue**: "Invalid API key" error on login
**Cause**: `SUPABASE_ANON_KEY` not set or incorrect
**Solution**: Verify environment variable in Netlify dashboard, redeploy

**Issue**: Users can log in but see "No data"
**Cause**: RLS policies blocking access
**Solution**: Verify user role in `portal_users` table, check RLS policies

**Issue**: OAuth redirect fails
**Cause**: Redirect URL mismatch
**Solution**: Ensure Netlify domain matches Supabase redirect URL configuration

**Issue**: Slow initial load (>10 seconds)
**Cause**: Flutter app bundle not optimized
**Solution**: Rebuild with `--web-renderer html` for smaller bundle size

---

## References

- **Product Requirements**: prd-portal.md
- **Implementation**: dev-portal.md
- **Overall Deployment**: ops-deployment.md
- **Database Operations**: ops-database-setup.md, ops-database-migration.md
- **Daily Operations**: ops-operations.md
- **Security**: ops-security.md

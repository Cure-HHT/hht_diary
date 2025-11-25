# Deployment Checklist

# TODO: Check all other .md files for information that should be in this file. Move that information here.

Use this checklist to ensure proper deployment and configuration of the Clinical Trial Diary Database.

---

## Pre-Deployment

### Review & Planning
- [ ] Review `db-spec.md` for architecture understanding
- [ ] Review `README.md` for deployment instructions
- [ ] Identify target environment (development/staging/production)
- [ ] Verify GCP project created
- [ ] Note project URL and credentials
- [ ] Determine required compute resources
- [ ] Plan backup and recovery strategy
- [ ] Identify compliance requirements

### Access & Permissions
- [ ] GCP project admin access confirmed
- [ ] Database credentials secured
- [ ] Team access roles defined
- [ ] Service account created (if needed)

---

## Database Deployment

### Step 1: Schema Creation
- [ ] Run `schema.sql` via Cloud SQL Proxy
- [ ] Verify all 12 tables created successfully
- [ ] Check for any errors in output
- [ ] Verify extensions enabled (uuid-ossp, pgcrypto)

### Step 2: Triggers
- [ ] Run `triggers.sql`
- [ ] Verify audit triggers created
- [ ] Test trigger: insert into record_audit
- [ ] Confirm record_state auto-updates

### Step 3: Roles & Authentication
- [ ] Run `roles.sql`
- [ ] Verify user_profiles table created
- [ ] Verify helper functions created
- [ ] Test current_user_id() function
- [ ] Test current_user_role() function

### Step 4: Row-Level Security
- [ ] Run `rls_policies.sql`
- [ ] Verify RLS enabled on all tables
- [ ] Count policies: `SELECT COUNT(*) FROM pg_policies`
- [ ] Verify policies for each role

### Step 5: Performance Optimization
- [ ] Run `indexes.sql`
- [ ] Verify indexes created (check pg_indexes)
- [ ] Verify materialized views created
- [ ] Test view refresh function

---

## GCP Configuration

### Identity Platform Setup
- [ ] Enable Identity Platform in GCP project
- [ ] Configure email/password authentication
- [ ] Configure email templates (via Firebase Console)
- [ ] Set up SMTP for production emails
- [ ] Deploy custom claims Cloud Function
- [ ] Test Firebase ID token contains custom claims
- [ ] Configure session timeout
- [ ] Enable MFA for admin roles

### Cloud Run API Configuration
- [ ] Deploy Cloud Run service
- [ ] Note service URL
- [ ] Configure service account permissions
- [ ] Configure CORS in Dart server
- [ ] Set up rate limiting (Cloud Armor if needed)
- [ ] Test API connection from client

### Security Settings
- [ ] Cloud SQL uses Private IP (VPC)
- [ ] Configure VPC connector for Cloud Run
- [ ] Set up Secret Manager for credentials
- [ ] Enable Cloud Audit Logs
- [ ] Configure Cloud Armor (DDoS protection)

---

## Initial Data Setup

### Create Admin User
- [ ] Create first user via Identity Platform
- [ ] Note user UUID
- [ ] Insert into user_profiles with ADMIN role
- [ ] Enable 2FA for admin user
- [ ] Test admin login
- [ ] Verify admin has global access

### Create Sites
- [ ] Insert initial site(s) into sites table
- [ ] Verify site metadata complete
- [ ] Test site queries

### Assign Investigators
- [ ] Create investigator users in auth.users
- [ ] Insert into user_profiles with INVESTIGATOR role
- [ ] Create investigator_site_assignments
- [ ] Verify investigator can access site data
- [ ] Test investigator permissions

### Enroll Test Patients (Dev/Staging)
- [ ] Create test user accounts
- [ ] Insert into user_profiles with USER role
- [ ] Create user_site_assignments
- [ ] Verify enrollment status
- [ ] Test patient login

---

## Testing

### Unit Tests
- [ ] Test audit trail creation
- [ ] Test read model updates
- [ ] Test trigger functions
- [ ] Test validation functions
- [ ] Test conflict detection

### RLS Policy Tests
- [ ] Test USER can only see own data
- [ ] Test USER cannot see others' data
- [ ] Test INVESTIGATOR can see site data
- [ ] Test INVESTIGATOR cannot modify patient data
- [ ] Test ANALYST has read-only access
- [ ] Test ADMIN has global access
- [ ] Test cross-site isolation

### Functional Tests
- [ ] Create diary entry via record_audit
- [ ] Verify read model updated
- [ ] Update diary entry
- [ ] Verify version incremented
- [ ] Create investigator annotation
- [ ] Test conflict detection
- [ ] Test conflict resolution
- [ ] Test soft delete

### Integration Tests
- [ ] Test authentication flow
- [ ] Test JWT claims
- [ ] Test API endpoints
- [ ] Test realtime subscriptions
- [ ] Test file uploads (if applicable)
- [ ] Test session management

### Performance Tests
- [ ] Test query performance (<100ms)
- [ ] Test bulk insert performance
- [ ] Test concurrent users (simulate load)
- [ ] Test materialized view refresh time
- [ ] Test index usage (EXPLAIN ANALYZE)
- [ ] Monitor connection pool

---

## Monitoring & Logging

### Database Monitoring
- [ ] Enable query performance insights
- [ ] Set up slow query alerts
- [ ] Monitor table sizes
- [ ] Monitor index usage
- [ ] Track connection count
- [ ] Monitor CPU and memory usage

### Application Monitoring
- [ ] Set up error tracking
- [ ] Configure log aggregation
- [ ] Set up uptime monitoring
- [ ] Configure alerting rules
- [ ] Test alert notifications

### Metrics to Track
- [ ] Daily active users
- [ ] Diary entries created per day
- [ ] Average sync latency
- [ ] Conflict rate
- [ ] Query performance (p95, p99)
- [ ] Error rate
- [ ] API response times

---

## Backup & Recovery

### Backup Configuration
- [ ] Enable Point-in-Time Recovery (PITR)
- [ ] Set retention period (7-30 days)
- [ ] Schedule automated backups
- [ ] Test backup creation
- [ ] Document backup locations
- [ ] Set up cross-region replication (production)

### Recovery Testing
- [ ] Test backup restoration
- [ ] Document recovery procedures
- [ ] Test point-in-time recovery
- [ ] Create runbook for disaster recovery
- [ ] Train team on recovery process
- [ ] Establish RTO/RPO targets

---

## Security Hardening

### Database Security
- [ ] Verify RLS enabled on all tables
- [ ] Review all policies
- [ ] Enable audit logging
- [ ] Configure access logs
- [ ] Set up anomaly detection
- [ ] Review user permissions
- [ ] Rotate service keys

### Application Security
- [ ] Implement rate limiting
- [ ] Set up WAF rules
- [ ] Configure CSP headers
- [ ] Enable HSTS
- [ ] Implement input validation
- [ ] Set up security headers
- [ ] Scan for vulnerabilities

### Compliance
- [ ] Document audit trail capabilities
- [ ] Verify electronic signature support
- [ ] Test data validation rules
- [ ] Review access controls
- [ ] Document change procedures
- [ ] Prepare for FDA audit
- [ ] Create compliance reports

---

## Scheduled Jobs

### Database Maintenance
- [ ] Schedule VACUUM (if not auto-vacuum)
- [ ] Schedule ANALYZE
- [ ] Schedule view refresh (hourly/daily)
- [ ] Schedule session cleanup
- [ ] Schedule conflict cleanup
- [ ] Archive old audit data (>2 years)

### Using pg_cron
```sql
-- Refresh views daily at 2 AM
SELECT cron.schedule(
    'refresh-views',
    '0 2 * * *',
    $$SELECT refresh_reporting_views();$$
);

-- Clean expired sessions every 30 min
SELECT cron.schedule(
    'cleanup-sessions',
    '*/30 * * * *',
    $$DELETE FROM user_sessions WHERE expires_at < now();$$
);
```

---

## Documentation

### Technical Documentation
- [ ] Database schema documented
- [ ] API endpoints documented
- [ ] RLS policies explained
- [ ] Deployment procedures written
- [ ] Troubleshooting guide created
- [ ] Architecture diagrams prepared

### User Documentation
- [ ] User guides created
- [ ] Investigator manual prepared
- [ ] Admin manual completed
- [ ] FAQ document created
- [ ] Video tutorials recorded (optional)
- [ ] Training materials prepared

### Compliance Documentation
- [ ] System validation plan
- [ ] User requirements specification
- [ ] Design specification
- [ ] Test plan and results
- [ ] Change control procedures
- [ ] SOPs documented

---

## Training

### Team Training
- [ ] Database administrators trained
- [ ] Backend developers trained
- [ ] Frontend developers trained
- [ ] QA team trained
- [ ] DevOps team trained

### User Training
- [ ] Investigators trained
- [ ] Site coordinators trained
- [ ] Patients onboarded
- [ ] Analysts trained
- [ ] Admin staff trained

---

## Go-Live

### Pre-Launch Checklist
- [ ] All tests passing
- [ ] Performance benchmarks met
- [ ] Security review completed
- [ ] Compliance review completed
- [ ] Backup verified
- [ ] Monitoring active
- [ ] Team trained
- [ ] Documentation complete
- [ ] Support plan ready
- [ ] Rollback plan documented

### Production Environment Configuration 
- [ ] Set environment: `ALTER DATABASE SET app.environment = 'production'`
- [ ] Verify state modification triggers enabled: `SELECT COUNT(*) FROM pg_trigger WHERE tgname LIKE 'prevent_direct_state%'` (should be 2)
- [ ] Test that direct state updates are blocked (should fail with error)
- [ ] Verify audit trail continues to update state via triggers
- [ ] Document environment setting in production runbook

### Launch
- [ ] Enable production database
- [ ] Migrate initial data (if any)
- [ ] Update DNS/endpoints
- [ ] Enable monitoring
- [ ] Announce to users
- [ ] Monitor closely for 24-48 hours
- [ ] Address any issues immediately

### Post-Launch
- [ ] Verify all systems operational
- [ ] Check monitoring dashboards
- [ ] Review logs for errors
- [ ] Gather user feedback
- [ ] Document any issues
- [ ] Schedule post-mortem meeting

---

## Maintenance Schedule

### Daily
- [ ] Review error logs
- [ ] Check unresolved conflicts
- [ ] Monitor system health
- [ ] Review security alerts
- [ ] Verify state protection triggers enabled (production): `SELECT COUNT(*) FROM pg_trigger WHERE tgname LIKE 'prevent_direct_state%'`

### Weekly
- [ ] Refresh materialized views (if not automated)
- [ ] Review performance metrics
- [ ] Check backup success
- [ ] Review user feedback
- [ ] Update documentation as needed

### Monthly
- [ ] Review database growth
- [ ] Analyze query performance
- [ ] Review security logs
- [ ] Update dependencies
- [ ] Review compliance status
- [ ] Team sync meeting

### Quarterly
- [ ] Full security audit
- [ ] Performance review
- [ ] Capacity planning
- [ ] Disaster recovery drill
- [ ] Compliance audit
- [ ] Update disaster recovery plan

---

## Emergency Contacts

```
Database Admin: __________________
GCP Support: Via GCP Console (depends on support plan)
On-Call Engineer: __________________
Security Team: __________________
Compliance Officer: __________________
```

---

## Version History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-XX-XX | Initial deployment | _______ |
| | | | |

---

## Sign-Off

- [ ] Database Administrator: _________________ Date: _______
- [ ] Security Officer: _________________ Date: _______
- [ ] Compliance Officer: _________________ Date: _______
- [ ] Project Manager: _________________ Date: _______

---

**Notes:**
Use this checklist for each environment (dev, staging, production).
Mark items as complete only when verified and tested.
Keep this document updated as procedures change.

# Callisto Clinical Trial Portal

**Sponsor**: Callisto Clinical Trials
**Type**: Flutter Web Application
**Status**: Development / Scaffold
**Version**: 1.0.0

---

## Overview

The Callisto Portal is a web-based clinical trial management system for Admins, Investigators, and Auditors. It enables user management, patient enrollment, patient monitoring, and questionnaire management.

### Key Features

- **Role-Based Access Control**: Three roles with distinct permissions
  - **Admin**: User management, patient overview
  - **Investigator**: Patient enrollment, monitoring, questionnaire management
  - **Auditor**: Read-only access to all data, compliance exports (stub)

- **Patient Enrollment**: Generate unique linking codes for mobile app connection
- **Patient Monitoring**: Real-time engagement tracking with status indicators
- **Questionnaire Management**: Send NOSE HHT and QoL questionnaires to patients
- **Token Revocation**: Revoke access for users and patient devices

---

## Implementation Status

### ✅ Completed
- Flutter Web project structure
- Supabase authentication integration
- Material Design 3 theme
- Routing with go_router
- Login page
- Admin dashboard (user management, patient overview)
- Investigator dashboard (patient enrollment, monitoring, questionnaires)
- Auditor dashboard (read-only view, export stub)
- Requirement traceability headers

### 🚧 In Progress / TODO
- Supabase database setup (needs credentials)
- Database schema deployment
- RLS policies activation
- Actual branding assets (using placeholders)
- Testing with real data
- Deployment to hosting platform

---

## Requirements Implemented

This portal implements the following requirements from spec/:

- **REQ-p00009**: Sponsor-Specific Web Portals
- **REQ-p00024**: Portal User Roles and Permissions
- **REQ-p00025**: Patient Enrollment Workflow
- **REQ-p00026**: Patient Monitoring Dashboard
- **REQ-p00027**: Questionnaire Management
- **REQ-p00028**: Token Revocation and Access Control
- **REQ-p00029**: Auditor Dashboard and Data Export
- **REQ-d00028**: Portal Frontend Framework
- **REQ-d00029**: Portal UI Design System

---

## Architecture

### Technology Stack
- **Framework**: Flutter 3.24+ (Web)
- **Language**: Dart 3.5+
- **Backend**: Supabase (PostgreSQL + Auth + Realtime)
- **Routing**: go_router 14.0+
- **State Management**: provider 6.1+
- **UI**: Material Design 3

### Project Structure
```
apps/portal/
├── lib/
│   ├── main.dart                      # App entry point
│   ├── config/
│   │   └── database_config.dart       # Multi-environment database configuration
│   ├── services/
│   │   ├── database_service.dart      # Database abstraction interface
│   │   ├── local_database_service.dart # Local mock database (dev)
│   │   ├── supabase_database_service.dart # Supabase implementation (qa/prod)
│   │   └── auth_service.dart          # Authentication service
│   ├── router/
│   │   └── app_router.dart            # Route configuration
│   ├── theme/
│   │   └── portal_theme.dart          # Material Design 3 theme
│   ├── widgets/
│   │   ├── portal_app_bar.dart        # App bar with user info
│   │   └── portal_drawer.dart         # Navigation drawer
│   └── pages/
│       ├── login_page.dart
│       ├── admin/
│       │   ├── admin_dashboard_page.dart
│       │   ├── user_management_tab.dart
│       │   └── patients_overview_tab.dart
│       ├── investigator/
│       │   ├── investigator_dashboard_page.dart
│       │   ├── patient_enrollment_tab.dart
│       │   └── patient_monitoring_tab.dart
│       └── auditor/
│           └── auditor_dashboard_page.dart
├── web/
│   ├── index.html                     # Web entry point
│   └── manifest.json                  # PWA manifest
└── pubspec.yaml                       # Dependencies
```

### Database Abstraction Layer

The portal uses a **database abstraction layer** to support multiple environments without code changes:

- **`DatabaseService`** (interface): Abstract interface defining all database operations
- **`LocalDatabaseService`**: Mock implementation with in-memory test data (dev environment)
- **`SupabaseDatabaseService`**: Production implementation using Supabase (qa/prod environments)
- **`DatabaseConfig`**: Configuration controller that selects the appropriate implementation based on build-time environment variables

Benefits:
- Develop and test without Supabase credentials
- Environment-specific configuration at build time
- Clean separation of concerns
- Easy to add additional implementations (SQLite, Firebase, etc.)

---

## Getting Started

### Prerequisites
- Flutter 3.24+ installed
- Dart 3.5+
- Chrome browser (for development)
- Supabase account and project

### Setup Steps

1. **Clone the repository**
   ```bash
   cd /home/mclew/dev24/diary
   ```

2. **Navigate to portal directory**
   ```bash
   cd apps/portal
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Configure Supabase**
   - Create a Supabase project at https://supabase.com
   - Deploy database schema from `database/schema.sql`
   - Copy credentials to `sponsor/config/callisto/supabase.env`
   - Update `lib/config/supabase_config.dart` with actual credentials

5. **Run development server**
   ```bash
   flutter run -d chrome
   ```

6. **Build for production**
   ```bash
   flutter build web --release --web-renderer html
   ```
   Output: `build/web/` (deploy to Netlify, Vercel, or Cloudflare Pages)

---

## Database Setup

### Required Tables
The portal requires the following database tables (defined in `database/schema.sql`):

- `sites` - Clinical trial sites
- `portal_users` - Portal user accounts (Admins, Investigators, Auditors)
- `patients` - Enrolled patients
- `questionnaires` - Questionnaire tracking (NOSE HHT, QoL)
- `user_site_access` - Site assignments for Investigators
- `record_audit` - Event sourcing audit trail

### RLS Policies
Row-Level Security policies enforce access control:
- Admins: Full access to users and patients
- Investigators: Access only to assigned sites
- Auditors: Read-only access to all data

Deploy RLS policies from `database/rls_policies.sql`.

---

## Configuration

### Multi-Environment Setup

The portal supports three environments via build-time environment variables:

1. **Dev** (local): Uses `LocalDatabaseService` with mock in-memory data
2. **QA/UAT**: Uses `SupabaseDatabaseService` with QA Supabase instance
3. **Prod/Mgmt**: Uses `SupabaseDatabaseService` with production Supabase instance

Environment variables are set using `--dart-define` flags at build/run time. **The app will fail to start if the environment is not properly configured** - no silent defaults.

### Build Commands

**Development (local mock database)**:
```bash
flutter run -d chrome --dart-define=DB_ENV=dev
```

**QA/UAT (Supabase QA instance)**:
```bash
flutter run -d chrome \
  --dart-define=DB_ENV=qa \
  --dart-define=SUPABASE_URL=https://qa-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=qa-anon-key-here
```

**Production (Supabase prod instance)**:
```bash
flutter build web --release \
  --dart-define=DB_ENV=prod \
  --dart-define=SUPABASE_URL=https://prod-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=prod-anon-key-here
```

### Automatic Environment Configuration

In deployed environments (QA, Prod), the deployment platform automatically sets environment variables:

- **Netlify/Vercel**: Configure env vars in dashboard, use build command with `--dart-define`
- **GitHub Actions**: Use secrets and pass via build command
- **Cloudflare Pages**: Configure env vars, inject via build script

Users should **never manually enter credentials** - the deployment environment determines the configuration automatically.

### Legacy Configuration (Deprecated)

Previously used `sponsor/config/callisto/supabase.env` file - this approach is deprecated in favor of build-time environment variables.

### Branding
Replace placeholder assets in `sponsor/assets/callisto/`:
- `logo.png` (200x60px)
- `icon.png` (512x512px)
- `favicon.png` (32x32px)

---

## Development Workflow

### Running Tests
```bash
flutter test
```

### Local Development
```bash
# Run with local mock database (recommended for development)
flutter run -d chrome --dart-define=DB_ENV=dev

# Press 'r' to hot reload
# Press 'R' to hot restart
```

### Testing with QA Database
```bash
# Run with QA Supabase instance
flutter run -d chrome \
  --dart-define=DB_ENV=qa \
  --dart-define=SUPABASE_URL=$QA_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$QA_SUPABASE_ANON_KEY
```

### Building
```bash
# Development build (local mock)
flutter build web --dart-define=DB_ENV=dev

# QA/UAT build
flutter build web --release \
  --dart-define=DB_ENV=qa \
  --dart-define=SUPABASE_URL=$QA_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$QA_SUPABASE_ANON_KEY

# Production build
flutter build web --release \
  --dart-define=DB_ENV=prod \
  --dart-define=SUPABASE_URL=$PROD_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$PROD_SUPABASE_ANON_KEY
```

---

## Deployment

### Netlify (Recommended)

**QA Environment**:
1. Configure environment variables in Netlify dashboard:
   - `QA_SUPABASE_URL`: QA Supabase project URL
   - `QA_SUPABASE_ANON_KEY`: QA Supabase anon key
2. Build command:
   ```bash
   flutter build web --release \
     --dart-define=DB_ENV=qa \
     --dart-define=SUPABASE_URL=$QA_SUPABASE_URL \
     --dart-define=SUPABASE_ANON_KEY=$QA_SUPABASE_ANON_KEY
   ```
3. Publish directory: `build/web/`
4. Custom domain: `qa-portal.example.com`

**Production Environment**:
1. Configure environment variables in Netlify dashboard:
   - `PROD_SUPABASE_URL`: Production Supabase project URL
   - `PROD_SUPABASE_ANON_KEY`: Production Supabase anon key
2. Build command:
   ```bash
   flutter build web --release \
     --dart-define=DB_ENV=prod \
     --dart-define=SUPABASE_URL=$PROD_SUPABASE_URL \
     --dart-define=SUPABASE_ANON_KEY=$PROD_SUPABASE_ANON_KEY
   ```
3. Publish directory: `build/web/`
4. Custom domain: `portal.example.com`

### Vercel

Configure environment variables in Vercel dashboard, then use build command:
```bash
flutter build web --release \
  --dart-define=DB_ENV=$DEPLOY_ENV \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### Cloudflare Pages

Configure environment variables in Pages dashboard, then inject via build script:
```bash
#!/bin/bash
flutter build web --release \
  --dart-define=DB_ENV=$CF_PAGES_BRANCH \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### GitHub Actions CI/CD

Example workflow:
```yaml
name: Deploy Portal
on:
  push:
    branches: [main, qa]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - name: Build
        run: |
          flutter build web --release \
            --dart-define=DB_ENV=${{ github.ref == 'refs/heads/main' && 'prod' || 'qa' }} \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
      - name: Deploy
        # Deploy to hosting platform
```

---

## User Workflows

### Admin Creates Investigator
1. Login as Admin
2. Navigate to User Management tab
3. Click "Create User"
4. Enter name, email, select "Investigator" role
5. Assign clinical sites
6. System generates linking code
7. Share code with investigator for device linking

### Investigator Enrolls Patient
1. Login as Investigator
2. Navigate to Patient Enrollment tab
3. Enter patient ID from IRT (format: SSS-PPPPPPP)
4. Select clinical site
5. Click "Enroll Patient"
6. System generates 10-character linking code
7. Share code with patient for mobile app setup

### Investigator Monitors Patients
1. Navigate to Patient Monitoring tab
2. View patient list with status badges:
   - **Green (Active)**: Data entered within 3 days
   - **Yellow (Attention)**: 4-7 days without data
   - **Red (At Risk)**: 7+ days without data
   - **Grey (No Data)**: Never entered data
3. Send questionnaires (NOSE HHT, QoL) to patients
4. Acknowledge completed questionnaires
5. Review summary statistics

### Auditor Reviews Data
1. Login as Auditor
2. View all users and patients (read-only)
3. Review compliance metrics
4. Export database (stub - to be implemented)

---

## Security

### Authentication
- Supabase Auth with email/password
- OAuth support (Google, Microsoft) configurable
- Session management via Supabase

### Authorization
- Role-based access control (RBAC) enforced at application layer
- Row-Level Security (RLS) policies at database layer
- Site-based data isolation for Investigators

### Audit Trail
- All actions logged via Supabase triggers
- Immutable event store in `record_audit` table
- Compliant with FDA 21 CFR Part 11

---

## Compliance

This portal is designed to meet:
- **FDA 21 CFR Part 11**: Electronic records and signatures
- **ALCOA+ Principles**: Attributable, Legible, Contemporaneous, Original, Accurate
- **HIPAA**: De-identified patient data (no PHI/PII stored)
- **GDPR**: Data protection by design

See `spec/prd-clinical-trials.md` for complete compliance requirements.

---

## Troubleshooting

### Common Issues

**Supabase connection error**
- Check `lib/config/supabase_config.dart` has correct URL and keys
- Verify Supabase project is active
- Check browser console for CORS errors

**Authentication fails**
- Verify user exists in `portal_users` table
- Check user has correct role assigned
- Ensure RLS policies are deployed

**Patients not appearing**
- Check Investigator has assigned sites in `user_site_access` table
- Verify patients are linked to correct sites
- Ensure RLS policies allow access

**Build errors**
- Run `flutter clean && flutter pub get`
- Verify Flutter version: `flutter --version`
- Check for missing dependencies

---

## Next Steps

### Before Production Deployment
1. ✅ Deploy database schema to Supabase
2. ✅ Configure RLS policies
3. ✅ Create initial admin user
4. ✅ Add real branding assets
5. ✅ Set up custom domain
6. ✅ Configure SSL certificate
7. ✅ Load test with realistic data
8. ✅ Security audit
9. ✅ UAT with sponsor stakeholders
10. ✅ Document deployment procedures

### Future Enhancements
- Database export functionality (REQ-p00029)
- Advanced reporting and analytics
- Mobile app integration (push notifications)
- EDC synchronization (proxy mode)
- Multi-language support
- Accessibility improvements (WCAG 2.1 AA)

---

## Support

**Technical Questions**: See `docs/dev-environment-setup.md`
**Deployment Issues**: See `spec/ops-portal.md`
**Compliance Questions**: See `spec/prd-clinical-trials.md`

**Contact**: support@callisto-trials.example.com

---

## License

Proprietary - Callisto Clinical Trials

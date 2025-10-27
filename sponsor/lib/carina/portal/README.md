# Carina Clinical Trial Portal

**Sponsor**: Carina Clinical Trials
**Type**: Flutter Web Application
**Status**: Development / Scaffold
**Version**: 1.0.0

---

## Overview

The Carina Portal is a web-based clinical trial management system for Admins, Investigators, and Auditors. It enables user management, patient enrollment, patient monitoring, and questionnaire management.

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
sponsor/lib/carina/portal/
├── lib/
│   ├── main.dart                      # App entry point
│   ├── config/
│   │   └── supabase_config.dart       # Supabase configuration
│   ├── services/
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
   cd sponsor/lib/carina/portal
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Configure Supabase**
   - Create a Supabase project at https://supabase.com
   - Deploy database schema from `database/schema.sql`
   - Copy credentials to `sponsor/config/carina/supabase.env`
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

### Environment Variables
Create `sponsor/config/carina/supabase.env`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
```

**NEVER commit this file to git!**

### Branding
Replace placeholder assets in `sponsor/assets/carina/`:
- `logo.png` (200x60px)
- `icon.png` (512x512px)
- `favicon.png` (32x32px)

---

## Development Workflow

### Running Tests
```bash
flutter test
```

### Hot Reload
```bash
flutter run -d chrome
# Press 'r' to hot reload
# Press 'R' to hot restart
```

### Building
```bash
# Development build
flutter build web

# Production build
flutter build web --release --web-renderer html
```

---

## Deployment

### Netlify (Recommended)
1. Build the web app: `flutter build web --release`
2. Deploy `build/web/` to Netlify
3. Configure environment variables in Netlify dashboard
4. Custom domain: `carina-portal.example.com`

### Vercel
1. Build: `flutter build web --release --web-renderer html`
2. Deploy `build/web/` to Vercel
3. Configure environment variables

### Cloudflare Pages
1. Build: `flutter build web --release`
2. Deploy `build/web/` to Cloudflare Pages
3. Configure Workers for environment variables

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

**Contact**: support@carina-trials.example.com

---

## License

Proprietary - Carina Clinical Trials

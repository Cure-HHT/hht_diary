# Carina Sponsor Implementation

**Sponsor**: Carina Clinical Trials
**Codename**: Carina (constellation)
**Status**: Development / Scaffold
**Type**: Multi-sponsor clinical diary portal and mobile app

---

## Directory Structure

This sponsor directory is **self-contained** and can be moved/archived as a single unit:

```
sponsor-carina/
├── lib/                      # Dart implementations
│   ├── carina_config.dart            # Sponsor configuration
│   └── portal/                       # Flutter Web portal application
│       ├── lib/                      # Portal source code
│       │   ├── config/               # Supabase configuration
│       │   ├── services/             # Authentication, data services
│       │   ├── router/               # App routing
│       │   ├── theme/                # Material Design 3 theme
│       │   ├── pages/                # Dashboard pages
│       │   │   ├── admin/            # Admin dashboard
│       │   │   ├── investigator/     # Investigator dashboard
│       │   │   └── auditor/          # Auditor dashboard
│       │   └── widgets/              # Shared UI components
│       ├── web/                      # Web entry point
│       ├── pubspec.yaml              # Dependencies
│       └── README.md                 # Portal documentation
│
├── config/                   # Configuration files
│   ├── portal.yaml                   # Portal configuration
│   ├── mobile.yaml                   # Mobile app configuration
│   ├── supabase.env.example          # Credentials template
│   └── .gitignore                    # Secrets protection
│
├── assets/                   # Branding assets
│   ├── logo.svg                      # Main logo (placeholder)
│   ├── icon.png                      # App icon (placeholder)
│   └── README.md                     # Asset guidelines
│
├── edge_functions/           # Edge Functions (EDC integration)
│   └── (empty - endpoint mode)
│
├── spec/                     # Sponsor-specific requirements
│   └── (empty - to be imported from Google Docs)
│
└── README.md                 # This file
```

---

## Features Implemented

### Portal (Flutter Web)
- **Admin Dashboard**: User management, patient overview, linking codes
- **Investigator Dashboard**: Patient enrollment, monitoring, questionnaire management
- **Auditor Dashboard**: Read-only compliance view, database export (stub)
- **Authentication**: Supabase Auth with role-based access control
- **Material Design 3**: Modern, responsive UI
- **Patient Monitoring**: Real-time engagement tracking with status indicators
- **Questionnaire Management**: NOSE HHT and Quality of Life questionnaires

### Status Indicators
- 🟢 **Green (Active)**: <3 days since last data entry
- 🟡 **Yellow (Attention)**: 4-7 days since last entry
- 🔴 **Red (At Risk)**: 7+ days since last entry
- ⚪ **Grey (No Data)**: Never entered data

### Linking Codes
- Format: `XXXXX-XXXXX` (10 characters)
- Non-ambiguous characters (excludes 0, O, 1, I, l)
- Generated for both users and patients
- Secure randomization using UUID + timestamp

---

## Technology Stack

- **Framework**: Flutter 3.24+ (Web)
- **Language**: Dart 3.5+
- **Backend**: Supabase (PostgreSQL + Auth + Realtime)
- **Routing**: go_router 14.0+
- **State Management**: provider 6.1+
- **UI**: Material Design 3

---

## Getting Started

### Prerequisites
- Flutter 3.24+ installed
- Dart 3.5+
- Chrome browser (for development)
- Supabase account and project

### Setup Steps

1. **Navigate to portal directory**
   ```bash
   cd sponsor-carina/lib/portal
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create Supabase project at https://supabase.com
   - Deploy database schema from `../../database/schema.sql`
   - Copy `sponsor-carina/config/supabase.env.example` to `supabase.env`
   - Update `lib/portal/lib/config/supabase_config.dart` with credentials

4. **Run development server**
   ```bash
   flutter run -d chrome
   ```

5. **Build for production**
   ```bash
   flutter build web --release --web-renderer html
   ```

---

## Configuration

### Environment Variables
Create `sponsor-carina/config/supabase.env`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
```

**NEVER commit this file to git!** (Protected by `.gitignore`)

### Branding
Replace placeholder assets in `sponsor-carina/assets/`:
- `logo.png` (200x60px, transparent)
- `icon.png` (512x512px)
- `favicon.png` (32x32px)

---

## Requirements Implemented

This sponsor implementation covers:

**PRD Requirements**:
- REQ-p00003: Separate Database Per Sponsor
- REQ-p00007: Automatic Sponsor Configuration
- REQ-p00008: Single Mobile App for All Sponsors
- REQ-p00009: Sponsor-Specific Web Portals
- REQ-p00014: Authentication and Authorization
- REQ-p00024: Portal User Roles and Permissions
- REQ-p00025: Patient Enrollment Workflow
- REQ-p00026: Patient Monitoring Dashboard
- REQ-p00027: Questionnaire Management
- REQ-p00028: Token Revocation and Access Control
- REQ-p00029: Auditor Dashboard and Data Export

**Dev Requirements**:
- REQ-d00028: Portal Frontend Framework
- REQ-d00029: Portal UI Design System

See `spec/prd-portal.md` and `spec/dev-portal.md` for complete requirements.

---

## Deployment

### Portal Deployment
1. Build: `flutter build web --release --web-renderer html`
2. Deploy `build/web/` to Netlify/Vercel/Cloudflare Pages
3. Configure environment variables
4. Custom domain: `carina-portal.example.com`

### Database Setup
1. Create Supabase project
2. Deploy `database/schema.sql`
3. Deploy `database/rls_policies.sql`
4. Create seed data (sites, admin user)

---

## Next Steps

### Before Production
- [ ] Create Supabase project
- [ ] Deploy database schema and RLS policies
- [ ] Configure credentials in `config/supabase.env`
- [ ] Replace placeholder branding assets
- [ ] Test with real data
- [ ] Deploy portal to hosting platform
- [ ] Set up custom domain and SSL

### Future Enhancements
- [ ] Database export functionality (REQ-p00029)
- [ ] Advanced reporting and analytics
- [ ] Mobile app integration (push notifications)
- [ ] EDC synchronization (proxy mode)
- [ ] Multi-language support
- [ ] Accessibility improvements (WCAG 2.1 AA)

---

## Architecture

This sponsor follows the **multi-sponsor architecture** defined in:
- `spec/prd-architecture-multi-sponsor.md` - Product architecture
- `spec/dev-architecture-multi-sponsor.md` - Development architecture

### Key Principles
- **Self-Contained**: Entire sponsor in single directory
- **Sponsor Isolation**: Separate Supabase instance per sponsor
- **Shared Schema**: Same database schema across all sponsors
- **Independent Deployment**: Portal and mobile app deployed separately
- **Role-Based Access**: Admin, Investigator, Auditor roles

---

## Support

**Portal Documentation**: `lib/portal/README.md`
**Asset Guidelines**: `assets/README.md`
**Configuration Template**: `config/supabase.env.example`

**Technical Questions**: See root `spec/` directory
**Deployment Issues**: See `spec/ops-portal.md`
**Compliance Questions**: See `spec/prd-clinical-trials.md`

---

## License

Proprietary - Carina Clinical Trials

---

## Moving This Sponsor

This entire directory is **self-contained** and can be:
- **Moved**: `mv sponsor-carina /path/to/archive/`
- **Archived**: `tar -czf carina-2025-10-27.tar.gz sponsor-carina/`
- **Shared**: `zip -r carina-portal.zip sponsor-carina/` (exclude `config/supabase.env`)
- **Version Controlled**: Separate git repo if needed

No dependencies on parent directory structure (except core platform database schema).

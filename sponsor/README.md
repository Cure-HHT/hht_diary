# Sponsor-Specific Implementations

This directory contains sponsor-specific code, configuration, and assets for the multi-sponsor Clinical Diary platform.

## Directory Structure

```
sponsor/
├── lib/                      # Sponsor implementations (Dart code)
│   └── {sponsor}/
│       ├── {sponsor}_config.dart      # Sponsor configuration
│       ├── {sponsor}_edc_sync.dart    # EDC integration (if proxy mode)
│       ├── {sponsor}_theme.dart       # Branding theme
│       └── portal/                    # Portal application
│
├── config/                   # Sponsor configurations (GITIGNORED for secrets!)
│   └── {sponsor}/
│       ├── mobile.yaml                # Mobile app config
│       ├── portal.yaml                # Portal config
│       └── supabase.env               # Supabase credentials (NEVER commit!)
│
├── assets/                   # Sponsor branding assets
│   └── {sponsor}/
│       ├── logo.png                   # Main logo
│       ├── icon.png                   # App icon
│       └── favicon.png                # Browser favicon
│
├── edge_functions/           # Sponsor Edge Functions (EDC integration)
│   └── {sponsor}/
│       └── edc_sync/                  # EDC synchronization functions
│
└── spec/                     # Sponsor-specific requirements
    └── {sponsor}/
        └── (imported from Google Docs later)
```

---

## Current Sponsors

### Carina

**Status**: Development / Scaffold
**Codename**: Carina (constellation)
**Mode**: Endpoint (no EDC sync)

**Implemented**:
- ✅ Portal application (Flutter Web)
- ✅ Configuration files (mobile, portal)
- ✅ Branding placeholders
- ✅ Requirement traceability

**Location**: `sponsor/lib/carina/portal/`
**Documentation**: See `sponsor/lib/carina/portal/README.md`

---

## Adding a New Sponsor

### 1. Choose Astronomical Codename
Select an astronomical phenomenon (constellation, star, nebula) for the sponsor codename.
Examples: Orion, Andromeda, Vega, Polaris, Nebula

### 2. Create Directory Structure
```bash
mkdir -p sponsor/lib/{sponsor}
mkdir -p sponsor/config/{sponsor}
mkdir -p sponsor/assets/{sponsor}
mkdir -p sponsor/edge_functions/{sponsor}
mkdir -p sponsor/spec/{sponsor}
```

### 3. Create Configuration Files
- `sponsor/config/{sponsor}/portal.yaml` - Portal configuration
- `sponsor/config/{sponsor}/mobile.yaml` - Mobile app configuration
- `sponsor/config/{sponsor}/supabase.env.example` - Credentials template

### 4. Add Branding Assets
- Logo: 200x60px PNG with transparency
- Icon: 512x512px PNG
- Favicon: 32x32px PNG

### 5. Implement Sponsor Code
- Create `{sponsor}_config.dart` extending `SponsorConfig`
- If proxy mode: implement `{sponsor}_edc_sync.dart` extending `EdcSync`
- Create portal application in `sponsor/lib/{sponsor}/portal/`

### 6. Deploy Database
- Create Supabase project for sponsor
- Deploy schema from `database/schema.sql`
- Deploy RLS policies from `database/rls_policies.sql`
- Configure credentials in `sponsor/config/{sponsor}/supabase.env`

---

## Sponsor Isolation

Each sponsor operates completely independently:
- **Separate Supabase project** (database instance)
- **Separate portal deployment** (unique URL)
- **Independent user accounts**
- **Isolated audit trails**
- **No cross-sponsor data access**

The mobile app contains **all** sponsor configurations bundled, with dynamic selection based on enrollment link.

---

## Security

### Secrets Management
**CRITICAL**: Never commit secrets to git!

- Supabase credentials stored in `.env` files (gitignored)
- Environment variables used in production
- GitHub Secrets for CI/CD
- Separate credentials per environment (dev, staging, production)

### Access Control
- Admin: Full user and patient management
- Investigator: Site-scoped patient access
- Auditor: Read-only compliance access

See `spec/prd-security-RBAC.md` for complete RBAC specification.

---

## Configuration Format

### portal.yaml
```yaml
sponsor:
  id: sponsor_id
  name: Sponsor Display Name

branding:
  primary_color: "#0175C2"
  logo: sponsor/assets/sponsor/logo.png

features:
  patient_enrollment: true
  questionnaires: true
  edc_sync: false

urls:
  production: https://sponsor-portal.example.com
```

### supabase.env
```env
SUPABASE_URL=https://project.supabase.co
SUPABASE_ANON_KEY=anon-key-here
SUPABASE_SERVICE_ROLE_KEY=service-role-key-here
```

**NEVER commit this file!** Copy from `.env.example` template.

---

## Build System

The build system composes core platform code with sponsor-specific code at build time.

### Build Commands
```bash
# Validate sponsor implementation
dart tools/build_system/validate_sponsor.dart --sponsor carina

# Build mobile app
dart tools/build_system/build_mobile.dart --sponsor carina --platform ios

# Build portal
dart tools/build_system/build_portal.dart --sponsor carina --environment production

# Deploy
dart tools/build_system/deploy.dart --sponsor carina --environment production
```

**Note**: Build system tools are planned for future implementation.

---

## Deployment

### Portal Deployment
1. Build Flutter Web app: `flutter build web --release`
2. Deploy to Netlify/Vercel/Cloudflare Pages
3. Configure custom domain: `{sponsor}-portal.example.com`
4. Set environment variables for Supabase credentials

### Mobile App Deployment
1. Build with all sponsor configs bundled
2. Single app submission to App Store and Google Play
3. Dynamic sponsor selection via enrollment link
4. Updates benefit all sponsors simultaneously

---

## Testing

### Sponsor Validation
```bash
# Run contract tests
flutter test test/contracts/

# Validate sponsor config
dart tools/build_system/validate_sponsor.dart --sponsor carina
```

### Integration Testing
```bash
# Test against Supabase staging
flutter test integration_test/
```

---

## Requirements Traceability

All sponsor code includes requirement traceability headers:

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-d00028: Portal Frontend Framework
```

Validate with:
```bash
python3 tools/requirements/validate_requirements.py
```

---

## Support

**Architecture Questions**: See `spec/prd-architecture-multi-sponsor.md`
**Development Guide**: See `spec/dev-architecture-multi-sponsor.md`
**Deployment Procedures**: See `spec/ops-deployment.md`

---

## Repository Pattern

This follows the **monorepo pattern** with sponsor-specific code in `sponsor/` directory:

- ✅ Single source of truth for core platform
- ✅ Sponsor-specific extensions isolated
- ✅ Version control for all components
- ✅ Shared CI/CD pipelines
- ✅ Atomic updates across core + sponsors

See `spec/prd-architecture-multi-sponsor.md` for complete architecture details.

---

## License

Proprietary - Individual sponsor implementations are confidential to their respective sponsors.

# Sponsor Directory Structure

This document describes the organization of sponsor-specific implementations in the multi-sponsor Clinical Diary platform.

---

## Directory Pattern

Each sponsor is a **self-contained directory** at the root level:

```
clinical-diary/
├── sponsor-{name}/              # Self-contained sponsor implementation
│   ├── lib/                     # Dart code (config, portal, mobile extensions)
│   ├── config/                  # Configuration files (GITIGNORED secrets!)
│   ├── assets/                  # Branding (logos, icons, fonts)
│   ├── edge_functions/          # Sponsor-specific Edge Functions
│   └── spec/                    # Sponsor-specific requirements
│
├── database/                    # SHARED schema (deployed per-sponsor)
├── spec/                        # Core platform specifications
└── docs/                        # Architecture Decision Records
```

---

## Current Sponsors

### Carina
**Status**: Development / Scaffold
**Directory**: `sponsor-carina/`
**Mode**: Endpoint (no EDC sync)
**Codename**: Carina (constellation)

**Implemented**:
- ✅ Flutter Web portal (Admin, Investigator, Auditor dashboards)
- ✅ Configuration files (portal.yaml, mobile.yaml)
- ✅ Placeholder branding assets
- ✅ Full requirement traceability

**Documentation**: See `sponsor-carina/README.md`

---

## Adding a New Sponsor

### 1. Create Directory
```bash
mkdir -p sponsor-{name}/{lib,config,assets,edge_functions,spec}
```

### 2. Choose Codename
Select an astronomical phenomenon (constellation, star, nebula, etc.):
- Examples: Orion, Andromeda, Vega, Polaris, Nebula, Carina

### 3. Implement Configuration
Create in `sponsor-{name}/config/`:
- `portal.yaml` - Portal configuration
- `mobile.yaml` - Mobile app configuration
- `supabase.env.example` - Credentials template
- `.gitignore` - Protect secrets

### 4. Add Branding
Create in `sponsor-{name}/assets/`:
- `logo.png` (200x60px, transparent)
- `icon.png` (512x512px)
- `favicon.png` (32x32px)

### 5. Implement Portal
Create Flutter Web app in `sponsor-{name}/lib/portal/`

### 6. Deploy Infrastructure
- Create Supabase project
- Deploy schema from `database/schema.sql`
- Deploy RLS policies from `database/rls_policies.sql`
- Configure credentials in `sponsor-{name}/config/supabase.env`

---

## Sponsor Isolation

Each sponsor operates **completely independently**:

| Aspect | Isolation Method |
|--------|------------------|
| **Database** | Separate Supabase project per sponsor |
| **Portal** | Unique URL per sponsor (e.g., `carina-portal.example.com`) |
| **Users** | Independent user accounts per sponsor |
| **Audit Trail** | Separate event logs per sponsor |
| **Configuration** | Isolated config files with gitignored secrets |
| **Data Access** | No cross-sponsor access possible |

The **mobile app** contains all sponsor configurations bundled, with dynamic selection based on enrollment link.

---

## Directory Benefits

### Self-Contained Units
✅ **Move**: `mv sponsor-carina /archive/`
✅ **Archive**: `tar -czf carina-2025-10-27.tar.gz sponsor-carina/`
✅ **Share**: `zip -r carina-portal.zip sponsor-carina/` (exclude secrets)
✅ **Independent Versioning**: Can be separate git repo if needed

### Clean Separation
- No subdirectory nesting under shared `sponsor/` directory
- Each sponsor directory is completely independent
- Easy to identify which files belong to which sponsor
- Simple to remove/archive old sponsors

---

## Security

### Secrets Management
**CRITICAL**: Never commit secrets to git!

Each sponsor has:
- `config/.gitignore` - Prevents committing secrets
- `config/supabase.env.example` - Template for credentials
- `config/supabase.env` - **GITIGNORED** actual credentials

### Access Control
Within each sponsor's portal:
- **Admin**: User management, patient overview
- **Investigator**: Patient enrollment, monitoring, questionnaires (site-scoped)
- **Auditor**: Read-only compliance access (all sites)

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
  logo: assets/logo.png

features:
  patient_enrollment: true
  questionnaires: true
  edc_sync: false

urls:
  production: https://sponsor-portal.example.com
```

### supabase.env (GITIGNORED!)
```env
SUPABASE_URL=https://project.supabase.co
SUPABASE_ANON_KEY=anon-key-here
SUPABASE_SERVICE_ROLE_KEY=service-role-key-here
```

---

## Build System (Planned)

The build system will compose core platform code with sponsor-specific code:

```bash
# Validate sponsor implementation
dart tools/build_system/validate_sponsor.dart --sponsor carina

# Build portal
dart tools/build_system/build_portal.dart --sponsor carina --env production

# Deploy
dart tools/build_system/deploy.dart --sponsor carina --env production
```

**Note**: Build tools planned for future implementation. Currently using manual build process.

---

## Deployment

### Portal
1. Navigate to `sponsor-{name}/lib/portal/`
2. Build: `flutter build web --release --web-renderer html`
3. Deploy `build/web/` to Netlify/Vercel/Cloudflare Pages
4. Configure custom domain: `{sponsor}-portal.example.com`
5. Set environment variables for Supabase credentials

### Mobile App
1. Build with all sponsor configs bundled
2. Single app submission to App Store and Google Play
3. Dynamic sponsor selection via enrollment link
4. Updates benefit all sponsors simultaneously

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

## Testing

### Sponsor Validation
```bash
# Validate sponsor configuration
dart tools/build_system/validate_sponsor.dart --sponsor carina

# Run tests
cd sponsor-carina/lib/portal
flutter test
```

### Integration Testing
```bash
# Test against Supabase staging
flutter test integration_test/
```

---

## Migration from Old Structure

If you have sponsors in the old `sponsor/lib/{name}/` structure:

```bash
# Create new sponsor directory
mkdir -p sponsor-{name}

# Move files
mv sponsor/lib/{name}/* sponsor-{name}/lib/
mv sponsor/config/{name}/* sponsor-{name}/config/
mv sponsor/assets/{name}/* sponsor-{name}/assets/

# Remove old structure
rm -rf sponsor/
```

---

## Support

**Architecture**: `spec/prd-architecture-multi-sponsor.md`
**Development**: `spec/dev-architecture-multi-sponsor.md`
**Deployment**: `spec/ops-deployment.md`
**Security**: `spec/prd-security-RBAC.md`

---

## References

- Multi-Sponsor Architecture: `spec/prd-architecture-multi-sponsor.md`
- Portal Requirements: `spec/prd-portal.md`
- Development Guide: `spec/dev-portal.md`
- Database Schema: `database/schema.sql`
- RLS Policies: `database/rls_policies.sql`

---

**Last Updated**: 2025-10-27
**Pattern**: Self-contained sponsor directories at root level

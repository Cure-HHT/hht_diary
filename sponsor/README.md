# Sponsor Directory

This directory contains all sponsor-specific implementations for the multi-sponsor Clinical Diary platform.

---

## Directory Structure

```
sponsor/
├── callisto/                    # Callisto sponsor (self-contained)
│   ├── lib/                     # Dart code (config, portal, mobile extensions)
│   ├── config/                  # Configuration files (GITIGNORED secrets!)
│   ├── assets/                  # Branding (logos, icons, fonts)
│   ├── edge_functions/          # Sponsor-specific Edge Functions
│   ├── spec/                    # Sponsor-specific requirements
│   └── README.md                # Sponsor-specific documentation
│
├── _template/                   # Template for new sponsors (future)
├── _abstractions/               # Shared sponsor abstractions (future)
└── README.md                    # This file
```

Each sponsor subdirectory is **self-contained** and can be moved/archived independently.

---

## Current Sponsors

### Callisto
**Status**: Development / Scaffold
**Directory**: `sponsor/callisto/`
**Mode**: Endpoint (no EDC sync)
**Codename**: Callisto (Jupiter's moon)

**Implemented**:
- ✅ Flutter Web portal (Admin, Investigator, Auditor dashboards)
- ✅ Configuration files (portal.yaml, mobile.yaml)
- ✅ Placeholder branding assets
- ✅ Full requirement traceability

**Documentation**: See `sponsor/callisto/README.md`

---

## Adding a New Sponsor

### 1. Create Directory
```bash
mkdir -p sponsor/{name}/{lib,config,assets,edge_functions,spec}
```

### 2. Choose Codename
Select an astronomical phenomenon (constellation, star, nebula, etc.):
- Examples: Orion, Andromeda, Vega, Polaris, Nebula, Callisto

### 3. Implement Configuration
Create in `sponsor/{name}/config/`:
- `portal.yaml` - Portal configuration
- `mobile.yaml` - Mobile app configuration
- `supabase.env.example` - Credentials template
- `.gitignore` - Protect secrets

### 4. Add Branding
Create in `sponsor/{name}/assets/`:
- `logo.png` (200x60px, transparent)
- `icon.png` (512x512px)
- `favicon.png` (32x32px)

### 5. Implement Portal
Create Flutter Web app in `sponsor/{name}/lib/portal/`

### 6. Deploy Infrastructure
- Create Supabase project
- Deploy schema from `../database/schema.sql`
- Deploy RLS policies from `../database/rls_policies.sql`
- Configure credentials in `sponsor/{name}/config/supabase.env`

---

## Sponsor Isolation

Each sponsor operates **completely independently**:

| Aspect | Isolation Method |
|--------|------------------|
| **Database** | Separate Supabase project per sponsor |
| **Portal** | Unique URL per sponsor (e.g., `callisto-portal.example.com`) |
| **Users** | Independent user accounts per sponsor |
| **Audit Trail** | Separate event logs per sponsor |
| **Configuration** | Isolated config files with gitignored secrets |
| **Data Access** | No cross-sponsor access possible |

The **mobile app** contains all sponsor configurations bundled, with dynamic selection based on enrollment link.

---

## Directory Benefits

### Self-Contained Units
✅ **Move**: `mv sponsor/callisto /archive/`
✅ **Archive**: `tar -czf callisto-2025-10-27.tar.gz sponsor/callisto/`
✅ **Share**: `zip -r callisto-portal.zip sponsor/callisto/` (exclude secrets)
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
dart tools/build_system/validate_sponsor.dart --sponsor callisto

# Build portal
dart tools/build_system/build_portal.dart --sponsor callisto --env production

# Deploy
dart tools/build_system/deploy.dart --sponsor callisto --env production
```

**Note**: Build tools planned for future implementation. Currently using manual build process.

---

## Deployment

### Portal
1. Navigate to `sponsor/{name}/lib/portal/`
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
dart tools/build_system/validate_sponsor.dart --sponsor callisto

# Run tests
cd sponsor-callisto/lib/portal
flutter test
```

### Integration Testing
```bash
# Test against Supabase staging
flutter test integration_test/
```

---

## Sponsor-Specific Build Reports

Each sponsor has dedicated build and validation reports that provide complete traceability for their specific implementation.

### Report Location

Sponsor-specific reports are generated in the centralized `build-reports/` directory:

```
build-reports/
├── callisto/             # Callisto sponsor reports
│   ├── traceability/     # Requirement-to-code mapping for Callisto
│   ├── test-results/     # Test execution results
│   └── validation/       # Validation reports
└── titan/                # Titan sponsor reports
    ├── traceability/
    ├── test-results/
    └── validation/
```

**See**: `../build-reports/README.md` for complete documentation on report structure and access.

### What Reports Are Available

**Traceability Reports**:
- Mapping of sponsor requirements to implementation code
- Test coverage by requirement
- Compliance validation for sponsor-specific features
- Generated from git history and source annotations

**Test Results**:
- Unit test results for sponsor-specific code (`sponsor/{name}/lib/`)
- Integration test results with sponsor Supabase instance
- End-to-end test results for sponsor portal
- Test coverage metrics (line, branch, function)

**Validation Reports**:
- Sponsor repository structure validation
- Configuration file validation (portal.yaml, mobile.yaml)
- Contract test compliance
- Branding asset validation
- Security scan results

### Accessing Reports

**Recent Builds (Last 90 Days)**:

GitHub Actions artifacts are available for recent builds:

```bash
# List recent workflow runs
gh run list --repo yourorg/clinical-diary

# Download artifacts for specific run
gh run download <run-id> --name build-reports-callisto
```

**Historical Reports (7+ Years)**:

Long-term archived reports are stored in AWS S3:

```bash
# List available reports for your sponsor
aws s3 ls s3://clinical-diary-build-reports/sponsors/callisto/

# Download specific release reports
aws s3 cp s3://clinical-diary-build-reports/sponsors/callisto/v2025.11.12.a/ \
  ./reports/ --recursive
```

**Note**: S3 access requires appropriate IAM permissions. Contact DevOps for access.

### Local Report Generation

Sponsors can generate reports locally for development and debugging:

```bash
# From sponsor repository root
cd clinical-diary

# Generate traceability for your sponsor
python3 tools/requirements/generate_traceability.py \
  --sponsor callisto \
  --output build-reports/callisto/traceability/

# Validate sponsor configuration
dart run tools/build_system/validate_sponsor.dart \
  --sponsor-repo ../clinical-diary-callisto \
  --output build-reports/callisto/validation/

# Run tests and generate coverage
cd ../clinical-diary-callisto
flutter test --coverage
genhtml coverage/lcov.info -o ../clinical-diary/build-reports/callisto/test-results/coverage/
```

**Note**: Locally generated reports are gitignored and not uploaded to S3.

### Report Contents

**Traceability Matrix**:
- Every REQ-xxxxx implemented in sponsor code
- Source files implementing each requirement
- Tests validating each requirement
- Git commits introducing each feature

**Test Execution Results**:
- Pass/fail status for all tests
- Execution time and performance metrics
- Code coverage percentages
- Failed test details with stack traces

**Validation Checklist**:
- Repository structure compliance
- Required files present (SponsorConfig, EdcSync, etc.)
- Contract test results
- No prohibited content (secrets, PII)
- Branding asset validation (size, format)

### FDA Compliance

All sponsor reports are retained for minimum 7 years per FDA 21 CFR Part 11 requirements:

**Tamper Evidence**:
- Each report includes SHA-256 checksum
- S3 object versioning prevents tampering
- Audit trail tracks who accessed what when

**Retention Policy**:

| Location | Retention | Access Method |
|----------|-----------|---------------|
| Local | Until cleaned | `build-reports/{sponsor}/` |
| GitHub Actions | 90 days | `gh run download` |
| S3 Standard | 90 days | AWS CLI/Console |
| S3 Glacier | 7+ years | AWS CLI (restore then download) |

**Audit Access**:

Sponsors can verify the integrity of archived reports:

```bash
# Download report and checksum
aws s3 cp s3://clinical-diary-build-reports/sponsors/callisto/v2025.11.12.a/traceability/matrix.json ./
aws s3 cp s3://clinical-diary-build-reports/sponsors/callisto/v2025.11.12.a/traceability/matrix.json.sha256 ./

# Verify integrity
sha256sum -c matrix.json.sha256
```

### CI/CD Integration

Reports are automatically generated during sponsor CI/CD workflows:

**On Pull Request**:
- Validation reports (structure, configuration)
- Contract test results
- Quick smoke test results

**On Main Branch Push**:
- Full test suite execution
- Complete traceability matrix
- Coverage reports

**On Release Tag**:
- Complete validation bundle
- Archival package with all reports
- Automatic upload to S3

**Workflow Configuration** (in sponsor repository):

```yaml
# .github/workflows/deploy_production.yml
- name: Generate Reports
  run: |
    cd ../clinical-diary
    python3 tools/requirements/generate_traceability.py \
      --sponsor callisto \
      --output build-reports/callisto/traceability/

- name: Upload Reports
  uses: actions/upload-artifact@v3
  with:
    name: build-reports-callisto
    path: build-reports/callisto/
    retention-days: 90

- name: Archive to S3
  run: |
    aws s3 sync build-reports/callisto/ \
      s3://clinical-diary-build-reports/sponsors/callisto/${GIT_TAG}/${TIMESTAMP}/
```

### Privacy and Isolation

**Complete Isolation**:
- Sponsor reports contain ONLY that sponsor's data
- No cross-sponsor information leakage
- Separate S3 paths per sponsor
- Independent access control per sponsor

**No Shared Data**:
- Reports do NOT include other sponsors' code
- Reports do NOT include other sponsors' test results
- Reports do NOT include cross-sponsor analysis

**Combined Reports**:
The `build-reports/combined/` directory contains aggregated reports for the core platform only. These reports:
- Aggregate data across all sponsors for core platform validation
- Do NOT expose sponsor-specific implementation details
- Used for core platform compliance and quality metrics

### Support

**Report Issues**:
If reports are missing, incomplete, or incorrect:

1. Check CI/CD workflow logs: `gh run view <run-id> --log`
2. Verify report generation scripts executed successfully
3. Check S3 for archived reports: `aws s3 ls s3://clinical-diary-build-reports/sponsors/{sponsor}/`
4. Contact DevOps if reports are permanently missing

**Documentation**:
- Build Reports: `../build-reports/README.md`
- Build System: `../spec/ops-deployment.md` (Build Reports section)
- ADR: `../docs/adr/ADR-007-multi-sponsor-build-reports.md`

---

## Templates and Abstractions

### _template/ (Future)
A template directory for quickly scaffolding new sponsors:
```bash
cp -r sponsor/_template sponsor/new-sponsor-name
# Then customize configuration and branding
```

### _abstractions/ (Future)
Shared code that multiple sponsors might use:
- Common EDC integration patterns
- Shared UI components
- Utility functions

**Note**: Keep abstractions minimal. Prefer sponsor isolation over code reuse.

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
**Pattern**: Self-contained sponsor subdirectories within sponsor/

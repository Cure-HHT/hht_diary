# Alternative Strategy: Public Monorepo + Portal Configuration

## Executive Summary

This document proposes an alternative to separate sponsor repos: a **public monorepo** where all sponsor-specific configuration is managed through the **sponsor portal** at runtime, not in git.

**Core Principle:** Code is public. Configuration is private and lives in the portal database.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    hht_diary (PUBLIC MONOREPO)                  │
│                                                                 │
│  ├── apps/clinical_diary/        # Mobile app                   │
│  ├── apps/portal/                # Sponsor portal               │
│  ├── packages/                   # Shared code                  │
│  ├── database/                   # Schema, migrations           │
│  ├── terraform/                  # Infrastructure               │
│  └── sponsor/                    # Generic sponsor templates    │
│       └── template/              # Default configs only         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ deploys
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Sponsor Portal (per sponsor)                 │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  Branding   │  │   Study     │  │  Mobile     │             │
│  │  - Logo     │  │   Config    │  │  Config     │             │
│  │  - Colors   │  │  - Forms    │  │  - Features │             │
│  │  - Strings  │  │  - Versions │  │  - Toggles  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                 │
│  Database: Sponsor-specific config stored in PostgreSQL         │
│  Assets: Branding files stored in GCS bucket (private)          │
└─────────────────────────────────────────────────────────────────┘
```

---

## What the Portal Manages

### 1. Branding Assets

Sponsors upload via portal UI:

```
Portal UI → GCS Bucket (private per sponsor)
├── logo.png           # App logo
├── logo_dark.png      # Dark mode variant
├── splash.png         # Splash screen
├── icon.png           # App icon (if white-label)
└── colors.json        # Brand colors
```

The mobile app fetches branding at startup:

```dart
class BrandingService {
  Future<BrandingConfig> loadBranding(String sponsorId) async {
    final response = await api.get('/api/v1/sponsors/$sponsorId/branding');
    return BrandingConfig.fromJson(response.data);
  }
}
```

### 2. Study Configuration

Portal database tables:

```sql
-- Sponsor study configuration
CREATE TABLE sponsor_study_config (
  sponsor_id UUID REFERENCES sponsors(id),

  -- Questionnaire versions
  questionnaire_versions JSONB NOT NULL DEFAULT '{}',
  -- e.g., {"epistaxis_daily": "v2.1", "quality_of_life": "v1.3"}

  -- GUI versions (can differ from data version)
  questionnaire_gui_versions JSONB NOT NULL DEFAULT '{}',
  -- e.g., {"epistaxis_daily": "gui_v3", "quality_of_life": "gui_v2"}

  -- Study parameters
  study_start_date DATE,
  study_end_date DATE,
  enrollment_cap INTEGER,

  -- Compliance settings
  reminder_schedule JSONB,
  compliance_window_hours INTEGER DEFAULT 24,

  PRIMARY KEY (sponsor_id)
);
```

### 3. Mobile App Feature Toggles

```sql
-- Mobile app configuration per sponsor
CREATE TABLE sponsor_mobile_config (
  sponsor_id UUID REFERENCES sponsors(id),

  -- Feature flags
  features_enabled JSONB NOT NULL DEFAULT '{}',
  -- e.g., {"offline_mode": true, "photo_capture": false, "biometric_auth": true}

  features_disabled JSONB NOT NULL DEFAULT '[]',
  -- Explicit disable list (overrides defaults)

  -- App behavior
  min_app_version VARCHAR(20),
  force_update_below VARCHAR(20),
  maintenance_mode BOOLEAN DEFAULT false,

  PRIMARY KEY (sponsor_id)
);
```

### 4. EDC Integration Settings

```sql
-- Portal-to-EDC bridge configuration
CREATE TABLE sponsor_edc_config (
  sponsor_id UUID REFERENCES sponsors(id),

  edc_type VARCHAR(50),  -- 'medidata_rave', 'oracle_inform', 'veeva', etc.
  edc_endpoint TEXT,
  edc_credentials_secret VARCHAR(255),  -- Reference to Doppler/Vault

  -- Field mappings (sponsor-specific)
  field_mappings JSONB NOT NULL DEFAULT '{}',

  -- Sync settings
  sync_frequency_minutes INTEGER DEFAULT 60,
  sync_enabled BOOLEAN DEFAULT true,

  PRIMARY KEY (sponsor_id)
);
```

---

## Deployment Model

### Single Codebase, Runtime Configuration

```yaml
# sponsors.yaml (in monorepo - just lists sponsors, no secrets)
system:
  release_tag: v1.0.2

sponsors:
  - id: callisto
    gcp_project: hht-callisto-prod
    region: eu-west-1

  - id: acme
    gcp_project: hht-acme-prod
    region: us-central1
```

### Deployment Flow

```bash
deploy_all() {
  tag=$(yq ".system.release_tag" sponsors.yaml)
  git checkout "tags/${tag}"

  for sponsor in $(yq ".sponsors[].id" sponsors.yaml); do
    gcp_project=$(yq ".sponsors[] | select(.id == \"$sponsor\") | .gcp_project" sponsors.yaml)

    # Deploy same code to each sponsor's GCP project
    # Configuration comes from portal database, not git
    terraform apply \
      -var="project=${gcp_project}" \
      -var="sponsor_id=${sponsor}"
  done
}
```

### Mobile App Configuration Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  App Start   │ ──► │  Fetch       │ ──► │  Apply       │
│              │     │  Config      │     │  Config      │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     Portal API
                     /api/v1/config
                            │
                            ▼
                     ┌──────────────┐
                     │  Database    │
                     │  (per-sponsor│
                     │   config)    │
                     └──────────────┘
```

---

## Comparison: Portal Config vs Private Repos

| Factor | Portal Config (This Proposal) | Private Sponsor Repos |
| --- | --- | --- |
| **Proprietary data location** | Portal database + GCS | Private git repos |
| **Config change process** | Portal UI (immediate) | Git commit + deploy |
| **Sponsor self-service** | Yes (portal UI) | No (requires dev) |
| **Audit trail** | Database audit log | Git history |
| **Versioning** | Database versioning | Git tags |
| **Rollback** | Database restore | Git revert |
| **Complexity** | Lower (one repo) | Higher (N+1 repos) |
| **Build process** | Simpler (no repo cloning) | Complex (clone overlays) |

---

## Pros of Portal Configuration

### 1. Simpler Repository Structure
- Single public monorepo
- No private repos to manage
- No build-time repo cloning
- Cleaner CI/CD pipelines

### 2. Sponsor Self-Service
- Sponsors can update branding without developer involvement
- Study coordinators can adjust parameters in real-time
- No git knowledge required
- Changes take effect immediately (no redeploy for config)

### 3. Better Separation of Concerns
- Code (git) vs Configuration (database) properly separated
- Developers focus on code, sponsors focus on their study
- Configuration changes don't require code review

### 4. Easier Onboarding
- New sponsor = new database records + GCP project
- No need to create and manage private repos
- Portal provides guided setup wizard

### 5. Runtime Flexibility
- A/B testing of configurations
- Gradual rollout of new questionnaire versions
- Emergency feature toggles without redeploy
- Maintenance mode per sponsor

### 6. Unified Audit Trail
- All config changes in one database
- Consistent audit format across sponsors
- FDA audit: query database, not multiple git repos

---

## Cons of Portal Configuration

### 1. Database as Config Store
- Database schema changes for new config options
- Migration complexity for config structure changes
- Need robust backup/restore for config data

### 2. No Git History for Config
- Config changes not in git history
- Harder to correlate code + config for debugging
- Need separate config versioning system

### 3. Portal Dependency
- Portal must be highly available for config
- Mobile app startup depends on config fetch
- Need offline fallback for cached config

### 4. Security Surface
- Portal UI is attack surface for config tampering
- Need robust RBAC for config changes
- Audit logging is critical

### 5. Testing Complexity
- Can't test config changes in PR
- Need staging environment with test configs
- Config drift between environments possible

### 6. Less Familiar Pattern
- Developers expect config in files
- Debugging requires database access
- Tooling (diff, blame) not available

---

## Hybrid Approach: Best of Both

Consider a hybrid where:

1. **Default configs** live in monorepo (version controlled)
2. **Sponsor overrides** live in portal (runtime configurable)
3. **Branding assets** live in GCS (sponsor-managed)

```dart
class ConfigService {
  Future<StudyConfig> getConfig(String sponsorId) async {
    // 1. Load defaults from bundled assets
    final defaults = await loadBundledDefaults();

    // 2. Fetch sponsor overrides from portal
    final overrides = await fetchSponsorOverrides(sponsorId);

    // 3. Merge (overrides win)
    return defaults.merge(overrides);
  }
}
```

This gives:
- Version-controlled defaults (git)
- Runtime flexibility (portal)
- Sponsor self-service for overrides
- Fallback to defaults if portal unavailable

---

## Implementation Considerations

### Portal Config API

```yaml
# OpenAPI spec excerpt
/api/v1/sponsors/{sponsorId}/config:
  get:
    summary: Get sponsor configuration
    responses:
      200:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/SponsorConfig'

/api/v1/sponsors/{sponsorId}/branding:
  get:
    summary: Get branding configuration
  put:
    summary: Update branding (sponsor admin only)

/api/v1/sponsors/{sponsorId}/study-config:
  get:
    summary: Get study configuration
  patch:
    summary: Update study parameters (sponsor admin only)
```

### Config Caching Strategy

```dart
class CachedConfigService {
  static const cacheDuration = Duration(hours: 1);

  Future<SponsorConfig> getConfig(String sponsorId) async {
    // Check cache first
    final cached = await _cache.get('config_$sponsorId');
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    try {
      // Fetch fresh config
      final config = await _api.fetchConfig(sponsorId);
      await _cache.set('config_$sponsorId', config, cacheDuration);
      return config;
    } catch (e) {
      // Fallback to stale cache if available
      if (cached != null) {
        return cached.data;
      }
      // Ultimate fallback: bundled defaults
      return await loadBundledDefaults();
    }
  }
}
```

### Database Schema for Config Versioning

```sql
-- Config change history for audit
CREATE TABLE sponsor_config_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_id UUID REFERENCES sponsors(id),
  config_type VARCHAR(50),  -- 'study', 'mobile', 'branding', 'edc'
  previous_value JSONB,
  new_value JSONB,
  changed_by UUID REFERENCES users(id),
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  change_reason TEXT
);

-- Trigger to auto-log changes
CREATE TRIGGER log_study_config_changes
  AFTER UPDATE ON sponsor_study_config
  FOR EACH ROW
  EXECUTE FUNCTION log_config_change('study');
```

---

## When to Use This Approach

**Choose Portal Config when:**
- Sponsors need self-service configuration
- Configuration changes frequently
- You want simpler repository management
- Sponsor onboarding should be fast
- You have a robust portal already

**Choose Private Repos when:**
- Configuration is mostly static
- You need git-based audit trail
- Sponsors have technical teams
- Build-time config validation is important
- You prefer infrastructure-as-code patterns

---

## Migration Path

If currently using private repos:

1. **Phase 1**: Add portal config tables, keep private repos
2. **Phase 2**: Migrate branding to GCS, read from portal
3. **Phase 3**: Migrate study config to portal
4. **Phase 4**: Deprecate private repos (keep as backup)

---

## Recommendation

For CureHHT, the **hybrid approach** is recommended:

1. **Monorepo** for all code (public)
2. **Portal database** for sponsor-specific config overrides
3. **GCS buckets** for branding assets (per-sponsor, private)
4. **Bundled defaults** for offline fallback

This provides:
- Simpler repository structure (one repo)
- Sponsor self-service (portal UI)
- Runtime flexibility (no redeploy for config)
- FDA audit compliance (database audit log)
- Offline resilience (cached/bundled defaults)

---

*Document Version: 1.0.0*
*Last Updated: 2026-01-08*

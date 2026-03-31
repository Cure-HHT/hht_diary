# Content & Asset Delivery Architecture

**Version**: 1.0
**Last Updated**: 2026-03-31
**Status**: Active

> This document answers: for every type of content in the system, where does it
> live, how does the app get it, and who controls it? It exists to prevent
> recurring confusion about terminology, ownership, and delivery mechanisms.

---

## Section 1: Glossary

| Term | Definition |
|------|-----------|
| **Diary server** | A per-sponsor Dart backend running on Cloud Run (`apps/daily-diary/diary_server/`). Handles patient enrollment, authentication, data sync, questionnaire submission, and serves sponsor branding/config to the mobile app. Each sponsor has its own diary-server instance in its own GCP project. |
| **Admin server** | The `cure-hht-admin` GCP project. Not a server in the traditional sense — it is a shared GCP project that hosts org-wide resources: Terraform state, Artifact Registry, and the Gmail service account used by all sponsor projects for email delivery. No patient data flows through it. |
| **Portal server** | A per-sponsor Dart backend + Flutter Web UI running on Cloud Run (`apps/sponsor-portal/`). Serves the clinical staff web portal (investigators, auditors, admins). Each sponsor has its own portal-server instance at a unique URL in its own GCP project. Also serves sponsor branding and configuration endpoints for the portal UI. |
| **Portal container** | The Docker image that packages the portal server, its Flutter Web UI, and sponsor-specific content into a single deployable unit. Sponsor content (branding, config) is injected at Docker build time from the sponsor's repository. |
| **Calliope** | Not a component in this system. The term has no definition in the codebase or architecture. If referenced in conversation, it should be defined or dropped. |
| **Global app** | The single mobile application ("Daily Diary" / "CureHHT Tracker") published once to the iOS App Store and once to Google Play (REQ-p00008). It contains configuration mappings for all sponsors but reveals no sponsor identities until enrollment. It is "global" in the sense that all sponsors share the same app binary. |

---

## Section 2: The Master Table

For each content type: where does it live, how does the app/portal get it, and can it change without an app/portal update?

### Mobile App Content

| Content Type | Where It Lives | How App Fetches It | Can Change Without App Update? |
|---|---|---|---|
| **License files** (GNU AGPL, OFL) | Bundled in app at `assets/licenses/` | Local asset read | No — requires app release |
| **Privacy policy** | **UNDECIDED** — see [Section 4](#section-4-the-privacy-policy-decision) | **UNDECIDED** | **UNDECIDED** |
| **Sponsor logo** | Sponsor's diary-server, served from `/app/sponsor-content/{sponsorId}/` in the container | `GET {diaryServerUrl}/{sponsorId}/mobile/assets/images/app_logo.png` (convention-based URL from `assetBaseUrl`) | Yes — update sponsor-content in sponsor repo and redeploy container |
| **Sponsor branding config** (title, feature flags, asset base URL) | Sponsor's diary-server, loaded from `sponsor-config.json` in container | `GET {diaryServerUrl}/api/v1/sponsor/branding/{sponsorId}` | Yes — update `sponsor-config.json` in sponsor repo and redeploy container |
| **Sponsor feature flags** (review screen, animations, fonts, timeouts) | Sponsor's diary-server, loaded from sponsor config / database | `GET {diaryServerUrl}/api/v1/sponsor/config?sponsorId={id}` | Yes — update config and redeploy |
| **App menu content** | Currently hardcoded in Flutter widget tree | Local — compiled into app | No — requires app release |
| **Questionnaire definitions** | Sponsor's diary-server database | Fetched during sync after enrollment | Yes — server-side change |
| **Sponsor backend URL mapping** | Compiled into app binary at `lib/flavors.dart` (static `sponsorBackends` map) | Local constant lookup by 2-letter prefix from enrollment code | No — requires app release. **TODO**: planned migration to central config service on `cure-hht-admin` to allow adding sponsors without app updates |
| **Enrollment code → sponsor mapping** | Compiled into app binary at `lib/config/sponsor_registry.dart` | Local constant lookup | No — requires app release. Same TODO as above |

### Portal Content

| Content Type | Where It Lives | How Portal Gets It | Can Change Without Portal Redeploy? |
|---|---|---|---|
| **License files** | Bundled in portal UI at `assets/licenses/` | Local asset | No — requires container rebuild |
| **Sponsor logo / branding** | Injected at Docker build time from sponsor repo into `/app/sponsor-content/{sponsorId}/` | `GET /api/v1/sponsor/branding` (reads `SPONSOR_ID` env var baked into container) | No — requires container rebuild with updated sponsor content |
| **Sponsor role mappings** | Database (`sponsor_role_mapping` table) | `GET /api/v1/sponsor/roles` | Yes — database change only |
| **Portal identity config** (Firebase auth domain, API key) | Environment variables via Doppler | Read at container startup | Yes — Doppler change + container restart |

---

## Section 3: The Sponsor Isolation Rule

### Does any server hold assets from more than one sponsor?

**No.** Every diary-server and portal-server instance is deployed into a dedicated GCP project per sponsor (REQ-p01054). Each container is built with exactly one sponsor's content baked in (`SPONSOR_ID` env var, `sponsor-content/{sponsorId}/` directory). There is no shared server that holds or serves content for multiple sponsors.

The **only** component that "knows about" multiple sponsors is the **mobile app binary**, which contains a static registry mapping 2-letter prefixes to backend URLs. But it downloads no sponsor content until after enrollment — the base installation reveals no sponsor identities (REQ-p01055-I).

### Is there one diary server per sponsor, or shared?

**One diary-server per sponsor, per environment.** Each sponsor gets:
- Its own GCP project (e.g., `cure-hht-dev`, `callisto4-prod`)
- Its own Cloud Run diary-server deployment
- Its own Cloud Run portal-server deployment
- Its own Cloud SQL database instance
- Its own Identity Platform tenant

There is no shared compute or storage between sponsors (REQ-p01054-F, REQ-p01054-G).

### What is the rule about cross-sponsor data/assets?

Absolute prohibition, enforced at multiple levels:

1. **Infrastructure**: Separate GCP projects with no cross-project networking (REQ-p01054-J)
2. **Database**: Separate Cloud SQL instances per sponsor; additionally, Row-Level Security policies enforce isolation within each database
3. **Application**: The mobile app connects to exactly one sponsor's backend based on enrollment code; no API endpoint exists to query across sponsors
4. **Repository**: Each sponsor has a separate GitHub repository; access is restricted so sponsors cannot see each other's repos or the core platform repo (REQ-p01057-H through M)
5. **Portal**: Each portal instance is scoped to one sponsor; authentication cannot cross sponsor boundaries (REQ-p00009-D, F)
6. **Contractual**: Sponsor participation is confidential — the operator cannot disclose it without written agreement (REQ-p01055-A)

---

## Section 4: The Privacy Policy Decision

> **Status: UNDECIDED — requires resolution**

The following questions need a documented answer:

| Question | Current State |
|----------|--------------|
| **Where does the privacy policy live?** | Markdown documents exist in `docs/` (`privacy-comprehensive-general.md`, `privacy-concise-general.md`, `privacy-diary-addendum.md`) but there is no serving mechanism to deliver them to the mobile app or portal. |
| **Who owns it?** | Multi-layer ownership documented in `privacy-diary-addendum.md`: Anspar Foundation during development phase, Sponsor Organization during operational phase, joint controllership for clinical trial data. |
| **How does it get updated?** | No mechanism exists. The docs are in the mono-repo and would require a code change to update. No API endpoint serves them. |
| **Is it bundled, served, or linked?** | **Not decided.** Options below. |
| **What about sponsor-specific supplements?** | The architecture defines "Sponsor-Specific Supplements" as a layer, but no implementation or delivery mechanism exists. |

### Options to Resolve

| Option | Mechanism | Pros | Cons |
|--------|-----------|------|------|
| **A: Bundle in app** | Ship as local asset (like license files) | Works offline, simple, no server dependency | Cannot update without app release; not suitable for sponsor-specific addenda |
| **B: Serve from diary-server** | `GET /api/v1/privacy-policy` endpoint per sponsor | Can update per-sponsor; caches locally after first fetch | Requires implementation; must handle offline (cache or fallback) |
| **C: Link to external URL** | Open a URL (e.g., `https://anspar.org/privacy`) in system browser | Always current; no app/server changes to update | Requires network; user leaves the app; harder to version per sponsor |
| **D: Hybrid** | Bundle base policy; serve sponsor supplement from diary-server; link to full legal text | Offline base coverage + per-sponsor flexibility | Most complex; multiple delivery mechanisms |

**Recommendation**: This decision should be made and recorded in [Section 5](#section-5-decision-log) before implementation begins.

---

## Section 5: Decision Log

Architectural decisions related to content and asset delivery. For broader architecture decisions, see `docs/adr/`.

| # | Date | Decision | Rationale | Alternatives Rejected |
|---|------|----------|-----------|----------------------|
| D-001 | Pre-2025 | **License files are bundled as local PDF assets** in the app and portal. | Regulated environments require offline access; licenses are stable and rarely change; avoids external CDN dependency. | Serving from server (unnecessary complexity for stable content); linking to URLs (offline requirement). |
| D-002 | Pre-2025 | **Sponsor branding/logos are served from the sponsor's diary-server**, not bundled in the app. | Branding can change without app release; different sponsors have different branding; confidentiality requires branding download only after enrollment (REQ-p01055-J). | Bundling in app (violates confidentiality — all sponsor logos would ship in every app binary; also requires app release to update). |
| D-003 | Pre-2025 | **Sponsor content is injected at container build time** from sponsor repositories, not fetched at runtime from a CDN or object store. | Simplicity; content is versioned alongside container; no additional infrastructure needed; content changes are tracked in git. | Runtime fetch from GCS bucket (adds infrastructure and failure modes); CDN (unnecessary for current scale). |
| D-004 | Pre-2025 | **One GCP project per sponsor** with fully isolated infrastructure. | FDA compliance requires complete data isolation; eliminates any possibility of cross-sponsor data leakage; simplifies compliance auditing. | Shared infrastructure with logical isolation (RLS-only) — rejected because pharma sponsors require infrastructure-level guarantees, not just application-level isolation. |
| D-005 | Pre-2025 | **Single mobile app binary for all sponsors** with enrollment-based sponsor detection. | One app listing simplifies distribution; enrollment codes handle routing; base app reveals no sponsor identities. | Per-sponsor app builds (operational nightmare at scale; exposes sponsor identity in app store listings). |
| D-006 | Pre-2025 | **Sponsor backend URLs are currently compiled into the app binary** (`flavors.dart`, `sponsor_registry.dart`). | Simplest approach for initial single-sponsor deployment. | Central config service (planned — see TODO in `sponsor_registry.dart` and `flavors.dart`). This is the intended future direction to allow adding sponsors without app updates. |
| D-007 | — | **Privacy policy delivery mechanism: UNDECIDED.** | See [Section 4](#section-4-the-privacy-policy-decision). | — |
| D-008 | — | **App menu content delivery: UNDECIDED.** | Currently hardcoded in Flutter widgets. No decision has been made on whether menu content (e.g., help links, about screens) should be server-driven or remain compiled. | — |

---

## References

- `spec/prd-architecture-multi-sponsor.md` — Multi-sponsor architecture requirements
- `spec/dev-app.md` — Mobile app specification (REQ-d00005: sponsor detection)
- `spec/prd-privacy-policy.md` — Privacy policy requirements
- `spec/dev-sponsor-repos.md` — Sponsor repository structure
- `infrastructure/terraform/admin-project/README.md` — Admin project (cure-hht-admin)
- `apps/common-dart/shared_functions/lib/src/sponsor_branding.dart` — Server-side branding loader
- `apps/daily-diary/clinical_diary/lib/services/sponsor_branding_service.dart` — Client-side branding service
- `apps/daily-diary/clinical_diary/lib/config/sponsor_registry.dart` — Enrollment code → sponsor mapping
- `apps/daily-diary/clinical_diary/lib/flavors.dart` — Per-environment backend URLs
- `docs/adr/` — Architecture Decision Records (broader system decisions)

---

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-03-31 | Initial document — created to resolve recurring confusion about content delivery, terminology, and undocumented decisions | Development Team |

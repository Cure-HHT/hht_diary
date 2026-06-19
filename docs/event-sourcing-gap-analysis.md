# Event-Sourcing Library Gap Analysis

This document tracks event-sourcing obligations that were present in the legacy `hht_diary/spec/prd-event-sourcing-system.md` (now archived under `spec-archive/`) but are not yet expressed in the canonical EVS library specs (`event_sourcing/spec/prd-*.md`).

The legacy file held 23 REQs. During the URS-v1 migration on 2026-05-15 we triaged them as:

- **13 fully covered** — already expressed in EVS; dropped from hht_diary. Code annotations targeting these will be rewritten to cite the EVS counterpart during code-annotation sweep (deferred to post-URS Phase 3).
- **5 partial / library-level gaps** — listed below. Track as upstream EVS issues; hht_diary does not retain its own copies during the transition.
- **3 diary-domain** — moved to `spec/prd-questionnaire-versioning.md` as `DIARY-PRD-questionnaire-{versioning,localization,sponsor-eligibility}`. Not event-sourcing concerns.
- **2 architecture-conflict / URS-bound** — deferred to URS-Phase-3 (see below).
- **1 obsolete** — dropped entirely.

## Upstream EVS gaps to file as issues

Each item below should become an issue in `Cure-HHT/event_sourcing` (or a draft EVS-PRD-* REQ in that repo's `spec/`).

### Schema versioning (was REQ-p01004)

EVS does not mandate per-event schema version identifiers or compatibility checks during materialization. The diary version required both. Library-level assertion missing:

> Every event SHALL include its schema version identifier; the library SHALL verify schema compatibility before deserializing and applying events during materialization.

Candidate home: `event_sourcing/spec/prd-event-log.md`.

### Atomic multi-action / batch operations (was REQ-p01012)

EVS-PRD-action-dispatch covers single-action idempotency but not multi-action atomicity. Missing assertion:

> The dispatch flow SHALL support submitting multiple related actions atomically, such that all succeed or all fail; resulting events SHALL carry matching causation or correlation identifiers.

Candidate home: `event_sourcing/spec/prd-action-dispatch.md`.

### Event type registry with runtime validation (was REQ-p01050)

EVS leaves event-type governance to the consuming application. The diary required a registry with runtime validation, deprecation tracking, and sunset dates. Library-level assertions missing:

> The library SHALL provide a registry of valid event types and versions; the dispatch flow SHALL reject actions that produce unregistered event types. The registry SHALL track deprecation and sunset metadata per type version.

Candidate home: `event_sourcing/spec/prd-action-dispatch.md`. NOTE: the diary's REQ-p01050 mixed in sponsor-eligibility metadata (assertion F, P) which is clinical-domain leakage; the EVS version should drop those.

### Observability hooks (was REQ-p01014)

EVS surfaces regulatory-level failures but does not specify metrics, throughput, or distributed tracing. Missing:

> The library SHALL expose OpenTelemetry-compatible hooks for metrics (event throughput, latency, queue depth) and SHALL propagate distributed tracing context across action dispatch boundaries.

Candidate home: new `event_sourcing/spec/prd-observability.md`.

### Error taxonomy (was REQ-p01007)

EVS-PRD-regulatory-alignment covers integrity violations but not the full error classification consumers need. Missing:

> The library SHALL classify failures into distinct categories (parse, validation, authorization, execution, conflict, storage) with distinct signaling so consumers can distinguish operational failure modes.

Candidate home: `event_sourcing/spec/prd-regulatory-alignment.md`.

## Deferred to URS-Phase-3

Two diary REQs were carve-out candidates per the migration plan but conflict with current architectural memory or are squarely URS-addressed; deferring rather than authoring transitional files:

### REQ-p01009: Encryption at Rest for Offline Queue

Mobile-platform security obligation (AES-256, iOS Keychain / Android Keystore integration, key rotation). URS §6.1 (Mobile Application Foundation) — specifically §6.1.4 Privacy Policy and §6.1.6 Application Lock — will define the mobile security envelope. Reconcile during URS-Phase-3 mobile migration; if any p01009 assertion is not covered, capture it as a new `DIARY-PRD-mobile-*` REQ at that time.

### REQ-p01010: Multi-tenancy Support

Library-level multi-tenancy assertions (isolated databases per tenant, tenant switching without restart, per-tenant offline queues, etc.) conflict with the current single-tenant-per-sponsor backend architecture (per-sponsor isolated VPC; no sponsor_id plumbing in data layers). The mobile app does not multi-tenant; sponsor selection happens at install/registration time. Most of p01010's assertions are obsolete relative to current architecture. URS migration will produce a clean multi-sponsor architecture REQ; the legacy assertions should be retired then, not migrated.

## Retired

### REQ-p01019: Phased Implementation

Implementation phasing markers (Phase 1/2/3 deliverables) are not normative product requirements; they belong in a development plan, not a PRD. Dropped without replacement.

## See also

- `spec-archive/prd-event-sourcing-system.md` — the legacy source (read-only reference).
- `event_sourcing/spec/prd-*.md` — current EVS library specs (canonical).
- `spec/prd-questionnaire-versioning.md` — where the 3 diary-domain REQs landed.

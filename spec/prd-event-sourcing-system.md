# Event Sourcing System

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-27
**Status**: Draft

> **See**: dev-event-sourcing-postgres.md for implementation details (to be created)
> **See**: ops-event-sourcing-deployment.md for deployment and operations (to be created)
> **See**: prd-database.md for diary-specific implementation
> **See**: prd-clinical-trials.md for compliance requirements

---

## Executive Summary

The Event Sourcing System is a reusable software module that provides a client-side interface to an event-sourced database. It enables client applications to interact with event streams and materialized views while maintaining compliance with FDA 21 CFR Part 11 requirements for electronic records and audit trails.

**Key Benefits**:
- Offline-first architecture with automatic event synchronization
- Type-safe event modeling and serialization
- Automatic conflict resolution for distributed edits
- Built-in audit trail support for compliance
- Pluggable architecture for use across multiple projects
- Schema version-aware migrations

**Target Use Cases**:
- Data collection applications with offline requirements
- Multi-user applications requiring audit trails
- Regulated industries requiring immutable audit trails
- Any system needing complete change history

---

## Architecture Overview

### High-Level Design

The module follows a CQRS (Command Query Responsibility Segregation) pattern where:

**Command Side (Writes)**:
- Application generates domain events locally
- Events queued on device until network available
- Events sent to server and appended to event log
- Server validates and persists events to immutable event table
- Acknowledgment returned to client

**Query Side (Reads)**:
- Client queries materialized views for current state
- Views automatically updated by database triggers
- Real-time subscriptions notify clients of remote changes
- Optimistic UI updates with server reconciliation

### Component Architecture

```
┌─────────────────────────────────────────────────────┐
│          Flutter Application Layer                  │
│  (Business Logic, UI, ViewModels)                  │
└─────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│      Flutter Event Sourcing Module                  │
│                                                     │
│  ┌────────────────┐  ┌───────────────────────┐    │
│  │ Event Store    │  │ Materialized View     │    │
│  │ Repository     │  │ Query Service         │    │
│  └────────────────┘  └───────────────────────┘    │
│                                                     │
│  ┌────────────────┐  ┌───────────────────────┐    │
│  │ Offline Queue  │  │ Conflict Resolution   │    │
│  │ Manager        │  │ Engine                │    │
│  └────────────────┘  └───────────────────────┘    │
│                                                     │
│  ┌────────────────┐  ┌───────────────────────┐    │
│  │ Schema         │  │ Real-time             │    │
│  │ Migration      │  │ Subscription          │    │
│  └────────────────┘  └───────────────────────┘    │
└─────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│         PostgreSQL Database                         │
│                                                     │
│  ┌────────────────┐  ┌───────────────────────┐    │
│  │ events         │  │ materialized_views    │    │
│  │ (append-only)  │  │ (current state)       │    │
│  └────────────────┘  └───────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

### Data Flow

**Event Creation Flow**:
1. User action triggers domain event in app
2. Event serialized and stored in local queue
3. Event repository attempts sync with server
4. Server validates event against business rules
5. Event appended to immutable events table
6. Database trigger updates materialized view
7. Client receives acknowledgment
8. Local optimistic state confirmed or rolled back

**Query Flow**:
1. UI requests current state via query service
2. Service checks local cache first
3. If stale, queries materialized view
4. Results deserialized to domain models
5. Optional real-time subscription established
6. Updates pushed to client automatically

---

## Essential Requirements

---

# REQ-p01000: Event Sourcing Client Interface

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

This requirement establishes a type-safe client interface for event sourcing operations in a PostgreSQL database. Event sourcing is critical for FDA 21 CFR Part 11 compliance as it provides immutable audit trails and complete historical reconstruction. The interface abstracts database complexity while ensuring type safety reduces runtime errors during clinical trial data collection. Schema versioning enables system evolution without compromising historical data integrity.

## Assertions

A. The module SHALL provide a type-safe client interface for creating events in an event-sourced PostgreSQL database.
B. The module SHALL provide a type-safe client interface for storing events in an event-sourced PostgreSQL database.
C. The module SHALL provide a type-safe client interface for querying events in an event-sourced PostgreSQL database.
D. The interface SHALL support append-only event creation with automatic timestamping.
E. The interface SHALL support event serialization to PostgreSQL-compatible JSON format.
F. The interface SHALL support querying materialized views for current state.
G. The interface SHALL support event stream replay for historical state reconstruction.
H. The interface SHALL support schema version tracking for forward compatibility.
I. The interface SHALL support schema version tracking for backward compatibility.
J. Events SHALL be defined as strongly-typed data structures.
K. The module SHALL provide automatic JSON serialization for events.
L. The module SHALL provide automatic JSON deserialization for events.
M. The module SHALL provide compile-time verification of event structure.
N. The module SHALL provide runtime validation of event data against schema.
O. The interface SHALL support custom event types via extension.

*End* *Event Sourcing Client Interface* | **Hash**: 750e5c35
---

---

# REQ-p01001: Offline Event Queue with Automatic Synchronization

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Client applications in clinical trials frequently operate in environments with intermittent connectivity, such as patient homes or remote clinical sites. Offline queuing ensures that no clinical data is lost during network outages and that FDA 21 CFR Part 11 compliant audit trails remain complete and tamper-evident. This requirement addresses the need for reliable data capture in adverse network conditions while maintaining data integrity and providing transparency to users about synchronization status.

## Assertions

A. The module SHALL queue events locally when network is unavailable.
B. The module SHALL automatically synchronize queued events to the server when connectivity is restored.
C. The module SHALL store queued events in local persistent storage.
D. The module SHALL deliver queued events to the server in FIFO (first-in-first-out) order.
E. The module SHALL implement retry logic with exponential backoff for failed synchronization attempts.
F. The module SHALL prevent duplicate event submission using idempotency keys.
G. The module SHALL preserve the event queue across application restarts.
H. The module SHALL provide user visibility into synchronization status.
I. The module SHALL save events to local storage immediately upon creation.
J. The module SHALL initiate automatic synchronization when network becomes available and the application is active.
K. The module SHALL provide a manual sync trigger for user-initiated synchronization.
L. The module SHALL display a sync status indicator showing pending, syncing, or complete states.
M. The module SHALL log failed synchronization events with detailed error messages.
N. The module SHALL NOT lose data even if the application is force-closed.

*End* *Offline Event Queue with Automatic Synchronization* | **Hash**: 35094804
---

---

# REQ-p01002: Optimistic Concurrency Control

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

In distributed systems with offline support, multiple users may edit the same data concurrently. Optimistic concurrency control ensures data integrity while maintaining the complete audit trail required for FDA 21 CFR Part 11 compliance. This approach allows local editing with conflict detection at synchronization time, rather than preventing concurrent access through locking mechanisms.

## Assertions

A. The system SHALL implement optimistic concurrency control to handle conflicting events from multiple clients editing the same data simultaneously.
B. The system SHALL use version vectors or sequence numbers for event ordering.
C. The system SHALL automatically detect conflicting events before server persistence.
D. The system SHALL support pluggable conflict resolution strategies including last-write-wins, merge, and custom strategies.
E. The system SHALL provide a default conflict resolution strategy.
F. The system SHALL allow custom conflict resolution strategies to be registered.
G. The system SHALL notify users when manual conflict resolution is required.
H. The system SHALL preserve all conflicting events in the audit trail.
I. The audit trail SHALL record all conflict resolution actions.
J. The event log SHALL retain all conflicting events without deletion or modification.

*End* *Optimistic Concurrency Control* | **Hash**: 994871a2
---

---

# REQ-p01003: Immutable Event Storage with Audit Trail

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

FDA 21 CFR Part 11 requires secure, computer-generated, time-stamped audit trails to ensure the integrity and reliability of electronic records in clinical trials. Immutable event storage provides tamper-proof audit trails by design, making it impossible to alter historical records without detection. This append-only architecture ensures regulatory compliance while enabling full reconstruction of system state at any point in time through event replay. The cryptographic integrity mechanisms provide mathematically verifiable proof that audit records have not been tampered with, which is critical for regulatory inspections and data integrity audits.

## Assertions

A. The system SHALL store all events as immutable, append-only records.
B. The system SHALL NOT allow modification of events after creation.
C. The system SHALL NOT allow deletion of events after creation.
D. The system SHALL enforce event immutability through database constraints.
E. Each event record SHALL include a timestamp.
F. Each event record SHALL include a user ID.
G. Each event record SHALL include an event type.
H. Each event record SHALL include a data payload.
I. Each event record SHALL include a causation ID.
J. The system SHALL cryptographically sign or hash each event for tamper detection.
K. The system SHALL guarantee event sequence ordering via database sequence numbers or equivalent constraints.
L. The system SHALL derive current state by replaying events through materialized views.
M. Materialized views SHALL always remain consistent with the event log.

*End* *Immutable Event Storage with Audit Trail* | **Hash**: 29a2c2ac
---

---

# REQ-p01004: Schema Version Management

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Long-lived clinical trial applications require schema evolution over multiple years of deployment. Version management ensures clients and servers remain compatible during phased rollouts, prevents data corruption from version mismatches, and supports safe rollbacks when migrations fail. This is critical for FDA 21 CFR Part 11 compliance where system validation must account for schema changes across the validated system lifecycle.

## Assertions

A. The system SHALL maintain a current database schema version identifier accessible to server applications.
B. The system SHALL expose the server application version to client applications via API.
C. Server applications SHALL verify database schema compatibility on startup before accepting requests.
D. Client applications SHALL verify server compatibility on startup before performing operations.
E. The system SHALL automatically apply data migration scripts when schema changes are compatible with the current version.
F. The system SHALL display clear error messages specifying version requirements when schema versions are incompatible.
G. The system SHALL provide rollback capability to restore the previous schema state when migrations fail.
H. Client applications SHALL query the server for the current schema version during startup.
I. The system SHALL tag all stored events with the schema version active at the time of event creation.
J. Client applications SHALL reject data operations when the server schema version is incompatible with the client version.
K. The system SHALL display clear upgrade instructions to users when version incompatibility is detected.

*End* *Schema Version Management* | **Hash**: 102eb5a1
---

---

# REQ-p01005: Real-time Event Subscription

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Real-time event subscriptions enhance user experience by providing immediate feedback on data changes and enable collaborative features where multiple users interact with shared clinical trial data. In FDA-regulated clinical trials, timely visibility of data changes is critical for research coordinators and clinical staff to respond to patient-reported events. The requirement addresses network reliability concerns in healthcare settings by ensuring continuity of event delivery despite transient connectivity issues.

## Assertions

A. The system SHALL support real-time subscriptions to event streams for notifying clients when new events occur.
B. The system SHALL provide WebSocket or Server-Sent Events transport mechanisms for push notifications.
C. The system SHALL support subscription filtering by event type.
D. The system SHALL support subscription filtering by aggregate identifier.
E. The system SHALL support subscription filtering by user identifier.
F. The system SHALL automatically reconnect subscriptions with exponential backoff on connection loss.
G. The system SHALL recover and deliver missed events when a subscription reconnects after disconnection.
H. The system SHALL clean up resources when subscriptions are disposed.
I. The system SHALL establish subscriptions with client-specified event filters.
J. The system SHALL notify subscribed clients immediately when events matching their filters occur.
K. The system SHALL NOT lose events during brief network interruptions when automatic reconnection succeeds.
L. The system SHALL prevent memory leaks by ensuring proper disposal of subscription resources.

*End* *Real-time Event Subscription* | **Hash**: 58430215
---

---

# REQ-p01006: Type-Safe Materialized View Queries

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Querying event-sourced systems by replaying entire event streams for every read operation creates unacceptable performance bottlenecks. Materialized views provide pre-computed, optimized read models that represent the current state derived from the immutable event log. This requirement ensures type-safe access to these views while maintaining performance through caching and efficient querying. The strongly-typed interfaces prevent runtime errors and enable compile-time validation of query logic, which is critical for FDA-validated systems where production failures have regulatory consequences.

## Assertions

A. The module SHALL provide type-safe query interfaces for all materialized views that represent current state derived from events.
B. View models SHALL be defined as strongly-typed data structures.
C. View models SHALL support automatic JSON code generation for serialization and deserialization.
D. The system SHALL automatically deserialize PostgreSQL JSONB columns into strongly-typed view models.
E. Query interfaces SHALL provide compile-time type checking for all query operations.
F. Query interfaces SHALL support filtering operations through WHERE clause construction.
G. Query interfaces SHALL support sorting operations on view data.
H. Query interfaces SHALL support pagination for result sets.
I. Query interfaces SHALL support efficient incremental queries that fetch only changes since the last query.
J. The module SHALL provide cache management for materialized view queries.
K. The cache management system SHALL support configurable time-to-live (TTL) values for cached data.
L. The cache management system SHALL support automatic invalidation of cached data when underlying views are updated.
M. Query interfaces SHALL support complex WHERE clauses with multiple conditions.
N. Query interfaces SHALL support ordering of results by specified fields.

*End* *Type-Safe Materialized View Queries* | **Hash**: 13f605de
---

---

# REQ-p01007: Error Handling and Diagnostics

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Comprehensive error handling and diagnostics are essential for maintaining system reliability and reducing mean time to resolution (MTTR) in production environments. Proper error classification, contextual logging, and integration with monitoring services enable developers to quickly identify root causes during development and operations teams to respond effectively to production incidents. This requirement supports FDA 21 CFR Part 11 compliance by ensuring that system failures are documented with complete audit context.

## Assertions

A. The module SHALL provide structured exception types for network failures.
B. The module SHALL provide structured exception types for validation failures.
C. The module SHALL provide structured exception types for conflict failures.
D. The module SHALL provide structured exception types for schema errors.
E. The module SHALL include actionable troubleshooting steps in all error messages.
F. The module SHALL log all errors with complete context including event data, user identity, and timestamp.
G. The module SHALL integrate with at least one crash reporting service (Firebase Crashlytics, Sentry, or equivalent).
H. The module SHALL provide a debug mode that logs all events in the event stream.
I. The module SHALL provide a debug mode that logs all state transitions.

*End* *Error Handling and Diagnostics* | **Hash**: baaaa244
---

## Optional/Advanced Requirements

---

# REQ-p01008: Event Replay and Time Travel Debugging

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Time travel debugging capabilities enable developers to reconstruct application state at any point in time for investigating bugs and understanding how data evolved. This is essential for regulatory audits requiring historical data reconstruction, allowing auditors to trace how clinical trial data reached its current state. The capability supports both development debugging and compliance investigations by providing mechanisms to replay events, compare states across time, and export event streams for detailed analysis.

## Assertions

A. The system SHALL provide an API to replay events up to a specific timestamp.
B. The system SHALL provide an API to replay events up to a specific sequence number.
C. The system SHALL support fast-forward navigation through event history.
D. The system SHALL support rewind navigation through event history.
E. The system SHALL create state snapshots at configurable intervals to optimize replay performance.
F. The system SHALL support comparison of application state between two points in time.
G. The system SHALL provide functionality to export event streams to JSON format.
H. The system SHALL provide functionality to export event streams to CSV format.
I. The system SHALL implement efficient replay using snapshots combined with incremental events.

*End* *Event Replay and Time Travel Debugging* | **Hash**: 5762fc28
---

---

# REQ-p01009: Encryption at Rest for Offline Queue

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Healthcare and clinical trial data often includes Protected Health Information (PHI) and Personally Identifiable Information (PII). Encrypting the offline queue provides defense-in-depth protection for sensitive data when devices are lost, stolen, or otherwise compromised. This requirement supports FDA 21 CFR Part 11 compliance by ensuring data integrity and confidentiality at rest. The encryption strategy balances security requirements with performance considerations to maintain usable application responsiveness.

## Assertions

A. The system SHALL encrypt all events stored in the offline queue before writing to on-device storage.
B. The system SHALL use AES-256 encryption for all event payload data in the offline queue.
C. The system SHALL integrate with platform-native secure storage mechanisms (iOS Keychain or Android Keystore) for key management.
D. The system SHALL NOT store encryption keys in plain text anywhere on the device.
E. The system SHALL store all encryption keys exclusively in platform secure storage.
F. The system SHALL support optional user-specific encryption keys for the offline queue.
G. The system SHALL complete encryption operations with less than 50 milliseconds of overhead per event.
H. The system SHALL support automatic rotation of encryption keys without data loss.

*End* *Encryption at Rest for Offline Queue* | **Hash**: 740eb955
---

---

# REQ-p01010: Multi-tenancy Support

**Level**: PRD | **Status**: Draft | **Implements**: p00043

## Rationale

This requirement enables the clinical trial platform to serve multiple sponsors or organizations from a single codebase deployment while maintaining complete data isolation between tenants. In the context of FDA-regulated clinical trials, strict tenant isolation is critical to prevent cross-contamination of trial data between different sponsors. Multi-tenancy reduces operational overhead by allowing a single application instance to manage multiple isolated sponsor databases, each with independent schema versions and offline synchronization queues. This architecture supports the platform's multi-sponsor deployment model while ensuring regulatory compliance and data integrity.

## Assertions

A. The system SHALL support connection to multiple isolated databases from a single client instance.
B. The system SHALL provide tenant-specific connection configuration for each database.
C. The system SHALL ensure complete isolation of events between tenants with no cross-tenant data access.
D. The system SHALL ensure complete isolation of queries between tenants with no cross-tenant data access.
E. The system SHALL support tenant switching without requiring application restart.
F. The system SHALL maintain separate offline queues for each tenant.
G. The system SHALL support tenant-specific schema versions independently managed per tenant.
H. The system SHALL propagate tenant context through all database operations.
I. The system SHALL NOT allow data leakage between tenants under any circumstances.
J. The configuration system SHALL support definitions for multiple tenants.
K. The offline synchronization system SHALL maintain queue isolation per tenant with no cross-tenant queue access.

*End* *Multi-tenancy Support* | **Hash**: 4284f635
---

---

# REQ-p01050: Event Type Registry

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Without an explicit type registry, the relationship between versioned schemas (e.g., survey-v1.0 and survey-v1.2) is implicit and derived by string parsing. This creates risks: typos silently create new types, no standard way to discover available types, and no formal tracking of version lifecycles. A registry provides a single source of truth that enables validation, discovery, and governance of the event type portfolio, supporting proper schema evolution and multi-tenant customization.

## Assertions

A. The system SHALL maintain a registry of event types that provides a single source of truth for available event schemas, their versions, and relationships.
B. The registry SHALL provide a catalog of base event types (e.g., survey, epistaxis) independent of version.
C. The registry SHALL explicitly group versioned schemas under their base type.
D. The registry SHALL store display name metadata for each event type.
E. The registry SHALL store description metadata for each event type.
F. The registry SHALL store sponsor eligibility metadata for each event type.
G. The registry SHALL track deprecation status for each event type version.
H. The registry SHALL track sunset dates for obsolete event type versions.
I. The registry SHALL enable runtime discoverability of available event types and versions.
J. Base event types SHALL be explicitly defined with unique identifiers.
K. Each versioned schema SHALL be linked to its base event type.
L. Type metadata SHALL include name, description, and status fields.
M. Type status values SHALL include active, deprecated, and sunset.
N. The system SHALL provide an API to enumerate available event types and their versions at runtime.
O. The system SHALL reject events with unregistered versioned_type values during validation.
P. The system SHALL support sponsor-specific type enablement configurable per tenant.

*End* *Event Type Registry* | **Hash**: e816a02e

---

---

# REQ-p01051: Questionnaire Versioning Model

**Level**: PRD | **Status**: Draft | **Implements**: p01050

## Rationale

Clinical questionnaires evolve across multiple independent dimensions. Structural changes add or remove data fields requiring database schema updates. Content changes refine question wording to improve clarity or address translation issues without altering the underlying data structure. Presentation changes enhance user experience through visual redesign without modifying what questions are asked. Conflating these three evolution paths into a single version number creates unnecessary coupling: wording improvements would trigger schema migrations, UI redesigns would invalidate validated instrument versions, and the audit trail would obscure which dimension actually changed. By tracking schema, content, and GUI versions independently, clinical teams can refine instrument language without engineering involvement, UX teams can improve presentation without affecting clinical validation, and regulatory audits can reconstruct the exact patient experience across all three dimensions.

## Assertions

A. The platform SHALL support independent versioning of questionnaire schema, content, and presentation.
B. The system SHALL distinguish between schema version, content version, and GUI version as separate versioning dimensions.
C. Schema version SHALL identify the data structure and field types stored in the database.
D. Schema version SHALL change when fields are added, removed, or restructured.
E. Schema version SHALL determine validation rules and migration requirements.
F. Content version SHALL identify the source language question text, option labels, help text, and scoring rules.
G. Content version SHALL change when wording is clarified or questions are refined, independent of schema changes.
H. GUI version SHALL identify the presentation and rendering of the questionnaire in client applications.
I. GUI version SHALL change when user interface is redesigned or user experience is improved, independent of content or schema.
J. Each questionnaire response SHALL record the schema version identifier.
K. Each questionnaire response SHALL record the content version identifier.
L. Each questionnaire response SHALL record the GUI version identifier.
M. The system SHALL enable complete reconstruction of what the patient saw using the recorded version identifiers.
N. The system SHALL enable complete reconstruction of how the data was captured using the recorded version identifiers.
O. The system SHALL track schema version via the versioned_type field.
P. The system SHALL record content version in event_data for each response.
Q. The system SHALL record GUI version in event_data for each response.
R. Wording changes SHALL create a new content version without requiring schema migration.
S. UI redesigns SHALL create a new GUI version without requiring content version changes.
T. UI redesigns SHALL create a new GUI version without requiring schema version changes.
U. The system SHALL enable retrieval of historical responses with exact version context for all three version dimensions.
V. Version relationships SHALL be documented in the questionnaire registry.
W. The platform SHALL maintain complete audit traceability across all three versioning dimensions.

*End* *Questionnaire Versioning Model* | **Hash**: fbf500ff

---

---

# REQ-p01052: Questionnaire Localization and Translation Tracking

**Level**: PRD | **Status**: Draft | **Implements**: p01051

## Rationale

International clinical trials require validated translations of instruments, where each translation has its own validation status and version lifecycle independent of the source content. For ALCOA+ compliance, the audit trail must show exactly what question text the patient saw in their language. For analysis purposes, responses must be normalized to a common language. Storing both the original patient response and canonical normalized response preserves the complete audit trail while enabling consistent cross-site analysis.

## Assertions

A. The platform SHALL support localized questionnaires with independent translation versioning.
B. The system SHALL store the language identifier showing the specific language and locale presented to the patient (e.g., es-MX for Spanish-Mexico).
C. The system SHALL store the translation version for each language, independent of the source content version.
D. The system SHALL store the source content reference indicating which source language content version each translation is based upon.
E. The system SHALL capture the original response as the exact value the patient entered or selected in their language.
F. The system SHALL capture the canonical response as the normalized value used for study analysis.
G. The system SHALL store the translation method for free-text translations, indicating whether the canonical value was auto-translated, manually translated, or verified by a human translator.
H. The system SHALL record patient language preference at enrollment.
I. The system SHALL present questionnaires in the patient's configured language.
J. The system SHALL track translation version per language per questionnaire.
K. The system SHALL enable reconstruction of the audit trail showing the exact localized content shown to each patient.
L. The system SHALL support management of translation versions independently of source content versions.

*End* *Questionnaire Localization and Translation Tracking* | **Hash**: 74dee412

---

---

# REQ-p01053: Sponsor Questionnaire Eligibility Configuration

**Level**: PRD | **Status**: Draft | **Implements**: p01050, p01051

## Rationale

Multi-sponsor deployments require sponsor-specific questionnaire portfolios to accommodate varying study designs. One sponsor may use only epistaxis tracking while another includes quality-of-life assessments. Version constraints enable patients in ongoing studies to continue using validated instrument versions while new enrollments can use updated versions, ensuring data consistency within study cohorts. Language enablement ensures only properly validated translations are offered to participants. This configuration-driven approach allows questionnaire changes to be managed deliberately, preventing unintended mid-study modifications that could impact response patterns and data quality. The platform enforces these constraints at data capture time to maintain study protocol compliance and data integrity across the multi-sponsor environment.

## Assertions

A. The system SHALL allow each sponsor to configure which questionnaire types are enabled for their clinical trial.
B. The system SHALL allow each sponsor to configure which questionnaire versions are enabled for their clinical trial.
C. The system SHALL allow each sponsor to configure which questionnaire languages are enabled for their clinical trial.
D. Sponsor questionnaire configuration SHALL specify the current version for new entries.
E. Sponsor questionnaire configuration SHALL specify the minimum accepted version for historical data.
F. Sponsor questionnaire configuration SHALL designate the source language for each enabled questionnaire.
G. The system SHALL present only sponsor-enabled questionnaires in client applications.
H. The system SHALL use the configured current version when capturing new questionnaire data.
I. The system SHALL accept historical questionnaire data from any version between the minimum version and the current version inclusive.
J. The system SHALL restrict language options to sponsor-enabled translations during data capture.
K. The system SHALL validate questionnaire responses against the rules defined in the appropriate questionnaire version.
L. The system SHALL enforce sponsor eligibility constraints during all data capture operations.
M. Configuration changes SHALL NOT invalidate existing historical questionnaire data.
N. The system SHALL support addition of new questionnaire types without requiring platform code changes.

*End* *Sponsor Questionnaire Eligibility Configuration* | **Hash**: d347bcdb

---

---

# REQ-p01011: Event Transformation and Migration

**Level**: PRD | **Status**: Draft | **Implements**: p01050

## Rationale

As clinical trial applications evolve over time, event structures and business logic change to accommodate new features, regulatory requirements, and data models. Event transformation (also called upcasting) enables the system to interpret historical events using current business logic without requiring backfills or data migrations. This maintains the integrity of the immutable event store while ensuring that all event consumers can work with a consistent, current event schema. This capability is essential for FDA 21 CFR Part 11 compliance, as it preserves the complete audit trail while adapting to evolving regulatory and clinical requirements.

## Assertions

A. The system SHALL support event transformation/upcasting to automatically convert old event formats to new formats.
B. The system SHALL support versioned event schemas with migration functions.
C. The system SHALL automatically upcast old events during replay operations.
D. The system SHALL maintain backward compatibility for all event consumers.
E. The system SHALL provide testing utilities for migration verification.
F. Event records SHALL include a schema version number.
G. The system SHALL maintain a registry of migration functions per event type.
H. The system SHALL automatically transform old events on read operations.
I. Migration test framework SHALL validate that transformations do not lose data.

*End* *Event Transformation and Migration* | **Hash**: adff05f2
---

---

# REQ-p01012: Batch Event Operations

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Some business operations naturally generate multiple events that should be atomic. For example, a transfer operation consists of both a withdrawal and a deposit that must either both succeed or both fail to maintain data consistency. Batch operations reduce network overhead by transmitting multiple events in a single request while preserving causal relationships between events.

## Assertions

A. The system SHALL provide an API to create batch event operations.
B. The system SHALL persist all events in a batch as a single atomic transaction.
C. Batch operations SHALL ensure that all events in the batch succeed or all events fail.
D. The system SHALL maintain causal ordering of events within a batch.
E. The system SHALL transmit batch events in a single network request.
F. The system SHALL serialize batch events efficiently.
G. The system SHALL rollback optimistic updates if the batch operation fails.
H. The system SHALL provide error handling for partial batch failures.

*End* *Batch Event Operations* | **Hash**: 0070c072
---

## DevOps and Production Requirements

---

# REQ-p01014: Observability and Monitoring

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Production systems require visibility into module behavior for debugging, capacity planning, and incident response. This requirement ensures comprehensive observability for event-driven modules in FDA-regulated clinical trial environments, enabling operators to detect issues, diagnose root causes, and maintain system reliability without compromising audit trail integrity.

## Assertions

A. The module SHALL provide observability hooks for monitoring module health, performance, and errors in production.
B. The system SHALL collect metrics for event throughput, queue depth, sync latency, and error rates.
C. The system SHALL integrate with distributed tracing systems to trace event flows across module boundaries.
D. The module SHALL provide a health check API that reports module status.
E. The health check API SHALL report queue status, connectivity status, and schema version.
F. The system SHALL provide performance profiling hooks to identify bottlenecks.
G. The system SHALL support configurable logging levels ranging from SILENT to VERBOSE.
H. The system SHALL export metrics via standard interfaces compliant with OpenTelemetry.
I. The distributed tracing system SHALL propagate context through event flows.

*End* *Observability and Monitoring* | **Hash**: 9df008fb
---

---

# REQ-p01015: Automated Testing Support

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Testable code is maintainable code in FDA-regulated systems where validation is critical. Providing comprehensive test utilities encourages proper testing practices, reduces integration friction, and enables validation of event sourcing behaviors. This supports FDA 21 CFR Part 11 validation requirements by making system behavior verifiable through automated testing.

## Assertions

A. The module SHALL include testing utilities to support unit, integration, and end-to-end testing of applications using the module.
B. The module SHALL provide a mock event store for unit testing.
C. The module SHALL provide an in-memory repository for integration tests.
D. The module SHALL provide test fixtures for common event scenarios.
E. The module SHALL provide time manipulation utilities for testing event ordering.
F. The module SHALL provide assertion helpers for event verification.
G. The module SHALL provide mock implementations of all interfaces.
H. The module SHALL provide test fixtures covering common event scenarios.
I. The module SHALL include documentation of testing best practices.
J. The module SHALL include example test suites demonstrating usage.

*End* *Automated Testing Support* | **Hash**: fb5dbbff
---

---

# REQ-p01016: Performance Benchmarking

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Client applications must be responsive and efficient to provide good user experience and avoid user frustration. Performance benchmarks establish quantifiable targets for critical operations including event persistence, synchronization, querying, and resource consumption. These targets ensure the system remains usable across varying network conditions and device capabilities while maintaining acceptable battery and memory usage.

## Assertions

A. The system SHALL complete event creation and local persistence operations in less than 10 milliseconds at the 95th percentile.
B. The system SHALL complete event synchronization in less than 100 milliseconds per event at the 95th percentile under good network conditions.
C. The system SHALL complete materialized view queries in less than 50 milliseconds at the 95th percentile when cached.
D. The system SHALL drain the offline queue at a rate greater than 10 events per second.
E. The system SHALL maintain a memory footprint of less than 50 megabytes during typical usage.
F. The system SHALL consume less than 1% battery per hour during active synchronization.
G. The system SHALL pass all defined performance target benchmarks in automated benchmark tests.
H. The system SHALL include performance regression tests in the CI/CD pipeline.
I. The system SHALL provide documentation describing performance characteristics of all benchmarked operations.
J. The system SHALL provide profiling guides for optimizing specific performance scenarios.

*End* *Performance Benchmarking* | **Hash**: 2c0805cf
---

---

# REQ-p01017: Backward Compatibility Guarantees

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Forcing breaking changes on consumers creates upgrade friction and technical debt. Backward compatibility enables continuous improvement without disruption. This requirement ensures that the clinical trial platform can evolve while minimizing impact on deployed applications and sponsor-specific implementations. By following semantic versioning and providing clear deprecation paths, the system allows sponsors to upgrade dependencies on their own timeline while maintaining stability.

## Assertions

A. The module SHALL maintain backward compatibility for public APIs across minor versions.
B. The system SHALL use semantic versioning with MAJOR.MINOR.PATCH format.
C. The module SHALL NOT introduce breaking API changes in MINOR versions.
D. The module SHALL NOT introduce breaking API changes in PATCH versions.
E. Breaking API changes SHALL only be introduced in MAJOR version releases.
F. Deprecated APIs SHALL emit compiler warnings when used.
G. The system SHALL provide deprecation warnings for at least one major version before removing deprecated APIs.
H. The system SHALL provide comprehensive migration guides for all major version upgrades.
I. The system SHALL include automated compatibility tests that verify compatibility against previous versions.

*End* *Backward Compatibility Guarantees* | **Hash**: c0664b5d
---

---

# REQ-p01018: Security Audit and Compliance

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

Healthcare applications handle sensitive Protected Health Information (PHI) and must meet stringent security standards to protect patient privacy and maintain regulatory compliance. FDA 21 CFR Part 11 requires electronic record systems to implement controls to ensure authenticity, integrity, and confidentiality. This requirement establishes a defense-in-depth security posture through multiple layers: proactive vulnerability prevention, secure data handling, automated continuous scanning, third-party validation, and comprehensive documentation. Together, these measures reduce risk of data breaches, ensure compliance with healthcare regulations (HIPAA, FDA), and maintain trust with patients and sponsors.

## Assertions

A. The system SHALL undergo security review to identify and remediate vulnerabilities.
B. The system SHALL maintain compliance with relevant security standards including FDA 21 CFR Part 11.
C. The system SHALL address OWASP client Top 10 vulnerabilities.
D. The system SHALL implement secure storage mechanisms for sensitive data.
E. The system SHALL implement protection against injection attacks.
F. The system SHALL use TLS 1.3 or higher for all network communication.
G. The system SHALL perform dependency vulnerability scanning.
H. The system SHALL undergo regular security audits.
I. The system SHALL NOT have any HIGH severity vulnerabilities in dependencies at release time.
J. The system SHALL NOT have any CRITICAL severity vulnerabilities in dependencies at release time.
K. The system SHALL undergo a security audit by a third-party vendor before 1.0 release.
L. The system SHALL integrate automated vulnerability scanning into the CI/CD pipeline.
M. The system SHALL provide documentation of the security architecture.
N. The system SHALL validate compliance against FDA 21 CFR Part 11 requirements.

*End* *Security Audit and Compliance* | **Hash**: acb9854a
---

## FDA 21 CFR Part 11 Compliance Considerations

### Audit Trail Requirements

The module supports FDA 21 CFR Part 11 compliance through:

**§11.10(e) - Audit Trail**: Events form an immutable, chronological audit trail recording:
- User identification (user_id in each event)
- Date and time stamp (created_at with server time)
- Action performed (event_type)
- Data values entered or changed (event_payload with old/new values)

**§11.10(c) - Sequence of Operations**: Event sequence numbers ensure chronological integrity and detect tampering.

**§11.50 - Signature Manifestations**: Event causation IDs create a chain of custody showing who initiated events and why.

**§11.10(a) - Validation**: The module must be validated in the context of each application deployment (not the module itself).

### Implementation Guidance

Applications using this module SHALL:
- Configure user authentication and identity management
- Implement event signing or hashing for tamper detection
- Ensure reliable time synchronization (NTP)
- Maintain event retention per regulatory requirements
- Validate the module in their specific deployment context

**See**: prd-clinical-trials.md for complete compliance requirements
**See**: dev-compliance-practices.md for implementation guidance

---

## Integration with Existing Systems

### PostgreSQL Schema Requirements

The module expects the following database schema structure:

**Events Table** (append-only):
- `id`: BIGSERIAL PRIMARY KEY
- `aggregate_id`: UUID (entity identifier)
- `event_type`: VARCHAR (event class name)
- `event_version`: INTEGER (schema version)
- `payload`: JSONB (event data)
- `metadata`: JSONB (user_id, timestamp, causation_id, etc.)
- `created_at`: TIMESTAMPTZ (server timestamp)
- `sequence`: BIGSERIAL (global ordering)

**Materialized Views**: Application-specific, refreshed by triggers or scheduled jobs

**Schema Versions Table**:
- `version`: INTEGER PRIMARY KEY
- `applied_at`: TIMESTAMPTZ
- `description`: TEXT
- `migration_script`: TEXT

### Migration Assumptions

The module assumes:
- Database migration managed by tools like Flyway, Liquibase, or Sqitch
- Schema version table maintained by migration tool
- Module queries schema version on startup for compatibility checks

---

## Open Source Ecosystem

### Existing Solutions Review

Based on research, existing application event sourcing solutions include:

**Harvest** (github.com/ltackmann/harvest):
- Event store for programming language with multiple backends
- Messagebus and CQRS framework
- Last updated: 2019 (may be stale)

**Jaguar-programming language/cqrs** (github.com/Jaguar-programming language/cqrs):
- Command Query Responsibility Separation library
- Lightweight, minimal dependencies
- Last updated: 2019 (may be stale)

**EventStore Client for programming language** (github.com/DISCOOS):
- Client for EventStoreDB
- Industry-leading event sourcing database
- Requires EventStoreDB instead of PostgreSQL

**Messaging** (github.com/mcssym):
- Flexible application event sourcing package
- Appears more active (2020+)
- Focuses on message bus patterns

### Differentiation

This module differs by:
- **PostgreSQL-specific**: Optimized for PostgreSQL event store
- **Offline-first**: client-optimized with offline queue
- **Compliance-focused**: FDA 21 CFR Part 11 support built-in
- **Production-ready**: Monitoring, testing, performance guarantees
- **Actively maintained**: Long-term support commitment

---

## Development Approach

---

# REQ-p01019: Phased Implementation

**Level**: PRD | **Status**: Draft | **Implements**: p00046

## Rationale

This requirement establishes a phased development approach for the event sourcing module to reduce implementation risk and enable early validation. The incremental delivery strategy allows the team to validate core assumptions with a minimal viable product (Phase 1), harden the implementation for production environments (Phase 2), and optionally add advanced enterprise features (Phase 3). This approach enables course correction based on real-world usage patterns and ensures each phase delivers measurable value before proceeding to the next.

## Assertions

A. The system SHALL implement event creation and local storage in Phase 1.
B. The system SHALL implement an offline queue with manual synchronization in Phase 1.
C. The system SHALL implement basic materialized view queries in Phase 1.
D. The system SHALL implement simple conflict detection in Phase 1.
E. The system SHALL implement schema version awareness in Phase 1.
F. The system SHALL implement automatic synchronization and retries in Phase 2.
G. The system SHALL implement real-time subscriptions in Phase 2.
H. The system SHALL implement comprehensive error handling in Phase 2.
I. The system SHALL implement monitoring and observability capabilities in Phase 2.
J. The system SHALL implement performance optimization in Phase 2.
K. The system SHALL support event replay and time travel in Phase 3.
L. The system SHALL support encryption at rest in Phase 3.
M. The system SHALL support multi-tenancy in Phase 3.
N. The system SHALL support event transformation in Phase 3.
O. Each phase SHALL be independently deployable.
P. Phase 1 deliverables SHALL be sufficient for pilot applications.
Q. Phase 2 deliverables SHALL be ready for production use.
R. Phase 3 deliverables SHALL add enterprise features.

*End* *Phased Implementation* | **Hash**: 44d8ece3
---

## Success Metrics

**Developer Experience**:
- Time to integrate: < 4 hours for experienced application developer
- Lines of boilerplate: < 50 LOC for typical use case
- Onboarding documentation: Complete tutorial + examples

**Performance**:
- Event creation latency: < 10ms (p95)
- Offline queue capacity: 10,000+ events
- Synchronization throughput: 10+ events/second

**Reliability**:
- No data loss in offline scenarios
- 99.9%+ event delivery success rate
- Graceful degradation under network stress

**Adoption**:
- Used in at least 2 production applications
- Positive developer feedback (surveys/interviews)
- Active community contributions

---

## References

- **Event Sourcing Pattern**: prd-database-event-sourcing.md
- **Database Architecture**: prd-database.md
- **Compliance Requirements**: prd-clinical-trials.md
- **Implementation Details**: dev-application-event-sourcing.md (to be created)
- **Operations Guide**: ops-application-event-sourcing.md (to be created)

---

## Glossary

**Event**: Immutable record of a state change that has occurred
**Event Store**: Append-only database of events
**Materialized View**: Pre-computed current state derived from events
**CQRS**: Command Query Responsibility Segregation - separate read/write paths
**Aggregate**: Entity or group of entities that form consistency boundary
**Causation**: The cause-and-effect relationship between events
**Idempotency**: Property where operation can be applied multiple times without changing result
**Optimistic Concurrency**: Conflict detection based on version checking
**Upcasting**: Transforming old event format to new format

---

## References

- **Diary Implementation**: prd-database.md
- **Development Guide**: dev-event-sourcing-postgres.md (to be created)
- **Operations Guide**: ops-event-sourcing-deployment.md (to be created)
- **Compliance**: prd-clinical-trials.md

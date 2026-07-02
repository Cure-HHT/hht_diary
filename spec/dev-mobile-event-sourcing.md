# Mobile *Diary*: Event-Sourcing Adoption

The mobile *Diary* application is built on the external `event_sourcing` library stack (`event_sourcing` / `reaction` / `reaction_widgets`) rather than an in-tree datastore. These DEV requirements record how the *Diary*'s data layer composes that stack: a single local scope as the adoption hub, qualifying state in the event log, writes through the *Action* dispatcher, reactive reads, on-device authorization, native outbound synchronization, and inbound receipt as events.

## DIARY-DEV-evs-stack-adoption: Diary Adopts the Event-Sourcing Stack

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-offline-first

### Overview

The *Diary*'s data layer is provided by the external `event_sourcing` library rather than an in-tree module, so the *Diary* inherits the library's correctness guarantees and shared evolution. The application composes the library through a single `LocalScope` mounted at the application root and contains no parallel reimplementation of the mechanics the library already provides. This requirement is the local adoption hub that the other mobile event-sourcing DEV requirements refine.

### Assertions

A. The mobile *Diary* SHALL depend on the `event_sourcing`, `reaction`, and `reaction_widgets` libraries for its data layer, with no in-tree event-store module.

B. The mobile *Diary* SHALL compose its data layer through a single `LocalScope` mounted at the application root via the `reaction_widgets` scope.

C. The mobile *Diary* SHALL NOT reimplement event-log, projection, dispatch, or synchronization mechanics that the library provides.

### Rationale

Delegating the data layer to the shared library keeps the *Diary* aligned with the platform's event-sourcing correctness guarantees — append-only log, deterministic materialization, hash-chain integrity — and means improvements to the substrate are inherited rather than re-engineered. A single root-mounted scope gives every screen one consistent path to the event-sourced truth, and the no-reimplementation rule prevents a divergent second source of truth from growing inside the application.

*End* *Diary Adopts the Event-Sourcing Stack* | **Hash**: 663897f8

## DIARY-DEV-state-in-event-log: Qualifying App State Lives in the Event Log

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-evs-stack-adoption

### Overview

State that is part of the *Diary*'s auditable record belongs in the append-only event log, not a side key-value store that can diverge from it. Enrollment, task/*Trial*, and settings/language state move into events; secrets remain in secure storage; anything kept app-local is either ephemeral or a rebuildable projection.

### Assertions

A. The System SHALL record enrollment, task/*Trial*, and settings/language state as events in the append-only event log rather than as `shared_preferences` entries.

B. The System SHALL keep secrets — credentials and tokens — in `flutter_secure_storage` and SHALL NOT write them to the event log.

C. The System SHALL keep any app-local state either genuinely ephemeral or a rebuildable projection of the event log, holding no authoritative state.

### Rationale

An event-sourced *Diary* whose enrollment and settings state lived in a side key-value store would have two sources of truth that can silently diverge, defeating reconstructability and the audit guarantee. Recording that state as events makes it part of the same attributable, tamper-evident log as the *Diary* entries. Secrets are the deliberate exception: they carry no audit value in the log and belong in platform secure storage, so they stay out of the event stream.

*End* *Qualifying App State Lives in the Event Log* | **Hash**: d6fb9049

## DIARY-DEV-action-write-path: Writes Flow Through the Action Dispatcher

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-evs-stack-adoption

### Overview

Every *Diary* write is submitted as an *Action* and dispatched through the core dispatcher, giving uniform validation, authorization, idempotency, and recording. No screen reaches around the dispatcher to append events directly.

### Assertions

A. The System SHALL submit each *Diary* write as an `ActionSubmission` dispatched through the core `ActionDispatcher`.

B. The System SHALL express *Diary* write-validation rules — time restrictions, duration checks, and *Overlap* — in the *Action*'s validate step.

C. The System SHALL NOT provide any screen a direct event-append path that bypasses the dispatcher.

### Rationale

Routing every write through one dispatcher is what makes validation, authorization, idempotency, and recording uniform rather than re-implemented per screen. Putting the *Diary*'s domain validation in each *Action*'s validate step keeps the rule and the write atomic — an invalid write never reaches the log. Forbidding direct-append back-doors guarantees the dispatcher's guarantees actually hold for the whole application.

*End* *Writes Flow Through the Action Dispatcher* | **Hash**: ea6148a0

## DIARY-DEV-reactive-read-path: Screens Read via Reactive Subscriptions

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-evs-stack-adoption

### Overview

Screens obtain *Diary* state through reactive views bound to registered projections, keeping the interface consistent with the event-sourced truth without manual polling. Read helpers that reproduce date, day-status, and incomplete semantics are thin wrappers over the subscription, and no app-side layer holds authoritative state.

### Assertions

A. The System SHALL provide screens their *Diary* state through a reactive view bound to a registered projection; no screen SHALL poll the datastore with one-shot reads.

B. The System SHALL implement read helpers that reproduce date, day-status, and incomplete semantics as thin wrappers over the reactive subscription, exposing live streams.

C. The System SHALL keep any app-side state layer free of authoritative state and fully reconstructible by re-subscribing.

### Rationale

Reactive reads keep the UI in lockstep with the event-sourced truth: when the log changes, the projection emits and the screen rebuilds, with no polling loop to drift out of date. Expressing the date/day-status/incomplete helpers as thin subscription wrappers means there is one derivation of those semantics, live everywhere. Keeping the app-side layer non-authoritative and re-subscribable preserves the correctness guardrail — every on-screen value is a rebuildable projection of the log, never independent mutable truth.

*End* *Screens Read via Reactive Subscriptions* | **Hash**: f37501bb

## DIARY-DEV-native-outbound-sync: Outbound Sync via Native Ingest Destination

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-evs-stack-adoption

### Overview

The server ingest edge runs the same `event_sourcing` library, so the *Diary* synchronizes natively rather than mapping to a legacy wire format. A single native `Destination` ships finalized and tombstone entry events as canonical batches, classifies delivery outcomes for safe retry, gates on the *Trial*-start watermark, and carries the device source identity as provenance.

### Assertions

A. The System SHALL ship finalized and tombstone *Diary* entry events to the server ingest edge as canonical batches through a single native `Destination`; checkpoint drafts SHALL remain local.

B. The System SHALL classify each delivery outcome as accepted, retry-with-backoff, or wedged, and SHALL retry transient conditions — offline, not-yet-enrolled, server error — without data loss.

C. The System SHALL gate outbound synchronization on the *Trial*-start watermark, keeping events dated before *Trial Start* local.

D. The System SHALL carry the device source identity as provenance on each batch, leaving *Participant* correlation to the server at ingest.

### Rationale

Because the server ingest edge runs the same substrate, a native canonical batch needs no lossy mapping to a legacy wire format and preserves the event identity end-to-end. The ingest-edge contract is defined by `DIARY-DEV-participant-ingest`; that edge is hosted on the *Sponsor Portal* server today (device-to-portal direct) and relocates to a dedicated *Diary* server under the deferred edge/core split. Classifying delivery outcomes lets transient failures retry with backoff instead of dropping data, while a genuinely wedged batch is surfaced rather than silently lost. The *Trial*-start watermark keeps the server dataset bounded to the *Trial* period even when the personal *Diary* extends earlier, and shipping the device source identity (rather than a resolved *Participant*) keeps correlation an ingest-side, server-authoritative decision.

*End* *Outbound Sync via Native Ingest Destination* | **Hash**: ebaa5551

## DIARY-DEV-participant-state-poll: Diary Lifecycle Propagation via State Poll

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-participant-disconnection

### Overview

The portal-side lifecycle *Actions* (disconnect, mark-not-participating, reconnect, reactivate) reach the *Diary* through the *Participant* state endpoint the *Diary* already polls for the *Trial*-start watermark. The endpoint exposes the two lifecycle facts the *Diary* acts on, and the *Diary* translates them into its synchronization and enrollment state. (Push delivery of these facts is the primary channel in the full design; this polled channel is the always-available backup, and the two share this contract.)

### Assertions

A. The *Diary* server SHALL expose, at the *Participant* state endpoint, whether the *Participant* is currently disconnected and whether the *Participant* is not-participating, each derived from the *Participant*'s most recent lifecycle event so that the two facts are mutually exclusive.

B. The *Diary* SHALL poll the *Participant* state endpoint and, on detecting either a disconnected or a not-participating state, SHALL discard its *Session* credential and stop synchronizing, so that resuming participation requires re-establishing the link with a new *Mobile Linking Code*; the *Diary* SHALL NOT silently resume synchronization on reconnection or reactivation. A subsequent successful re-link SHALL clear both states and return the *Diary* to active synchronization.

### Rationale

Routing lifecycle propagation through the same state endpoint the *Diary* already polls avoids a second device-facing contract and keeps the *Diary* authoritative over its own synchronization behavior. Deriving both facts from the latest lifecycle event makes them mutually exclusive — mark-not-participating supersedes disconnected — and lets the device distinguish the two for its interface, even though it acts on both identically at the credential layer. Discarding the *Session* credential on either transition is what makes both the reconnection and the reactivation workflows go back through the *Mobile Linking Code* mechanism rather than silently resuming: disconnection releases the device binding, and reconnection (which reactivation is routed through) restores the link only when the *Participant* enters a fresh code — a deliberate defense against resuming on a device that may no longer be in the *Participant*'s possession. The locally-buffered disconnected-period entries ship on the next drain once that re-link succeeds. The two states differ only in *Sponsor*-rule retention and interface presentation (a reconnection prompt versus an off-*Trial* notice), not in credential handling.

*End* *Diary Lifecycle Propagation via State Poll* | **Hash**: 0a04e639

## DIARY-DEV-local-participant-authorization: On-Device Authorization Permits the Local Participant

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-evs-stack-adoption

### Overview

The *Diary* is local-first and single-*User*: recording must work regardless of study enrollment. On-device authorization permits the authenticated local *Participant* their own actions, and the server re-validates synced events at ingest as the authoritative gate.

### Assertions

A. The System SHALL authenticate the local *Participant* from first launch with a stable per-install identifier, independent of study linking.

B. The System SHALL permit recording, editing, deleting, and submitting *Diary* entries regardless of study-enrollment status.

C. The System SHALL gate outbound synchronization, not local data entry, on study enrollment.

D. On-device authorization SHALL permit the authenticated local *Participant* the declared *Diary* permissions and SHALL NOT be the authoritative authorization gate.

### Rationale

A *Participant* may install the *Diary* and begin recording before any study linking completes, and may need to backfill events while enrollment is pending; gating local entry on enrollment would lose contemporaneous data. So on-device authorization is deliberately permissive for the local *Participant*, and the only enrollment gate is on synchronization. The device is not trusted as the authority — the server re-validates every synced event at ingest — so a permissive on-device policy cannot admit unauthorized data to the canonical record.

*End* *On-Device Authorization Permits the Local Participant* | **Hash**: 5b6674c2

## DIARY-DEV-inbound-event-on-receipt: Inbound Receipt Emits an Event

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-evs-stack-adoption

### Overview

Keeping the FCM-primary / polling-backup receive interface while turning receipt into an event makes inbound messages first-class, auditable *Diary* state. On receipt the application emits a registered event into its own *Event Store* via an *Action*, and acknowledgement of a received command is itself a recorded *Action*.

### Assertions

A. The System SHALL retain the FCM-primary / polling-backup receive interface unchanged.

B. On receipt of a message or a positive poll result, the System SHALL emit a registered event into its own *Event Store* via an *Action*.

C. The System SHALL record acknowledgement of a received command as an *Action* and event, routed outbound.

### Rationale

Inbound messages are part of what happened on the device and therefore belong in the same append-only record as everything else; emitting an event on receipt makes them reconstructible and auditable rather than transient side effects. The existing FCM-primary / polling-backup interface is retained unchanged because it already meets the delivery requirements — only the handling changes, turning a received message into a first-class event. Recording command acknowledgement as its own event closes the loop, so the log shows not just that a command arrived but that the device acted on it.

> **Partially realized:** Assertion C is realized for the questionnaire-recall
> command: on receipt of a recall, the device emits an outbound
> `questionnaire_recall_acked` event that echoes the recall flow token, closing
> the command loop for that specific command type. The general node-to-node
> cross-post for other command types remains future work (CUR-1371); assertion C
> carries no implementation or verification annotation for those commands until
> that work lands — the absence is intentional, not an accidental coverage gap.

*End* *Inbound Receipt Emits an Event* | **Hash**: 9143d6c4

## DIARY-DEV-device-health-checks: On-Demand Device Health Checks

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-device-health-diagnostics

### Overview

The device health diagnostic is implemented as a registry of independent checks plus a metadata-only raw appendix builder. The checks are pure functions over a probe context and run only when the export is requested, so the steady-state cost is unchanged. The registry is extensible: a new condition ships as one more check in the same application update that carries its fix.

### Assertions

A. The **System** SHALL evaluate the registered health checks only when the diagnostic export is requested, performing no additional periodic evaluation in steady state.

B. The **System** SHALL include health checks for a wedged outbound synchronization queue, synchronization backlog growth, event hash-chain link contiguity, local event-store writability, and authorization and link state.

C. A health check that fails to execute SHALL yield a warning finding and SHALL NOT abort the remaining checks or the export.

D. The diagnostic export's raw appendix SHALL serialize event headers, synchronization-queue entry metadata and attempt outcomes, cursors, counts, device identity, and clock and time-zone facts, and SHALL omit event payload bodies.

### Rationale

Pure, registry-based checks are independently testable and keep the failure of one check from taking down the rest — important on an already-sick device where the diagnostic must not itself crash. Running the battery only on request honors the common-fast/rare-possible principle: a wedge is a near-never event and the export a near-never operation, so a one-shot evaluation costs nothing in normal operation. The named-check list captures the conditions understood today; unknown conditions are read out of the raw appendix first and promoted to a named check only when they recur. The raw appendix is restricted to headers and operational metadata so the artifact is PHI-free by construction, satisfying the parent's content limit while still carrying everything needed to diagnose a transport, ordering, or integrity fault.

*End* *On-Demand Device Health Checks* | **Hash**: 8d3827d5

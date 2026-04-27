# Storage Failure Handling — Design

**Date**: 2026-04-22
**Branch**: mobile-event-sourcing-refactor
**Authors**: brainstormed in session
**Status**: Design — pending review and implementation plan

---

## 1. Motivation

The mobile event-sourcing refactor (CUR-1154) introduces `EntryService.record` as the sole patient-facing write API and commits to atomic local writes (REQ-d00117, REQ-d00133). A pre-implementation review surfaced a gap: when the local storage layer itself fails — disk full, lock contention, file corruption, schema unreadability — there is no contract for what the user sees, no contract for how the system surfaces the failure, and no commitment to data preservation in the failure path. The same gap exists on the planned server side once portal ingestion lands: PostgreSQL on Cloud SQL has analogous failure modes (volume full, deadlock, corruption, connection loss) and no current spec governs its failure UX.

This design fills that gap with one new PRD requirement and a new dev-level spec file holding 14 implementation requirements, organized as: shared abstractions, mobile-specific overlay, server-specific overlay.

## 2. Scope

In scope:

| # | Failure mode | Surface |
| --- | --- | --- |
| 1 | Local write fails — disk full / quota exceeded / sandbox limit | Mobile and server |
| 2 | Local write fails — lock or transaction timeout | Mobile and server |
| 3 | Local write fails — corrupted file / failed integrity check | Mobile and server |
| 4 | Store open/init fails — file missing, permission denied, schema unreadable | Mobile and server |
| 5 | Read returns corrupted data (triggers materialized-view rebuild) | Mobile |
| 6 | Capacity pre-warning — disk space below configured threshold | Mobile and server |
| 7 | Server connection lost mid-operation, pool exhausted | Server |
| 8 | FIFO destination exhausted — surfaced via Storage Health | Mobile |
| 9 | Storage Health query and stream surface (snapshot + transitions) | Mobile and server |
| 10 | Storage Failure Audit log (durable, separate from event log) | Mobile and server |
| 11 | Failure injection seam for testing | Mobile and server |

## 3. Out of scope

| Item | Reason |
| --- | --- |
| Sync transport failures (`SendTransient`/`SendPermanent` categorization) | Already covered by REQ-d00122-E and REQ-d00124 |
| At-rest encryption of the mobile event store | Encryption itself is deferred (see `project_event_sourcing_refactor_out_of_scope.md` item 5) |
| UI mockups for "FIFO exhausted — please update" banners | Frontend task; this design only commits to surfacing the state, not its presentation |
| Cloud SQL infrastructure-level concerns (replica lag, failover) | GCP/Cloud SQL configuration; not application-level |
| Decisions about what to *do* with surfaced state (alert routing, banner display, email cadence) | Caller's responsibility; this design only commits to making the state queryable and observable |
| Backpressure (slow writes when **Warning Tier** reached) | Deliberately omitted; can be added in a later REQ if shown to be needed |

## 4. Structure decisions

### 4.1 File layout

Two files touched, one new:

| File | Change |
| --- | --- |
| `spec/prd-event-sourcing-system.md` | Append **REQ-p01087** (Storage Failure Visibility) |
| `spec/dev-storage-failure-handling.md` | **New file** — holds REQ-d00135 through REQ-d00148 |
| `spec/INDEX.md` | Append the 15 new entries |
| `spec/NFR/glossary-core.md` (or project-equivalent glossary) | Append the new defined terms (see §5) |

Why a new dev file rather than appending to `dev-event-sourcing-mobile.md`: the failure story spans both mobile and server, so a separate home reads better and avoids further bloating the mobile spec.

### 4.2 REQ ID allocation

Highest existing PRD ID: REQ-p01086. Next free: **REQ-p01087**.

Highest existing dev ID: REQ-d00134. Next free range: **REQ-d00135 through REQ-d00148** (14 IDs).

### 4.3 Style conformance

This spec follows `spec/NFR/style-guide.md`:

- EARS syntax (Ubiquitous, Event-Driven, State-Driven, Unwanted Behavior, Optional Feature)
- Active voice with **the System** as subject
- Atomic assertions; no inter-REQ references in assertion text
- Defined terms bolded; cross-referenced via the glossary, not via REQ IDs
- Configurable values in `{{double_curly_braces}}`
- PRD assertions free of programming languages, libraries, frameworks, and API signatures
- SHALL only inside Assertions sections (Rationale text uses normal prose)

## 5. Glossary additions

The following terms are added to the project glossary. Wherever they appear in assertion text, they are bolded.

| Term | Definition |
| --- | --- |
| **Storage Exception** | Categorized exception thrown by storage write paths. Carries one of the **Storage Failure Categories**, the underlying cause when available, and a structured context map for diagnostic fields. |
| **Storage Failure Category** | One of the named failure categories defined by the **Storage Failure Taxonomy**: **Capacity Exhausted**, **Concurrency Timeout**, **Store Corrupted**, **Store Unavailable**, or **Connection Lost**. |
| **Storage Failure Taxonomy** | The closed enumeration of **Storage Failure Categories** that anchors the cross-platform failure model. |
| **Capacity Exhausted** | Storage operation rejected because the target volume, quota, or sandbox limit has no remaining space. |
| **Concurrency Timeout** | Storage operation rejected because lock acquisition or transaction completion exceeded its time bound. |
| **Store Corrupted** | Storage operation rejected because the store's contents fail an integrity or consistency check. |
| **Store Unavailable** | Storage operation rejected because the store cannot be opened — file absent, permission denied, schema unreadable, or the database server is in startup, recovery, or shutdown. |
| **Connection Lost** | Server-side: storage operation rejected because an established database connection dropped, the connection pool was exhausted, or transport security failed. |
| **Storage Health** | Read-only ambient state of a local datastore: **Capacity Tier**, list of FIFO destinations currently exhausted (where applicable), and the most recent **Storage Failure Audit** record. Exposed as both an on-demand snapshot and a transition stream. |
| **Capacity Tier** | One of **Ok Tier**, **Warning Tier**, or **Critical Tier**, computed from current free space against configured thresholds. |
| **Ok Tier** | The **Capacity Tier** value indicating ample free space — at or above the warning threshold. |
| **Warning Tier** | The **Capacity Tier** value indicating diminishing free space — below the warning threshold and at or above the critical threshold. |
| **Critical Tier** | The **Capacity Tier** value indicating imminent exhaustion — below the critical threshold. |
| **Storage Failure Audit** | Durable record of a single **Storage Exception** that escaped its call site, retained independently of the event log for diagnostic review. |
| **System Operator** (synonym **Sysop**) | A human role: vendor staff who deploy, maintain, and monitor the **Sponsor Portal** service. |
| **Sponsor Administrator** (synonym **Admin**) | A human role: a **Sponsor Portal** **User** with elevated privileges as defined by the **Sponsor**'s protocol. |

The terms **User**, **Participant**, **Sponsor**, **Sponsor Portal**, and **Diary Entry** are assumed to already exist in the project glossary; if any are missing, they are added as part of this spec's implementation.

## 6. PRD requirement

### REQ-p01087: Storage Failure Visibility

```text
# REQ-p01087: Storage Failure Visibility

Level: prd | Status: Draft | Implements: -
Refines: REQ-p00006

## Rationale

REQ-p00006 commits to offline-first data entry and to preserving entries
across unexpected closure, but does not address what happens when the
storage layer itself cannot accept a submission. A **User** who believes
a submission succeeded when it did not loses trust in the diary; a
**Sponsor** who cannot see degradation in the **Participant**-data store
cannot meet its oversight obligations. This requirement establishes the
visibility commitment that closes that gap.

## Assertions

A. If a **Diary Entry** submission cannot be persisted, then the System
   SHALL notify the **User** that the submission did not succeed.

B. The System SHALL distinguish a failed submission from a successful
   submission in every **User**-facing display of submission status.

C. The System SHALL provide an advance indication to the **User** when
   storage capacity approaches exhaustion.

D. Where the **User** is a **Participant**, the System SHALL provide the
   **Sponsor** with the capability to monitor the operational state of
   the **Participant**-data store.

E. Where the **User** is a **Participant**, the System SHALL retain a
   record of every storage failure affecting that **Participant**'s data
   for later **Sponsor** review.
```

Notes:

- D and E use the **Where** EARS pattern (Optional Feature) to scope sponsor-facing assertions to the participant case. Non-participant **Users** of the diary app have no **Sponsor** to surface to.
- A uses the **If/Then** pattern (Unwanted Behavior).
- B, C, D, E use the Ubiquitous pattern.
- The vendor-vs-regulated-entity wording rule applies in D: the System provides the *capability* to monitor; the **Sponsor** is the recipient of that capability.

## 7. Dev requirements

All assertions below are framed in EARS syntax with **the System** as subject. Defined terms are bolded; configurable values are in `{{double_curly_braces}}`. Each REQ ends with the standard `*End*` footer (hash field marked `pending` until INDEX is regenerated).

### 7.1 Shared abstractions

#### REQ-d00135: Storage Failure Taxonomy

```text
# REQ-d00135: Storage Failure Taxonomy

Level: dev | Status: Draft | Implements: REQ-p01087

## Rationale

A finite, named set of failure categories anchors the cross-platform
storage failure model. Callers, tests, and operator-facing surfaces all
reference these names; per-platform classifiers translate underlying
errors into one of them. The set is closed: an underlying error that
matches none of these is a gap in the platform-specific classifier, not
a sixth category, and is to be re-raised unwrapped so the surrounding
caller still receives the original exception.

## Assertions

A. The System SHALL define exactly five **Storage Failure Categories**:
   **Capacity Exhausted**, **Concurrency Timeout**, **Store Corrupted**,
   **Store Unavailable**, and **Connection Lost**.

B. The System SHALL NOT introduce a sixth or further
   **Storage Failure Category** without amending this requirement.

C. Each per-platform classifier SHALL map every classifiable underlying
   error into exactly one **Storage Failure Category**.

D. If an underlying error matches none of the **Storage Failure
   Categories**, then the per-platform classifier SHALL re-raise the
   error unwrapped.

*End* *Storage Failure Taxonomy* | **Hash**: pending
```

#### REQ-d00136: Storage Exception Hierarchy

```text
# REQ-d00136: Storage Exception Hierarchy

Level: dev | Status: Draft | Implements: REQ-p01087

## Rationale

A categorized **Storage Exception** lets callers branch on failure mode
without parsing platform-specific error codes. A common base class with
typed subtypes — one per **Storage Failure Category** — gives callers
both type-safe pattern matching and uniform structured-context
propagation across mobile and server.

## Assertions

A. The System SHALL define a base **Storage Exception** type from which
   every per-category storage-failure exception derives.

B. The System SHALL define exactly one exception subtype per
   **Storage Failure Category**.

C. Each **Storage Exception** SHALL carry the **Storage Failure
   Category** that classifies it.

D. Each **Storage Exception** SHALL carry the underlying error from
   which it was classified, when one is available.

E. Each **Storage Exception** SHALL carry a structured context map for
   diagnostic fields supplied by the throwing call site.

*End* *Storage Exception Hierarchy* | **Hash**: pending
```

#### REQ-d00137: Storage Health Query Surface

```text
# REQ-d00137: Storage Health Query Surface

Level: dev | Status: Draft | Implements: REQ-p01087

## Rationale

Ambient operational state — capacity tier, exhausted FIFO destinations,
most recent failure — is not naturally surfaced as a thrown exception
because it does not correspond to a specific call. **Storage Health**
provides this state as a pull-based snapshot for callers reading on
demand, and as a push-based stream for callers reacting to transitions.
Reading health must never itself raise a **Storage Exception**, because
a thrown exception from the health surface defeats the purpose of having
a separate ambient-state channel.

## Assertions

A. The System SHALL expose **Storage Health** as a snapshot readable on
   demand.

B. The System SHALL expose **Storage Health** as a stream that emits a
   value on every transition of the snapshot's value.

C. The **Storage Health** snapshot SHALL include the current
   **Capacity Tier**.

D. The **Storage Health** snapshot SHALL include the most recent
   **Storage Failure Audit** record, or null when no failure has been
   recorded since startup.

E. Where the platform exposes FIFO destinations, the **Storage Health**
   snapshot SHALL include the list of FIFO destination identifiers
   currently in exhausted state.

F. Reading the **Storage Health** snapshot or subscribing to the
   **Storage Health** stream SHALL NOT raise any exception derived from
   the **Storage Exception** hierarchy.

*End* *Storage Health Query Surface* | **Hash**: pending
```

#### REQ-d00138: Storage Failure Audit

```text
# REQ-d00138: Storage Failure Audit

Level: dev | Status: Draft | Implements: REQ-p01087

## Rationale

A **Storage Exception** that escapes its call site is operational
diagnostic evidence: it tells an operator what failed, when, in what
context, and from where. Persisting these records to a store independent
of the event log ensures that a corrupted event log does not also
suppress its own failure diagnostics. The retention window aligns with
the diagnostic review cadence rather than with regulatory record
retention, since these are operational records, not patient data.

## Assertions

A. The System SHALL persist a **Storage Failure Audit** record for every
   **Storage Exception** that escapes its originating call site.

B. The System SHALL persist **Storage Failure Audit** records to a
   durable store separate from the event log.

C. Each **Storage Failure Audit** record SHALL carry the timestamp of
   the exception, the **Storage Failure Category**, the structured
   context map carried by the exception, and the caller stack trace.

D. The **Storage Failure Audit** store SHALL retain its records across
   application restart.

E. The System SHALL retain each **Storage Failure Audit** record for at
   least {{audit_retention_period}} after the timestamp of the
   originating exception.

*End* *Storage Failure Audit* | **Hash**: pending
```

### 7.2 Mobile-specific requirements

#### REQ-d00139: Mobile Storage Error Classification

```text
# REQ-d00139: Mobile Storage Error Classification

Level: dev | Status: Draft | Implements: REQ-p01087

## Rationale

The mobile storage backend (Sembast on iOS and Android) raises
exceptions in several Dart and platform-native shapes — `DatabaseException`,
`FileSystemException`, errno-bearing platform errors. The classifier maps
these into the cross-platform **Storage Failure Taxonomy** so callers
can branch on category without knowing platform-specific error shapes.

## Assertions

A. When a Sembast or filesystem error occurs during a storage operation,
   the System SHALL classify the error into exactly one
   **Storage Failure Category** before re-raising.

B. The System SHALL classify any error indicating exhausted disk space,
   exhausted volume quota, or sandbox-imposed storage limit as
   **Capacity Exhausted**.

C. The System SHALL classify any error indicating database lock
   contention or transaction timeout as **Concurrency Timeout**.

D. The System SHALL classify any error indicating database file
   unreadability, integrity check failure, or schema-record corruption
   as **Store Corrupted**.

E. The System SHALL classify any error indicating database file absence,
   permission denial on the database directory, or unreadable schema
   version as **Store Unavailable**.

F. If a raised error does not match any of the **Storage Failure
   Categories**, then the System SHALL re-raise the error unwrapped.

G. If a raised error does not match any of the **Storage Failure
   Categories**, then the System SHALL log a warning identifying the
   unclassified error.

*End* *Mobile Storage Error Classification* | **Hash**: pending
```

#### REQ-d00140: Mobile Capacity Tier Probing

```text
# REQ-d00140: Mobile Capacity Tier Probing

Level: dev | Status: Draft | Implements: REQ-p01087

## Rationale

The mobile **Capacity Tier** is computed from free space on the volume
holding the database file. Probing on app start and on each
synchronization cycle balances responsiveness against polling overhead:
fresh enough that a **User** approaching exhaustion sees the warning
within a sync interval, infrequent enough not to compete with normal
work. Thresholds are configuration-driven so that downstream apps can
tune the warning surface without forking the package; package-supplied
defaults exist so that an app with no override still has a reasonable
contract.

## Assertions

A. The System SHALL determine free space on the storage volume holding
   the database file at app start.

B. While the application is running, the System SHALL re-determine free
   space at each invocation of the synchronization orchestration cycle.

C. The System SHALL classify free space below the {{capacity_warning}}
   threshold and at or above the {{capacity_critical}} threshold as
   **Warning Tier**.

D. The System SHALL classify free space below the {{capacity_critical}}
   threshold as **Critical Tier**.

E. The System SHALL classify free space at or above the
   {{capacity_warning}} threshold as **Ok Tier**.

F. When the **Capacity Tier** transitions, the System SHALL emit a
   transition value on the **Storage Health** stream.

G. The System SHALL source {{capacity_warning}} and {{capacity_critical}}
   from runtime configuration with package-supplied defaults.

*End* *Mobile Capacity Tier Probing* | **Hash**: pending
```

#### REQ-d00141: Mobile Materialized View Recovery on Read Corruption

```text
# REQ-d00141: Mobile Materialized View Recovery on Read Corruption

Level: dev | Status: Draft | Implements: REQ-p01087, REQ-p00004

## Rationale

REQ-d00121-G already establishes that the diary-entries materialized
view is a cache rebuildable from the event log. When a read of that
cache raises **Store Corrupted**, automatic rebuild is the natural
recovery path: the event log is the source of truth, the materializer
is a pure function, and the rebuild produces an identical view. If
the event log itself is corrupt, the recovery boundary is reached and
the failure surfaces to the caller; recovery from a corrupt event log
is an operator-driven concern, not an in-app loop.

## Assertions

A. If a read of the materialized diary-entries store raises
   **Store Corrupted**, then the System SHALL trigger a
   materialized-view rebuild from the event log.

B. The rebuild SHALL invoke the existing `rebuildMaterializedView`
   path.

C. While a rebuild is in progress, the System SHALL block subsequent
   reads of the diary-entries store from returning until the rebuild
   completes or fails.

D. If a rebuild itself raises **Store Corrupted** on the event log,
   then the System SHALL surface the failure to the caller.

E. If a rebuild itself raises **Store Corrupted** on the event log,
   then the System SHALL NOT attempt further automatic recovery.

F. The System SHALL log every rebuild trigger with the originating read
   context.

*End* *Mobile Materialized View Recovery on Read Corruption* | **Hash**: pending
```

#### REQ-d00142: Failure Classification on EntryService.record

```text
# REQ-d00142: Failure Classification on EntryService.record

Level: dev | Status: Draft | Implements: REQ-p01087, REQ-p00006

## Rationale

REQ-d00133-E already commits to aborting the whole write on materializer
or storage failure. This requirement adds the classification commitment:
the aborted call surfaces a **Storage Exception** so the caller can
branch on category. Auto-retry is deliberately disallowed at this layer
because retrying on **Capacity Exhausted** compounds the problem and
retrying on **Concurrency Timeout** can mask a real concurrency bug; the
caller is the right party to decide whether and how to retry.

## Assertions

A. If `EntryService.record` cannot complete the local write, then the
   System SHALL throw a categorized **Storage Exception** before
   returning to the caller.

B. The System SHALL include the attempted entry-type identifier and
   aggregate identifier in the thrown **Storage Exception**'s context.

C. The System SHALL NOT return a successful result from
   `EntryService.record` when the underlying write has not committed.

D. The System SHALL NOT retry `EntryService.record` automatically when
   a **Storage Exception** is thrown.

*End* *Failure Classification on EntryService.record* | **Hash**: pending
```

### 7.3 Server-specific requirements

#### REQ-d00143: Server Storage Error Classification

```text
# REQ-d00143: Server Storage Error Classification

Level: dev | Status: Draft | Implements: REQ-p01087

## Rationale

The server storage backend (PostgreSQL on Cloud SQL) raises errors with
SQLSTATE codes. The classifier maps SQLSTATE codes into the
cross-platform **Storage Failure Taxonomy** so server-side callers and
the HTTP response mapping (REQ-d00145) can branch on category without
parsing SQLSTATE strings directly.

## Assertions

A. When a PostgreSQL operation raises a SQLSTATE error, the System SHALL
   classify the error into exactly one **Storage Failure Category**
   before re-raising.

B. The System SHALL classify SQLSTATE 53100 (`disk_full`) and any
   storage-originated 53000-class error as **Capacity Exhausted**.

C. The System SHALL classify SQLSTATE 40P01 (`deadlock_detected`),
   55P03 (`lock_not_available`), and 57014 (`query_canceled`) raised
   by `lock_timeout` or `statement_timeout` expiration as
   **Concurrency Timeout**.

D. The System SHALL classify SQLSTATE XX001 (`data_corrupted`) and
   XX002 (`index_corrupted`) as **Store Corrupted**.

E. The System SHALL classify SQLSTATE 57P03 (`cannot_connect_now`) and
   any open-time failure indicating the database is in recovery,
   shutdown, or startup as **Store Unavailable**.

F. The System SHALL classify any 08000-class connection error raised
   after a connection has been established, and any pool-exhaustion
   error, as **Connection Lost**.

G. If a raised SQLSTATE does not match any of the **Storage Failure
   Categories**, then the System SHALL re-raise the error unwrapped.

H. If a raised SQLSTATE does not match any of the **Storage Failure
   Categories**, then the System SHALL log a warning identifying the
   unclassified SQLSTATE.

*End* *Server Storage Error Classification* | **Hash**: pending
```

#### REQ-d00144: Server Capacity Tier Probing

```text
# REQ-d00144: Server Capacity Tier Probing

Level: dev | Status: Draft | Implements: REQ-p01087

## Rationale

Cloud SQL volume sizing varies by **Sponsor** deployment; package-supplied
threshold defaults would be misleading. Thresholds are sourced entirely
from runtime configuration so each deployment can tune them to its
provisioned volume size and growth profile. The probe interval is
likewise configurable to balance freshness against monitoring-query load.

## Assertions

A. The System SHALL determine database storage utilization at startup.

B. While the server is running, the System SHALL re-determine database
   storage utilization at intervals no greater than
   {{capacity_probe_interval}}.

C. The System SHALL classify utilization at or above the
   {{capacity_warning_pct}} threshold and below the
   {{capacity_critical_pct}} threshold as **Warning Tier**.

D. The System SHALL classify utilization at or above the
   {{capacity_critical_pct}} threshold as **Critical Tier**.

E. The System SHALL classify utilization below the
   {{capacity_warning_pct}} threshold as **Ok Tier**.

F. When the **Capacity Tier** transitions, the System SHALL emit a
   transition value on the **Storage Health** stream.

G. The System SHALL source {{capacity_probe_interval}},
   {{capacity_warning_pct}}, and {{capacity_critical_pct}} from
   runtime configuration.

*End* *Server Capacity Tier Probing* | **Hash**: pending
```

#### REQ-d00145: Storage-Failure HTTP Response Mapping

```text
# REQ-d00145: Storage-Failure HTTP Response Mapping

Level: dev | Status: Draft | Implements: REQ-p01087, REQ-p01001

## Rationale

The mobile FIFO drain loop categorizes server responses into
`SendTransient` (retryable) and `SendPermanent` (not retryable). A
storage failure on the server is always a transient condition from the
mobile's perspective: the **User**'s submission is well-formed, the
server is temporarily unable to accept it, retrying after a backoff is
the correct behavior. Mapping every **Storage Exception** to a 5xx
response — never 4xx — guarantees the mobile FIFO categorizes server-
side storage failures as transient and never wedges. The structured
**Storage Failure Category** in the response body lets operator
dashboards distinguish causes without affecting retry behavior.

## Assertions

A. When the ingest endpoint catches a **Storage Exception**, the System
   SHALL respond with an HTTP status code in the 5xx range.

B. The System SHALL NOT respond with an HTTP status code in the 4xx
   range when the underlying failure is a **Storage Exception**.

C. The System SHALL respond with HTTP 507 (Insufficient Storage) for
   **Capacity Exhausted**.

D. The System SHALL respond with HTTP 503 (Service Unavailable) for
   **Concurrency Timeout**, **Store Unavailable**, and **Store Corrupted**.

E. The System SHALL respond with HTTP 502 (Bad Gateway) for
   **Connection Lost**.

F. The response body SHALL include the **Storage Failure Category** in
   a structured field readable by automated clients.

*End* *Storage-Failure HTTP Response Mapping* | **Hash**: pending
```

#### REQ-d00146: Local Datastore Health External Surface

```text
# REQ-d00146: Local Datastore Health External Surface

Level: dev | Status: Draft | Implements: REQ-p01087

## Rationale

**Storage Health** (REQ-d00137) is the in-process data surface of the
local datastore's operational state. To satisfy REQ-p01087's visibility
commitment, that data must reach the party responsible for acting on it
on each node. On the **Sponsor Portal**, those parties are the
**System Operator** monitoring the deployment and the
**Sponsor Administrator** monitoring the trial; access is governed by
authenticated role checks. On the diary app, the only party present is
the **User**, who is the implicit administrator of their own device;
access is granted to that User without a role check. The privacy
guardrail is framed by content rather than by audience: **Storage
Health** carries operational status only, never **Diary Entry**
contents, regardless of who reads it.

## Assertions

A. The System SHALL expose the **Storage Health** of the local datastore
   on every node where a local datastore exists.

B. On the **Sponsor Portal**, the System SHALL expose **Storage Health**
   via an authenticated read endpoint.

C. On the **Sponsor Portal**, the read endpoint SHALL deny access to any
   caller not holding the **System Operator** role or the
   **Sponsor Administrator** role.

D. On the diary app, the System SHALL expose **Storage Health** via an
   in-app surface accessible to the **User** of the device.

E. The exposed **Storage Health** SHALL include only operational status
   fields.

F. The exposed **Storage Health** SHALL NOT include the contents of any
   **Diary Entry**.

*End* *Local Datastore Health External Surface* | **Hash**: pending
```

#### REQ-d00147: FIFO Exhaustion Surfaced via Storage Health

```text
# REQ-d00147: FIFO Exhaustion Surfaced via Storage Health

Level: dev | Status: Draft | Implements: REQ-p01087, REQ-p01001

## Rationale

A FIFO destination whose head transitions to `exhausted` final_status
represents a delivery wedge requiring human attention. REQ-p01001-H
mandates a user-visible signal for this state but leaves the surfacing
mechanism unspecified. **Storage Health** is the natural carrier:
exhaustion is an ambient operational state, not a per-call failure, and
the existing health surface already plumbs to both the in-app
diagnostics view and the **Sponsor Portal** endpoint. Surfacing both
the onset and the resolution as stream transitions lets a subscribed
UI render the "back to healthy" state without polling.

## Assertions

A. When a FIFO entry's `final_status` transitions to `exhausted`, the
   System SHALL add the destination's identifier to the
   exhausted-destinations field of **Storage Health**.

B. When an identifier is added to the exhausted-destinations field, the
   System SHALL emit a transition value on the **Storage Health**
   stream.

C. When a FIFO destination has no entries in `exhausted` final_status
   remaining, the System SHALL remove the destination's identifier from
   the exhausted-destinations field.

D. When an identifier is removed from the exhausted-destinations field,
   the System SHALL emit a transition value on the **Storage Health**
   stream.

*End* *FIFO Exhaustion Surfaced via Storage Health* | **Hash**: pending
```

#### REQ-d00148: Storage Failure Injection for Testing

```text
# REQ-d00148: Storage Failure Injection for Testing

Level: dev | Status: Draft | Implements: -

## Rationale

The failure modes specified in this document — capacity exhaustion, lock
timeout, store corruption, store unavailability, connection loss — are
hard to provoke in normal test runs. Filling an actual disk in CI is
slow and brittle; killing connections mid-query is platform-dependent;
corrupting a database file is destructive and non-portable. A dedicated
failure-injection seam in the storage backend gives tests a deterministic
way to provoke each **Storage Failure Category** at exact operation
points without any of those problems. Applying the same seam shape on
mobile and server keeps test patterns portable across platforms.

## Assertions

A. The System SHALL provide a `FailureInjector` interface that the
   storage backend consults before each storage operation.

B. The production-default `FailureInjector` SHALL be a no-op that raises
   no exception under any consultation.

C. The test `FailureInjector` SHALL allow tests to enqueue an arbitrary
   **Storage Exception** to be raised on a subsequent storage operation.

D. The test `FailureInjector` SHALL allow tests to scope an enqueued
   failure by **Storage Failure Category**, by storage operation type,
   or by call ordinal.

E. The System SHALL apply the same `FailureInjector` interface to both
   the mobile storage backend and the server storage backend.

*End* *Storage Failure Injection for Testing* | **Hash**: pending
```

## 8. Implementation sequence

The implementation plan (separate document, written next via the writing-plans skill) breaks into the following phases. They are listed here as guidance for the planner, not as a binding sequence.

1. **Glossary first** — add the new defined terms (§5) to the project glossary so all subsequent assertion text has valid bolded references.
2. **Shared abstractions** — REQ-d00135, REQ-d00136, REQ-d00137, REQ-d00138. Pure-Dart on the mobile side, with a server-shareable subset where applicable. No platform code yet.
3. **Mobile classifier and probe** — REQ-d00139, REQ-d00140, REQ-d00141. Uses Sembast and platform channels for free-disk-space.
4. **Wire `EntryService.record`** — REQ-d00142. Refines existing REQ-d00133-E without breaking it.
5. **Mobile health surface** — REQ-d00146-A, REQ-d00146-D. In-app diagnostics view.
6. **FIFO exhaustion surfacing** — REQ-d00147. Wires the existing FIFO `final_status` transitions into the **Storage Health** stream.
7. **Failure injection** — REQ-d00148 (mobile half). Enables testing for all of phases 2–6.
8. **Server classifier and probe** — REQ-d00143, REQ-d00144. Lands when portal ingestion is designed (currently deferred per `project_event_sourcing_refactor_out_of_scope.md` item 1).
9. **Server HTTP mapping and health endpoint** — REQ-d00145, REQ-d00146-B/C/E/F. Lands with portal ingestion.
10. **PRD assertion** — REQ-p01087 is added to `prd-event-sourcing-system.md` and INDEX'd as part of the spec landing, but its full satisfaction depends on the dev REQs above.

Phases 2–7 are mobile-only and can land alongside the rest of CUR-1154. Phases 8–9 wait on the portal ingestion design (currently deferred).

## 9. Open items

- **Glossary file location**: this design assumes a project glossary exists. The cure-hht repo's actual glossary location should be confirmed during the writing-plans phase. The callisto repo has `spec/NFR/glossary-core.md`; the cure-hht repo may organize differently.
- **`{{audit_retention_period}}` default**: REQ-d00138-E leaves the retention period configurable. A reasonable default (90 days?) should be set during implementation; this design takes no position.
- **`{{capacity_warning}}` and `{{capacity_critical}}` defaults for mobile**: REQ-d00140-G commits to package-supplied defaults but does not name them. Reasonable starting values (warning at 500 MB, critical at 100 MB?) should be chosen during implementation.
- **Existing PRD term audit**: the wording memory specifies that "patient" is being phased out in favor of **User** / **Participant**. REQ-p00006 currently uses "patients" — this design does not propose retroactive changes to existing REQs, but a separate cleanup pass may be warranted.
- **`StorageBackend` interface refactor**: implementing REQ-d00148-A requires inserting the `FailureInjector` consultation point into the existing `StorageBackend` operations defined in REQ-d00117. This is a small refactor that may have implications for already-landed Phase 4.3 code; the writing-plans phase should size it.

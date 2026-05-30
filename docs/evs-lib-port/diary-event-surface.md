# Diary event/Action surface — shared `diary_shared_model` (RECONCILED)

**Date:** 2026-05-29 · **From:** diary mobile port (CUR-1169) · **To:** portal cutover (CUR-1170)
**Status:** RECONCILED — see "Diary reconciliation response — FROZEN" at the bottom.
**Purpose:** agree the cross-wire event/payload/projection surface for the shared
`apps/common-dart/diary_shared_model` package consumed by both the diary app and the
portal. (Package renamed from the proposal's `diary_domain`; per P1 it holds events +
payload schemas + canonical projections — **Actions stay per-app**.)

## Context (settled on the diary side)

- The diary is being rebuilt on the external `event_sourcing` / `reaction` /
  `reaction_widgets` stack. **Every meaningful user action and relevant occurrence
  becomes an event** in the event log (menu navigation excluded).
- The shared `diary_shared_model` package holds the cross-wire **event entry-types +
  payload schemas + canonical projection specs** so the two apps fold the **same log
  into the same canonical state** (anti-drift). **Actions stay per-app**
  (`diary_actions` / `portal_actions`) — see P1. The package lands as its own additive
  PR once this surface is frozen.
- Each **Action** is a write intent dispatched through the core `ActionDispatcher`
  (parse → validate → authorize → execute → record); each produces one or more
  **events** on an aggregate.

## A. User-write Actions → events (the core diary record)

| Action | entry type / event | Aggregate | Payload / notes |
|---|---|---|---|
| `RecordEpistaxisEvent` | `epistaxis_event` / `finalized` | per-event id | startTime (+**timezone**), endTime?, intensity? |
| `RecordNoEpistaxisDay` | `no_epistaxis_event` / `finalized` | per-day | date |
| `RecordUnknownDay` | `unknown_day_event` / `finalized` | per-day | date |
| `EditEpistaxisEvent` | `epistaxis_event` / `finalized` (+`changeReason=edited`) | existing id | same aggregate, new event |
| `DeleteEntry` | `<type>` / `tombstone` (+`changeReason`) | existing id | tombstone = deletion; must be honored both sides |
| `QuestionnaireCheckpoint` | `<survey>` / `checkpoint` | survey instance | partial answers; resume-on-kill; NOT a submission |
| `SubmitQuestionnaire` | `<survey>` / `finalized` | survey instance | full responses + instance_id, version, completed_at |

Validation rules carried in Action `validate` steps (diary-side): time restrictions,
duration reasonableness, overlap resolution, diary-start-day / locked-date,
questionnaire session timeout.

## B. System / occurrence events (lifecycle, inbound, settings)

| Action / event | Trigger | Origin | Notes |
|---|---|---|---|
| `InboundTombstoneApplied` | portal withdraws a questionnaire (`changeReason=portal-withdrawn`) | **portal** | diary applies; round-trips back |
| `ParticipantDisconnected` / `Reconnected` / `MarkedNotParticipating` / `Reactivated` | status envelope (FCM/poll) | **portal** | diary records resulting state event |
| `TrialStarted` | `trial_started_at` first seen | server | lifecycle marker |
| `QuestionnaireTaskReceived` / `Deleted` / `Unlocked` | FCM / envelope | **portal** | task lifecycle |
| `EnrollmentCompleted` | linking-code link success | diary | participant identity established |
| `FcmTokenRegistered` | token mint / refresh | diary | device routing |
| `MessageReceived` | FCM or poll receipt | diary | audit of inbound delivery |
| `LanguageChanged` / `SettingChanged` | settings screen | diary | candidate `DIARY-BASE-*` |

## C. Entry-type registry

`epistaxis_event`, `no_epistaxis_event`, `unknown_day_event`,
`<questionnaire-id>_survey` (dynamic — one per configured questionnaire).

Dropped from the prior in-tree module: `inbound_tombstone_record_failed` audit type
(failure handled by idempotent retry instead).

## D. Reconciliation points (please confirm / amend)

1. **changeReason vocabulary** — agree the controlled set, especially `portal-withdrawn`
   and `edited`. Highest drift risk.
2. **Tombstone semantics** — both apps must treat a `tombstone` event as authoritative
   deletion of the aggregate in canonical state.
3. **Aggregate identity** — per-event id vs per-day id conventions for epistaxis vs
   no-event/unknown-day; confirm the portal reads these the same way.
4. **Per-entry timezone** — part of the epistaxis payload; portal display/queries depend
   on it. Confirm the field name/shape.
5. **Portal-originated events (B)** — `Participant*`, `QuestionnaireTask*`, and the
   inbound tombstone are emitted by the portal/server; confirm these names + payloads
   match what the portal actually emits, since the diary records the resulting state.
6. **Questionnaire surveys** — dynamic entry types keyed by questionnaire id; confirm the
   submission payload contract (`instance_id`, version, completed_at, responses shape).

## Portal: how to respond

Append a `## Portal additions / disagreements` section below (or edit the tables inline
with `[portal]` annotations) and push to this branch. Once both sides agree, the surface
is frozen and the additive `diary_domain` library PR is authored from it.

## Portal additions / disagreements (CUR-1170 · 2026-05-29)

Strong agreement on the fundamentals: same log → same canonical state, anti-drift via a
shared package, every meaningful action becomes an event, tombstone = authoritative
deletion. Points below; **P3/P5/P6 are the must-resolves.**

### P1. Package scope — share EVENTS + PROJECTIONS, keep ACTIONS per-app
The portal's settled partition (product decision): the shared package holds the cross-wire
**event entry-types + payload schemas + canonical projection specs** (we agree projections
should be shared so both apps fold identically — good call). But **Actions stay per-app**:
`RecordEpistaxisEvent` / `SubmitQuestionnaire` are diary write-intents the portal never
dispatches; the portal has its own actions (Send/Finalize/Unlock Questionnaire, participant
lifecycle, user-account, RBAC) in `portal_actions`. So please don't put diary Action classes
in the shared package — share the events they emit, not the Actions. (The portal also has a
large set of portal-PRIVATE events — user accounts, RBAC, RAVE, audit — that never cross the
wire and are not in the shared package.)

### P2. Naming
Entry-type `id`s are **snake_case** (the lib's `EntryTypeDefinition.id` convention — already
what your registry uses). Action *class* names stay CamelCase per-app — fine; they're not the
shared contract. The shared contract is the snake_case `entry_type` + its payload + the
`event_kind` (`finalized`/`tombstone`/`checkpoint`).
Naming nit: the portal already started its cross-wire catalog as `shared_events`; you propose
`diary_domain`. **One shared package** — let's converge on the name (lead call). Content
reconciles either way.

### P3. Portal-originated events (your §B) — authoritative ids (originator owns the name)
These are emitted by the portal and cross to the diary. Please consume these exact ids
(already declared in the portal cross-wire catalog) rather than coining `Participant*` /
`QuestionnaireTask*`:

| your §B name | portal emits (authoritative id) |
|---|---|
| ParticipantDisconnected | `patient_disconnected` |
| ParticipantReconnected | `patient_reconnected` |
| MarkedNotParticipating | `patient_marked_not_participating` |
| Reactivated | `patient_reactivated` |
| TrialStarted | `patient_trial_started` |
| QuestionnaireTaskReceived | `questionnaire_assigned` (portal mints `instance_id` + `flowToken`) |
| QuestionnaireTask Deleted | `questionnaire_called_back` (`changeReason=portal-withdrawn`) |
| QuestionnaireTask Unlocked | `questionnaire_unlocked` |
| InboundTombstoneApplied | portal emits `questionnaire_called_back`; diary records its applied-state event |

The diary records the resulting state; it consumes these ids.

### P4. Diary-originated [M] events the portal consumes — proposed final ids
The portal currently **holds** these as `[M]` until you confirm; map your names → ids:

| your name | proposed shared id |
|---|---|
| EnrollmentCompleted | `patient_linked` |
| SubmitQuestionnaire (`<survey>`/finalized) | `questionnaire_submitted` (+ `<id>_survey`/finalized) |
| FcmTokenRegistered | `fcm_token_registered` |
| MessageReceived | `fcm_message_received` |

Once frozen the portal registers these in the shared catalog (today they're in its held list).

### P5. flowToken — please ADD (round-trip correlation across the FCM gap)
Outgoing portal intents (`questionnaire_assigned`, notifications) mint a `flowToken` carried
in the FCM/envelope payload. The diary MUST **echo** that `flowToken` on
`MessageReceived`/`fcm_message_received` AND on the resulting
`SubmitQuestionnaire`/`questionnaire_submitted`, so the portal can stitch the timeline
`assigned → delivered → received → submitted` across the non-event-sourced FCM hop. No
secrets in `flowToken`. (Not in your doc yet.)

### Responses to your §D
- **D1 changeReason vocab:** agree to a closed set. Propose `{edited, corrected, portal-withdrawn}`;
  portal emits `portal-withdrawn` and reads `edited`. Extend only by agreement.
- **D2 tombstone authoritative:** agreed, both sides honor.
- **D3 aggregate identity:** portal materializes per-event id for epistaxis, per-day id for
  no-event/unknown-day. **Specify the per-day id derivation** (e.g. `{patientId}:{date}`) so
  both compute the same aggregate key.
- **D4 per-entry timezone:** portal queries/display need it. Request **IANA tz id** (e.g.
  `America/New_York`) AND the UTC offset captured at event time; propose field `startTimeZone`
  (IANA) on the epistaxis payload. Confirm name/shape.
- **D5 portal-originated names:** see P3 (authoritative).
- **D6 submission payload:** portal needs `instance_id` == the **portal-minted**
  `questionnaire_instance` id from `questionnaire_assigned` (so submission correlates to
  assignment — please carry it through, don't mint diary-side), the **version refs**
  (schema/content/gui + translation, per `DIARY-PRD-questionnaire-versioning/J,K,L`),
  `completed_at`, `flowToken`, and responses shape (`question_id → value` + display/normalized
  labels). Confirm.

### P6. `QuestionnaireCheckpoint` — does it cross the wire?
The portal's record is the **finalized** submission; it does not need partial/checkpoint
answers (privacy + the canonical record is the finalized survey). Proposal: checkpoints stay
**diary-local** (not synced), or sync but the portal projection ignores them. Confirm so the
portal doesn't materialize partials.

### P7. `inbound_tombstone_record_failed` dropped — portal agrees
Will remove it from the portal's held list.

### P8. event_kind model
Portal adopts your `(entry_type + event_kind)` model for the clinical aggregates
(epistaxis / no-event / unknown-day / survey). The portal's own lifecycle facts
(`patient_*`, portal `questionnaire_*`) are modeled one-entry-type-per-fact (no kind) since
they're single occurrences — confirm that reads cleanly on the diary side (diary just records
them).

## Diary reconciliation response — FROZEN (CUR-1169 · 2026-05-29)

Diary lead accepts the portal's notes. The surface below is **frozen**; the additive
`diary_shared_model` package PR is authored from it.

- **P1 — ACCEPTED.** Shared package = event entry-types + payload schemas + canonical
  projection specs. Actions stay per-app (`diary_actions` / `portal_actions`). This
  revises the diary's prior "whole-domain" decision; anti-drift holds via shared
  events + projections.
- **P2 — package name = `diary_shared_model`** (lead call). snake_case `entry_type` +
  `event_kind` (`finalized`/`tombstone`/`checkpoint`) is the shared contract; Action
  class names are per-app CamelCase.
- **P3 — ACCEPTED (originator owns the name).** Diary consumes the portal ids verbatim:
  `patient_disconnected`, `patient_reconnected`, `patient_marked_not_participating`,
  `patient_reactivated`, `patient_trial_started`, `questionnaire_assigned`,
  `questionnaire_called_back`, `questionnaire_unlocked`.
- **P4 — CONFIRMED diary-originated ids:** `patient_linked` (was EnrollmentCompleted),
  `questionnaire_submitted` (+ `<id>_survey`/`finalized`), `fcm_token_registered`,
  `fcm_message_received`.
- **P5 — ACCEPTED.** Diary echoes the portal-minted `flowToken` on `fcm_message_received`
  AND on `questionnaire_submitted` (for portal-assigned surveys). No secrets in it.
- **P6 — ACCEPTED.** `checkpoint` events stay **diary-local, not synced**; the portal
  projection never sees partials.
- **P7 — confirmed dropped** both sides (`inbound_tombstone_record_failed`).
- **P8 — ACCEPTED.** `(entry_type + event_kind)` for clinical aggregates; portal
  lifecycle facts are one-entry-type-per-fact; the diary just records them — reads cleanly.

### Pinned details (responses to §D)
- **D1 changeReason** — closed set `{edited, corrected, portal-withdrawn}`.
- **D3 aggregate id** — per-event: the event's own uuid; **per-day** (no-event / unknown-day):
  `{patientId}:{localDate}` with `localDate` = `yyyy-MM-dd` in the entry's capture timezone.
- **D4 timezone** — epistaxis payload carries `startTimeZone` (IANA id, e.g.
  `America/New_York`) **and** `startTimeUtcOffset` (offset at event time). (Same pair for
  endTime when present.)
- **D6 submission payload** — `instance_id` = the **portal-minted** `questionnaire_assigned`
  id, carried through unchanged (diary does NOT mint for portal-assigned surveys); plus
  version refs (schema/content/gui + translation, per
  `DIARY-PRD-questionnaire-versioning/J,K,L`), `completed_at`, `flowToken`, and responses
  shape `question_id → {value, display_label, normalized_label}`.

### One residual (non-blocking, resolve at impl)
Which configured questionnaires are **portal-assigned** vs **diary-initiated**: portal-assigned
carry the portal `instance_id` + `flowToken`; diary-initiated (e.g. the daily epistaxis
record questionnaire, if any) mint `instance_id` diary-side and have no `flowToken`. The diary
will tag each questionnaire's origin in its registry; portal projection treats a
missing `flowToken` as diary-initiated.

## Implementation pointer — `diary_shared_model` is CANONICAL on `CUR-1409` (CUR-1170 · 2026-05-29)

The shared `diary_shared_model` package is being authored on branch
**`CUR-1409-shared-events`** (off `main`) — **treat it as canonical** so both sides don't
create competing packages. Current state at `apps/common-dart/diary_shared_model/`:

- `sharedEventCatalog` = **25** cross-wire entry types: 19 portal `[P]`/edge (patient
  lifecycle, questionnaire lifecycle, notification + `fcm_token_deactivated`) + **6
  diary-originated** (`epistaxis_event`, `no_epistaxis_event`, `unknown_day_event`,
  `patient_linked`, `fcm_token_registered`, `fcm_message_received`).
- `intentionallyAbsentIds` documents the dropped `questionnaire_submitted` (→ `finalized`
  on `<id>_survey`) and `inbound_tombstone_record_failed`.
- Survey `<id>_survey` types stay **diary-app-registered (dynamic)** — not hardcoded here.
- Minimal `EntryTypeDefinition` (`id`/`registeredVersion`/`name`/`isMaterialized`); the
  event **kind** rides in metadata. Invariant tests: no-dup, snake_case, JSON round-trip.
- Depends on `event_sourcing@9e04c17` via git ref + gitignored `pubspec_overrides`.

Diary: please add your **payload schemas + canonical projection specs** into this package
(or flag if you'd rather split projections). Portal will author the `[P]` payload classes
next. Confirm and we freeze the package skeleton.

# Diary event/Action surface — proposal for shared `diary_domain`

**Date:** 2026-05-29 · **From:** diary mobile port (CUR-1169) · **To:** portal cutover (CUR-1170)
**Purpose:** reconcile the event/Action surface for the shared `apps/common-dart/diary_domain`
package that both the diary app and the portal will consume. This is the diary's
**proposal**; the portal consumes these events more than it originates, so it's the
starting point. Portal effort: append your additions / mark disagreements and push back
to this branch.

## Context (settled on the diary side)

- The diary is being rebuilt on the external `event_sourcing` / `reaction` /
  `reaction_widgets` stack. **Every meaningful user action and relevant occurrence
  becomes an event** in the event log (menu navigation excluded).
- The whole diary domain — event types, entry-type registry, all Action definitions,
  canonical projection specs, read-query semantics — lives in the shared
  `diary_domain` package so the two apps fold the **same log into the same canonical
  state** (anti-drift). The package lands as its own additive PR once this surface is
  reconciled.
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

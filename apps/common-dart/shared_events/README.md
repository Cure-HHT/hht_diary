# shared_events

Single source of truth for **cross-wire** event entry-type ids that travel between
the mobile diary, diary-server, and portal-server (`[home: shared]` in the Phase 0
catalog). Nothing references this package in production yet — it is the cross-post
artifact for aligning the event id contract with the mobile rebuild (CUR-1371).

## What is here (Plan 1)

The exhaustive **portal-originated (`[P]`) + edge** entry types, as
`EntryTypeDefinition`s grouped in `sharedEventCatalog`:

- patient lifecycle (9), questionnaire lifecycle (7), notification + fcm_token (3).

Each is the substrate's minimal `EntryTypeDefinition` (`id` / `registeredVersion` /
`name` / `isMaterialized`). Typed payload-schema classes and rendering/projection
metadata are **not** here — payload classes are a follow-on plan; rendering is app-side.

## Held for the mobile cross-post

Mobile-authored (`[M]`) ids are listed in `heldMobileAuthoredIds` and are NOT
registered until the schema is agreed with mobile: `patient_linked`,
`questionnaire_submitted`, `fcm_message_received`, `fcm_token_registered`, and the
clinical ePRO entries (`epistaxis_event`, `no_epistaxis_event`, `unknown_day_event`,
the `{eq|nose_hht|hht_qol}_survey` types, `inbound_tombstone_record_failed`).

## Local development

`pubspec_overrides.yaml` (gitignored) points `event_sourcing` at a sibling clone at
`../../../../../event_sourcing/event_sourcing`. The committed `pubspec.yaml` pins the
git ref (`9e04c17`).

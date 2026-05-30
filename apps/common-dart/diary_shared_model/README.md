# diary_shared_model

Single source of truth for the **cross-wire** event surface shared between the mobile
diary, diary-server, and portal-server: entry-type ids (+ payload schemas and canonical
projections, added incrementally). The event/payload surface was **frozen with the diary
team on 2026-05-29** (`docs/evs-lib-port/diary-event-surface.md`). **Actions stay per-app**
(`diary_actions` / `portal_actions`); only the shared events/projections live here.

## Catalog (`sharedEventCatalog`)

- Portal-originated (`[P]`) + edge: patient lifecycle (9), questionnaire lifecycle (7),
  notification + fcm_token (3).
- Diary-originated (`mobile`): clinical `epistaxis_event` / `no_epistaxis_event` /
  `unknown_day_event`, plus `patient_linked`, `fcm_token_registered`, `fcm_message_received`.

Each is the substrate's minimal `EntryTypeDefinition` (`id` / `registeredVersion` / `name` /
`isMaterialized`). The event **kind** (`finalized` / `tombstone` / `checkpoint`) rides in
event metadata, not the id. Survey entry types (`<id>_survey`, e.g. `eq` / `nose_hht` /
`hht_qol`) are registered **dynamically by the diary app** from its `questionnaires.json`
asset and are not hardcoded here. Typed payload-schema classes and projection specs are
follow-on work.

## Intentionally absent (`intentionallyAbsentIds`)

- `questionnaire_submitted` — realized as a `finalized`-kind event on a `<id>_survey` type.
- `inbound_tombstone_record_failed` — dropped both sides (idempotent retry).

## Local development

`pubspec_overrides.yaml` (gitignored) points `event_sourcing` at a sibling clone at
`../../../../../event_sourcing/event_sourcing`. The committed `pubspec.yaml` pins the git
ref (`9e04c17`).

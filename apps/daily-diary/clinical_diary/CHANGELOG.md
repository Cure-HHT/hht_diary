# Changelog

## [0.9.18+38] - 2026-04-27

### Changed

- **Patient writes flow through `event_sourcing_datastore`.** Nosebleed entries, "no nosebleeds" markers, "unknown day" markers, and questionnaire submissions all write through `EntryService.record(...)` to the local event log first, materialize to the `diary_entries` view, and drain to the diary server through a per-destination FIFO. Network failures no longer lose data; app suspension no longer loses partial work.
- **Questionnaires now persist locally before submission.** NOSE-HHT and Quality-of-Life questionnaires inherit the same hash-chained provenance and offline-queue behavior as nosebleed events. Withdrawn-by-server questionnaires materialize as tombstoned entries via the portal inbound poll instead of surfacing a submit-time error dialog.
- **Sync triggers run foreground-only.** Lifecycle resume, periodic timer (15 min default), connectivity restored, FCM `onMessage`, and FCM `onMessageOpenedApp` all invoke `syncCycle()` while the app is in the foreground. No background isolate.

### Added

- `bootstrapClinicalDiary` — single entry point composing `SembastBackend`, the event-sourcing runtime, the diary view reader, the sync cycle, and triggers.
- `DiaryExportService` — full event-log audit trail export as JSON (`hht-diary-export-YYYY-MM-DD-HHMMSS.json`).
- FIFO-wedge banner on the home screen — visible state when any destination is permanently rejected.
- Modal-on-resume routing scaffold for incomplete surveys (forward-looking; the FCM-prompt handler that creates incomplete-survey aggregates lands in a follow-up).

### Removed

- `NosebleedService`, `QuestionnaireService`, `NosebleedRecord` model. The legacy bespoke append-only datastore (`append_only_datastore` package dependency) is no longer used by `clinical_diary`.
- `data_export_service.dart` legacy importer. Re-import of legacy export files is not supported; new exports use the event-log shape.

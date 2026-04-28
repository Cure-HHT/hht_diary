// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00006: Offline-First Data Entry

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

/// Minimal write-API surface that entry widgets need from the datastore.
///
/// The typedef matches the signature of `EntryService.record`. Production code
/// wires a thin closure over a real `EntryService`. Test code supplies a fake
/// that records calls without any I/O. Keeping this as a function type
/// decouples entry widgets from `EntryService`'s constructor dependencies
/// (backend, registry, etc.).
// Implements: REQ-d00004-E — local-first write path invoked by widgets.
// Implements: REQ-d00004-F — single write path through EntryService adapter.
typedef EntryRecorder =
    Future<StoredEvent?> Function({
      required String entryType,
      required String aggregateId,
      required String eventType,
      required Map<String, Object?> answers,
      String? checkpointReason,
      String? changeReason,
    });

/// Binds a real `EntryService` into an [EntryRecorder] closure.
EntryRecorder entryRecorderFromService(EntryService service) =>
    ({
      required entryType,
      required aggregateId,
      required eventType,
      required answers,
      checkpointReason,
      changeReason,
    }) => service.record(
      entryType: entryType,
      aggregateId: aggregateId,
      eventType: eventType,
      answers: answers,
      checkpointReason: checkpointReason,
      changeReason: changeReason,
    );

/// Shared context passed to every entry widget.
///
/// [entryType] — the entry-type identifier registered in the entry-type
///   registry.
/// [aggregateId] — the aggregate this widget reads/writes events for.
/// [widgetConfig] — sponsor/study configuration for the widget, including the
///   optional `'variant'` key that gates variant-specific UX.
/// [initialAnswers] — non-null when opening an existing entry for editing;
///   for survey entries, this is the cumulative answer map from the latest
///   checkpoint (the `cycle` key is included and treated as immutable seed
///   metadata by `SurveyRendererWidget`).
/// [recorder] — the [EntryRecorder] function the widget uses for all writes.
///   Bind a real `EntryService` via `entryRecorderFromService`; supply a fake
///   closure in tests.
/// [isFinalized] — true when the aggregate's latest event is `finalized`.
///   Widgets should render read-only and hide submit actions.
/// [isWithdrawn] — true when the aggregate has been tombstoned / deleted.
///   Widgets should render read-only with a "withdrawn" banner and no submit.
// Implements: REQ-d00004-F — single write path through EntryService adapter.
class EntryWidgetContext {
  const EntryWidgetContext({
    required this.entryType,
    required this.aggregateId,
    required this.widgetConfig,
    required this.recorder,
    this.initialAnswers,
    this.isFinalized = false,
    this.isWithdrawn = false,
  });

  final String entryType;
  final String aggregateId;
  final Map<String, Object?> widgetConfig;
  final Map<String, Object?>? initialAnswers;
  final EntryRecorder recorder;

  /// True when the aggregate has already been finalized (is_complete = true in
  /// the view). The launching surface (home screen / Task 12) populates this
  /// from the view row so widgets can render read-only without re-reading
  /// events themselves.
  // Implements: REQ-d00004-E — local-first read path surfaces completion state.
  final bool isFinalized;

  /// True when the aggregate has been tombstoned (is_deleted = true in the
  /// view). The launching surface populates this from the view row.
  // Implements: REQ-d00004-E — local-first read path surfaces deletion state.
  final bool isWithdrawn;
}

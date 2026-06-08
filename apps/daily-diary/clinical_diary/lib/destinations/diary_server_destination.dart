// End-state NATIVE outbound destination for the diary clinical entries.
//
// Unlike the transitional `LegacySyncDestination` (which hand-translates
// canonical events into the legacy `/api/v1/user/sync` wire shape), this
// destination ships the library's CANONICAL `esd/batch@1` `BatchEnvelope`
// bytes verbatim to a diary-server event-sourcing ingest. Because both nodes
// run on `event_sourcing`, there is no wire translation: `serializesNatively`
// is `true`, the library's drain reconstructs the canonical envelope, and
// [send] only POSTs the bytes.
//
// The server-side native ingest handler (`EventStore.ingestBatch`) is the
// diary-server rebuild's responsibility; this client meets it at the canonical
// `esd/batch@1` contract.
//
// The common send()/wireFormat/serializesNatively/HTTP-classification logic
// lives in `CanonicalIngestDestination` (shared with `SystemEventsDestination`,
// which POSTs to the SAME ingest endpoint). This subclass supplies only its
// FIFO `id` and `filter`.

import 'package:clinical_diary/destinations/canonical_ingest_destination.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Outbound [Destination] that ships finalized + tombstone `DiaryEntry`
/// events to the diary server as canonical `esd/batch@1` batches.
///
/// See [CanonicalIngestDestination] for the HTTP response classification
/// (shared with the system-events destination).
class DiaryServerDestination extends CanonicalIngestDestination {
  // Implements: DIARY-DEV-native-outbound-sync/A — single native destination
  //   selecting finalized + tombstone DiaryEntry events (checkpoints stay
  //   local) and shipping them as canonical esd/batch@1 batches.
  DiaryServerDestination({
    required super.client,
    required super.resolveIngestUrl,
    required super.authToken,
  });

  /// Stable FIFO key for the primary diary server. SHALL NOT change for the
  /// lifetime of the store.
  static const String destinationId = 'primary';

  @override
  String get id => destinationId;

  /// Selects finalized + tombstone diary-entry events; excludes `checkpoint`
  /// (drafts stay diary-local) and every non-`DiaryEntry` aggregate. Survey
  /// (`<id>_survey`) events are also `DiaryEntry`, so they sync through this
  /// same destination automatically once they migrate to the new store.
  @override
  SubscriptionFilter get filter => const SubscriptionFilter(
    aggregateTypes: {diaryEntryAggregateType},
    eventTypes: {'finalized', 'tombstone'},
  );
}

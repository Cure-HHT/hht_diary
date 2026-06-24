// End-state NATIVE outbound destination for the device's SYSTEM events
// (link / sync / lifecycle management / FCM token registration + inbound
// message receipts).
//
// This is the second of the two device->portal outbound destinations. The
// first, `DiaryServerDestination`, ships the clinical diary entries
// (`DiaryEntry` aggregate). This one ships the system aggregates and POSTs to
// the SAME diary-server / portal `/ingest` endpoint as `DiaryServerDestination`
// — same `client`, same `resolveIngestUrl`, same `authToken`, same canonical
// `esd/batch@1` wire shape (it extends `CanonicalIngestDestination`, which
// holds the shared send()/classify logic).
//
// Scope: today this filter selects the FCM aggregates (`FcmToken` token
// registration, `InboundMessage` receipts) so push routing tokens reach the
// portal token projection. As other system flows (link / sync / lifecycle)
// migrate to native ingest, their aggregate types JOIN this destination's
// filter — there is no need for a third outbound queue.

import 'package:clinical_diary/destinations/canonical_ingest_destination.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Outbound [Destination] that ships finalized + tombstone system events
/// (currently the FCM `FcmToken` + `InboundMessage` aggregates) to the same
/// diary-server / portal `/ingest` as the diary-server destination, as
/// canonical `esd/batch@1` batches.
///
/// See [CanonicalIngestDestination] for the HTTP response classification.
class SystemEventsDestination extends CanonicalIngestDestination {
  // Implements: DIARY-DEV-native-outbound-sync/A — a second native destination
  //   selecting the device's system aggregates (FCM token + inbound receipt)
  //   and shipping them as canonical esd/batch@1 batches to the same ingest.
  SystemEventsDestination({
    required super.client,
    required super.resolveIngestUrl,
    required super.authToken,
  });

  /// Stable FIFO key for the system-events outbound queue. SHALL NOT change for
  /// the lifetime of the store.
  static const String destinationId = 'system';

  @override
  String get id => destinationId;

  /// Selects finalized + tombstone events on the system aggregates. Today that
  /// is the FCM aggregates (`FcmToken` token registration/refresh,
  /// `InboundMessage` push receipts) and the recall-notice aggregate
  /// (`questionnaire_recall_notice` ack events); additional system aggregate
  /// types (link / sync / lifecycle) JOIN this set as those flows migrate to
  /// native ingest.
  ///
  /// Device actions emit `eventType: 'finalized'` (the semantic name lives in
  /// `entryType`, e.g. `fcm_token_registered`, `questionnaire_recall_acked`),
  /// so the event-type gate selects `finalized` + `tombstone`, matching the
  /// portal projections' axis.
  @override
  SubscriptionFilter get filter => const SubscriptionFilter(
    aggregateTypes: {
      'FcmToken',
      'InboundMessage',
      'questionnaire_recall_notice',
    },
    eventTypes: {'finalized', 'tombstone'},
  );

  /// Drain ASAP: a lone system event (FCM token registration/refresh, a push
  /// receipt) is NEVER held — it ships on the next sync trigger immediately (the
  /// post-append drain fires after every append). Push routing tokens must reach
  /// the portal projection the moment the device links, and receipts must
  /// round-trip promptly for flowToken correlation. Explicit (not merely
  /// inherited) so the contrast with `DiaryServerDestination`'s batching window
  /// (`kDiaryBatchWindow`) is intentional.
  // Implements: DIARY-DEV-native-outbound-sync/A
  @override
  Duration get maxAccumulateTime => Duration.zero;
}

import 'package:append_only_datastore/src/destinations/subscription_filter.dart';
import 'package:append_only_datastore/src/destinations/wire_payload.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';

/// One synchronization target — the primary diary server, a future
/// analytics backend, etc. — that owns its own FIFO, transform, and send.
///
/// A `Destination` has four responsibilities:
///
/// 1. Declaring *what* it wants via [filter]: a deterministic predicate over
///    `(entry_type, event_type, optional predicate)` that selects which
///    events are enqueued to this destination's FIFO.
/// 2. Declaring *how batches are assembled* via [canAddToBatch] and
///    [maxAccumulateTime]: per-candidate admission plus a hold on
///    single-event batches so destinations that prefer to ship batches of
///    two or more are not prematurely flushed when only one event is
///    available.
/// 3. Declaring *how its bytes look on the wire* via [wireFormat] and
///    [transform]: a pure-function serialization from an in-memory event
///    batch to a single [WirePayload] (bytes + contentType + transformVersion)
///    covering the whole batch.
/// 4. Handing the bytes off via [send], returning a [SendResult] that the
///    drain loop routes to success / retry / exhaust outcomes.
///
/// Destinations are registered at app boot in `DestinationRegistry` and are
/// immutable for the process lifetime. A destination's [id] is the key of
/// its FIFO Sembast store (`fifo_{id}`) and SHALL be stable: changing it
/// later would orphan the store's contents. The typical id is a short
/// slug, e.g. `"primary"` for the primary diary server.
// Implements: REQ-d00122-A+B+C+D+E — Destination contract surface.
// Implements: REQ-d00128-D+E+F — batch transform, canAddToBatch,
// maxAccumulateTime.
// Implements: REQ-d00129-B — allowHardDelete defaults to false in the
// abstract contract; concrete destinations opt in explicitly.
abstract class Destination {
  const Destination();

  /// Stable identifier — used as the FIFO store suffix (`fifo_{id}`) and as
  /// the key in `DestinationRegistry`. SHALL be unique across the registry
  /// and SHALL NOT change for the lifetime of the store.
  // Implements: REQ-d00122-A — stable id is the FIFO store identifier.
  String get id;

  /// Event-selection predicate. An event is enqueued to this destination
  /// iff `filter.matches(event)` returns `true`.
  // Implements: REQ-d00122-B — filter deterministically selects events.
  SubscriptionFilter get filter;

  /// Opaque wire-format identifier such as `"json-v1"` or `"fhir-r4"`.
  /// Every `FifoEntry` enqueued for this destination SHALL carry this
  /// value in its `wire_format` column.
  // Implements: REQ-d00122-C — wire_format string is declared.
  String get wireFormat;

  /// Upper bound on how long `fillBatch` may hold a single-event batch
  /// before flushing it. A single-event batch SHALL NOT flush until
  /// `now() - batch.first.client_timestamp >= maxAccumulateTime` OR
  /// [canAddToBatch] has already returned `false` for a subsequent
  /// candidate. Destinations that are happy with single-event batches
  /// SHALL return `Duration.zero`.
  // Implements: REQ-d00128-F — maxAccumulateTime hold on single-event
  // batches is honored by fillBatch.
  Duration get maxAccumulateTime;

  /// Whether this destination permits hard deletion of its FIFO store via
  /// `DestinationRegistry.deleteDestination`. The abstract default is
  /// `false` because some destinations carry regulatory audit weight and
  /// must not be purged in one call; concrete destinations that permit
  /// hard deletion SHALL override the getter to `true` as an explicit
  /// opt-in.
  // Implements: REQ-d00129-B — abstract default false; opt-in via override.
  bool get allowHardDelete => false;

  /// Destination-owned batching rule. Invoked by `fillBatch` once per
  /// candidate event under consideration: returning `true` adds
  /// [candidate] to [currentBatch]; returning `false` ends the current
  /// batch (the candidate remains available for the next batch / tick).
  /// The predicate SHALL be deterministic and pure — identical inputs
  /// SHALL produce identical outputs across invocations.
  // Implements: REQ-d00128-E — canAddToBatch is the destination-owned
  // batch admission predicate.
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate);

  /// Pure transform from an event [batch] to its wire payload. Produces
  /// exactly one [WirePayload] covering every event in the batch.
  /// Implementations SHALL be deterministic: identical input batches
  /// SHALL produce byte-identical [WirePayload]s, so the
  /// `transform_version` stamp uniquely identifies the transform that
  /// produced the bytes.
  ///
  /// The batch SHALL be non-empty — callers (drain / fillBatch) SHALL
  /// NOT invoke `transform` with an empty list, and implementations MAY
  /// throw [ArgumentError] on that precondition violation.
  ///
  /// The method is `async` because real destinations may do per-batch
  /// async work (e.g., signing, key-store lookup); pure-Dart test doubles
  /// return `Future.value(...)`.
  ///
  /// The returned payload is typically handed directly to `send(...)` on
  /// the drain path; the same bytes are also persisted on the
  /// [`FifoEntry.wirePayload`] for later retry attempts.
  // Implements: REQ-d00122-D — transform produces (bytes, content_type,
  // transform_version); transform_version is preserved on the FifoEntry.
  // Implements: REQ-d00128-D — transform takes a batch and produces one
  // WirePayload covering every event in the batch; empty batch is invalid.
  Future<WirePayload> transform(List<StoredEvent> batch);

  /// Hand [payload] to the destination and categorize the outcome.
  ///
  /// Implementations SHALL return one of:
  ///
  /// - [SendOk] — the payload was accepted; drain loop marks the entry sent.
  /// - [SendTransient] — retryable failure (typically 5xx, timeouts, network
  ///   errors); drain loop applies backoff per `SyncPolicy`.
  /// - [SendPermanent] — non-retryable failure (typically 4xx excluding
  ///   rate-limits); drain loop marks the entry exhausted and wedges the
  ///   FIFO per REQ-d00119-D.
  ///
  /// How underlying HTTP codes, network errors, and timeouts map into those
  /// three variants is a per-destination judgment, not dictated by the
  /// contract.
  // Implements: REQ-d00122-E — send returns a three-variant SendResult;
  // categorization is per-destination policy.
  Future<SendResult> send(WirePayload payload);
}

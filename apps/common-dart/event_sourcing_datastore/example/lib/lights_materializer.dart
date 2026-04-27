import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

/// Maintains an `rgb_lights` materialized view that toggles three lights
/// (red, green, blue) on/off in response to button-press events. Each
/// press flips the corresponding light's `is_on` state and stamps
/// `last_toggled_at`.
///
/// Used by the example's `LightsPanel` to demonstrate `watchView` —
/// rendering changes are driven by the materializer's view writes,
/// without any panel-side polling or event-stream filtering. The
/// `aggregateType == 'RgbLight'` check guards against unrelated events
/// (DiaryEntry materializations, etc.) routing through this fold.
///
/// View row shape (one per color, keyed by color name):
///
/// ```dart
/// {'color': 'red', 'is_on': true, 'last_toggled_at': '2026-04-25T...'}
/// ```
// Implements: REQ-d00140-A — concrete materializer maintaining one view.
// Implements: REQ-d00140-G — promoter required and supplied by caller.
class LightsMaterializer extends Materializer {
  const LightsMaterializer({required this.promoter});

  static const String viewKey = 'rgb_lights';

  /// Map from this materializer's three event types to the color they
  /// toggle. Defines the universe of events that fall into this fold;
  /// the existing button-press destinations route the same event types
  /// downstream too.
  static const Map<String, String> _entryTypeToColor = <String, String>{
    'red_button_pressed': 'red',
    'green_button_pressed': 'green',
    'blue_button_pressed': 'blue',
  };

  @override
  final EntryPromoter promoter;

  @override
  String get viewName => viewKey;

  @override
  bool appliesTo(StoredEvent event) =>
      _entryTypeToColor.containsKey(event.entryType);

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required Map<String, Object?> promotedData,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  }) async {
    final color = _entryTypeToColor[event.entryType];
    if (color == null) return; // appliesTo gates this; defense-in-depth.

    final priorRaw = await backend.readViewRowInTxn(txn, viewName, color);
    final priorOn = (priorRaw?['is_on'] as bool?) ?? false;
    final next = <String, Object?>{
      'color': color,
      'is_on': !priorOn,
      'last_toggled_at': event.clientTimestamp.toUtc().toIso8601String(),
    };
    await backend.upsertViewRowInTxn(txn, viewName, color, next);
  }
}

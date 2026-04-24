import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:flutter/foundation.dart';

/// UI state container for the demo. Holds the cross-panel selection tri-
/// state (aggregate / event / fifo row — mutually exclusive), a binding
/// to the shipped `DestinationRegistry`, and a handle to the process-wide
/// `SyncPolicy` notifier.
///
/// No REQ assertions target this file directly — it is UI plumbing that
/// the widget tasks read through. Per-panel selection highlighting and
/// the DETAIL column both resolve through these getters.
class AppState extends ChangeNotifier {
  AppState({required this.registry, required this.policyNotifier});

  final DestinationRegistry registry;
  final ValueNotifier<SyncPolicy> policyNotifier;

  String? _selectedAggregateId;
  String? _selectedEventId;
  String? _selectedFifoRowId;
  String? _selectedFifoDestinationId;

  String? get selectedAggregateId => _selectedAggregateId;
  String? get selectedEventId => _selectedEventId;
  String? get selectedFifoRowId => _selectedFifoRowId;

  /// Destination id that owns `_selectedFifoRowId`. FIFO rows in
  /// different destinations can collide on `entry_id` because
  /// `FifoEntry.entryId == eventIds.first` — the library re-uses the
  /// first event's id as the row id. The pair `(destinationId,
  /// entryId)` is what actually identifies a row uniquely.
  String? get selectedFifoDestinationId => _selectedFifoDestinationId;

  void selectAggregate(String? id) {
    _selectedAggregateId = id;
    _selectedEventId = null;
    _selectedFifoRowId = null;
    _selectedFifoDestinationId = null;
    notifyListeners();
  }

  void selectEvent(String? id) {
    _selectedAggregateId = null;
    _selectedEventId = id;
    _selectedFifoRowId = null;
    _selectedFifoDestinationId = null;
    notifyListeners();
  }

  void selectFifoRow(String? destinationId, String? id) {
    _selectedAggregateId = null;
    _selectedEventId = null;
    _selectedFifoRowId = id;
    _selectedFifoDestinationId = destinationId;
    notifyListeners();
  }

  void clearSelection() {
    _selectedAggregateId = null;
    _selectedEventId = null;
    _selectedFifoRowId = null;
    _selectedFifoDestinationId = null;
    notifyListeners();
  }

  /// Every `DemoDestination` currently registered, in registration order.
  /// Non-DemoDestinations registered by foreign code are filtered out
  /// because the demo's UI controls are shaped to `DemoDestination` knobs
  /// (connection / latency / batch size sliders).
  List<DemoDestination> get destinations =>
      registry.all().whereType<DemoDestination>().toList(growable: false);

  /// Delegate to `DestinationRegistry.addDestination` and notify listeners
  /// so widgets bound to `destinations` rebuild.
  Future<void> addDestination(DemoDestination destination) async {
    await registry.addDestination(destination);
    notifyListeners();
  }
}

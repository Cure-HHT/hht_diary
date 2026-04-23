import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:append_only_datastore_demo/demo_destination.dart';
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

  String? get selectedAggregateId => _selectedAggregateId;
  String? get selectedEventId => _selectedEventId;
  String? get selectedFifoRowId => _selectedFifoRowId;

  void selectAggregate(String? id) {
    _selectedAggregateId = id;
    _selectedEventId = null;
    _selectedFifoRowId = null;
    notifyListeners();
  }

  void selectEvent(String? id) {
    _selectedAggregateId = null;
    _selectedEventId = id;
    _selectedFifoRowId = null;
    notifyListeners();
  }

  void selectFifoRow(String? id) {
    _selectedAggregateId = null;
    _selectedEventId = null;
    _selectedFifoRowId = id;
    notifyListeners();
  }

  void clearSelection() {
    _selectedAggregateId = null;
    _selectedEventId = null;
    _selectedFifoRowId = null;
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

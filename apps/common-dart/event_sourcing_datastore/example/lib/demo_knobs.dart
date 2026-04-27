import 'package:flutter/foundation.dart';

/// Live-tunable network simulation. The destination's `send()` routes by
/// `connection.value`: `ok` succeeds (after `sendLatency.value`), `broken`
/// returns `SendTransient`, `rejecting` returns `SendPermanent`.
enum Connection { ok, broken, rejecting }

/// Shared interface implemented by demo destinations that expose
/// live-tunable network/batch knobs to the FIFO panel UI. The panel
/// renders sliders + a connection dropdown for any destination that
/// implements this interface, regardless of its concrete class. Both
/// `DemoDestination` (lossy) and `NativeDemoDestination` (esd/batch@1)
/// implement it; production destinations typically would not.
///
/// The four notifiers map onto:
/// - `connection` — drives `send()` outcome (ok / transient / permanent).
/// - `sendLatency` — `Future.delayed` applied before returning `SendOk`.
/// - `batchSize` — read by `canAddToBatch` to cap current batch length.
/// - `maxAccumulateTimeN` — backing notifier for the
///   `Destination.maxAccumulateTime` getter.
abstract class DemoKnobs {
  ValueNotifier<Connection> get connection;
  ValueNotifier<Duration> get sendLatency;
  ValueNotifier<int> get batchSize;
  ValueNotifier<Duration> get maxAccumulateTimeN;
}

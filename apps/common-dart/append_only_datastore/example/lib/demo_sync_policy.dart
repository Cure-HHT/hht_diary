import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:flutter/foundation.dart';

// Implements: REQ-d00126 — SyncPolicy is a value object; demo defaults
// per design §7.7. Short backoff (1s initial, 10s ceiling, no jitter,
// 1M attempts) makes retry cadence observable live on a reviewer's
// desktop without them waiting minutes between attempts. Production's
// SyncPolicy.defaults (60s initial, 2h ceiling, 0.1 jitter, 20 attempts)
// stays untouched.
const SyncPolicy demoDefaultSyncPolicy = SyncPolicy(
  initialBackoff: Duration(seconds: 1),
  backoffMultiplier: 1.0,
  maxBackoff: Duration(seconds: 10),
  jitterFraction: 0.0,
  maxAttempts: 1000000,
  periodicInterval: Duration(seconds: 1),
);

/// Process-wide mutable policy handle read by `SyncCycle` at every tick
/// (via the 1-second Timer.periodic in `main.dart`) and mutated by the
/// slider bar at Task 12.
final ValueNotifier<SyncPolicy> demoPolicyNotifier = ValueNotifier<SyncPolicy>(
  demoDefaultSyncPolicy,
);

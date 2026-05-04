import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

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

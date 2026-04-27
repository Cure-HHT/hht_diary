part of 'sembast_backend.dart';

/// Test-only accessors that reach past the [StorageBackend] abstraction
/// into the underlying sembast database. Application code SHALL NOT
/// reach for these — every read/write need has a typed `StorageBackend`
/// method (`readFifoHead`, `readFifoRow`, `listFifoEntries`,
/// `findEventById`, `findEventsForAggregate`, `findAllEvents`,
/// `findEntries`, `findViewRows`, `queryAudit`, etc.).
///
/// Tests use these to (a) inspect raw store contents that have no
/// public API equivalent (e.g., asserting the on-disk shape of a FIFO
/// row's payload column or audit-trail wedged-row attempts[]), and
/// (b) perform surgical mutations that simulate corruption / partial
/// writes for negative-path coverage (e.g., the missing-event drain
/// test in `drain_test.dart`).
///
/// New non-test callers ARE a code smell and SHALL be reviewed against
/// the typed surface first. The `@visibleForTesting` annotation makes
/// the analyzer flag any non-test caller.
extension SembastBackendTestSupport on SembastBackend {
  // Implements: REQ-d00151-B (compliance posture) — keeps the raw-database
  // accessor outside the production API surface; only test code reaches
  // for it via this extension, and the analyzer flags non-test callers
  // through the @visibleForTesting annotation.
  /// Underlying sembast [Database] handle. Visible for tests only.
  @visibleForTesting
  Database get databaseForTesting => _db;
}

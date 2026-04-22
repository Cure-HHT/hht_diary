import 'package:append_only_datastore/src/destinations/destination.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:flutter/foundation.dart';

/// Process-wide registry of synchronization destinations.
///
/// Registration is a boot-time concern: sponsor-repo `main()` calls
/// [register] for each destination defined for its trial before any event
/// write happens. On the first [all] or [matchingDestinations] read the
/// registry freezes — subsequent [register] calls throw. The freeze is
/// deliberate: if destinations could be registered after events start
/// flowing, a FIFO could contain entries authored before a late-registered
/// destination's filter applied, producing a silently-invalid queue.
///
/// A singleton is the right shape because the FIFO stores themselves are
/// process-global (Sembast's database), so the set of destinations that
/// those FIFOs correspond to must also be process-global. Tests bypass the
/// singleton-lifetime guarantee via [reset], which is annotated
/// `@visibleForTesting`.
// Implements: REQ-d00122-G — boot-time registration; immutable post-freeze.
// Implements: REQ-d00122-A — destination ids are unique in the registry.
class DestinationRegistry {
  DestinationRegistry._();

  /// Singleton instance. Sponsor-repo boot code and tests both access the
  /// registry through this getter.
  static final DestinationRegistry instance = DestinationRegistry._();

  final List<Destination> _destinations = [];
  bool _frozen = false;

  /// Register [destination]. Call at boot, before any [all] or
  /// [matchingDestinations] read.
  ///
  /// Throws `ArgumentError` if a destination with the same [Destination.id]
  /// is already registered (REQ-d00122-A).
  /// Throws `StateError` if the registry has already frozen on a prior
  /// [all]/[matchingDestinations] read (REQ-d00122-G).
  void register(Destination destination) {
    if (_frozen) {
      throw StateError(
        'DestinationRegistry is frozen; register(${destination.id}) '
        'must happen at boot, before any all() or matchingDestinations() '
        'read (REQ-d00122-G).',
      );
    }
    for (final existing in _destinations) {
      if (existing.id == destination.id) {
        throw ArgumentError.value(
          destination.id,
          'destination.id',
          'destination id ${destination.id} is already registered '
              '(REQ-d00122-A)',
        );
      }
    }
    _destinations.add(destination);
  }

  /// All registered destinations, in registration order. The first call
  /// freezes the registry (REQ-d00122-G); the returned list is
  /// unmodifiable.
  List<Destination> all() {
    _frozen = true;
    return List<Destination>.unmodifiable(_destinations);
  }

  /// Destinations whose filter matches [event], in registration order.
  /// Also freezes the registry on first call (same as [all]).
  List<Destination> matchingDestinations(StoredEvent event) {
    _frozen = true;
    return _destinations
        .where((d) => d.filter.matches(event))
        .toList(growable: false);
  }

  /// Wipe the registry and unfreeze. Test-only — production must never
  /// reach this path because changing the set of registered destinations
  /// after events have been enqueued is a data-integrity violation.
  @visibleForTesting
  void reset() {
    _destinations.clear();
    _frozen = false;
  }
}

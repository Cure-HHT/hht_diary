import 'package:trial_data_types/trial_data_types.dart';

/// Process-wide registry mapping `entry_type` ids to `EntryTypeDefinition`.
///
/// `EntryService.record` validates the incoming `entryType` through this
/// registry (REQ-d00133-H) before opening a write transaction; widgets and
/// materialization paths also read through it to resolve per-type metadata
/// (`effective_date_path`, `widget_id`). Centralizing registrations on one
/// object is how an app keeps "the set of known entry types" a single
/// authority rather than a ledger scattered across widgets.
///
/// This minimal surface — `register`, `byId`, `isRegistered`, `all` — is
/// what `EntryService.record` needs in Phase 4.3 Task 16. Task 17 will
/// polish the surface (iteration ergonomics, JSON registration helpers)
/// without changing these signatures.
// Implements: REQ-d00133-H — isRegistered backs record()'s pre-I/O
// entryType validation.
class EntryTypeRegistry {
  /// Register [defn]. Duplicate id is a configuration bug — silent
  /// shadowing would let an app declare two competing definitions for the
  /// same entry type and the later one would silently win — so it is
  /// surfaced loudly via `ArgumentError`.
  void register(EntryTypeDefinition defn) {
    if (_defs.containsKey(defn.id)) {
      throw ArgumentError.value(
        defn.id,
        'defn.id',
        'EntryTypeDefinition "${defn.id}" already registered',
      );
    }
    _defs[defn.id] = defn;
  }

  /// Returns the `EntryTypeDefinition` registered under [id], or `null`
  /// when no registration matches. Callers distinguish "unknown type"
  /// from "registered" with a null check.
  EntryTypeDefinition? byId(String id) => _defs[id];

  /// True iff a definition is registered under [id]. Convenience
  /// wrapper over `byId != null` for call sites that only need the
  /// yes/no answer.
  bool isRegistered(String id) => _defs.containsKey(id);

  /// Every currently-registered `EntryTypeDefinition`, in registration
  /// order. Returned list is unmodifiable so callers cannot mutate the
  /// registry by mutating the view.
  List<EntryTypeDefinition> all() =>
      List<EntryTypeDefinition>.unmodifiable(_defs.values);

  final Map<String, EntryTypeDefinition> _defs =
      <String, EntryTypeDefinition>{};
}

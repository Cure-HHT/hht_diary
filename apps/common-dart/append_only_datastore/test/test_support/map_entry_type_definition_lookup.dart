import 'package:append_only_datastore/src/materialization/entry_type_definition_lookup.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// In-memory [EntryTypeDefinitionLookup] for use in tests.
///
/// Lives under `test/test_support/` — intentionally NOT exported from
/// `lib/` — so production code cannot accidentally depend on a registry
/// that the test environment constructed. Apps register their real
/// destinations via the sponsor-repo registry (Phase 5 wiring).
class MapEntryTypeDefinitionLookup extends EntryTypeDefinitionLookup {
  MapEntryTypeDefinitionLookup(Map<String, EntryTypeDefinition> byId)
    : _byId = Map<String, EntryTypeDefinition>.unmodifiable(byId);

  /// Builds a lookup from a list of definitions, indexing them by `id`.
  /// Throws [ArgumentError] if two definitions share the same `id` — silent
  /// shadowing would be a registration bug, so it is surfaced at construction
  /// time.
  factory MapEntryTypeDefinitionLookup.fromDefinitions(
    Iterable<EntryTypeDefinition> definitions,
  ) {
    final map = <String, EntryTypeDefinition>{};
    for (final def in definitions) {
      if (map.containsKey(def.id)) {
        throw ArgumentError.value(
          def.id,
          'definitions',
          'duplicate EntryTypeDefinition id',
        );
      }
      map[def.id] = def;
    }
    return MapEntryTypeDefinitionLookup(map);
  }

  final Map<String, EntryTypeDefinition> _byId;

  @override
  EntryTypeDefinition? lookup(String entryTypeId) => _byId[entryTypeId];
}

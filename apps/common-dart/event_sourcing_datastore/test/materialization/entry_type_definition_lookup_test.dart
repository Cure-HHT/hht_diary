import 'package:event_sourcing_datastore/src/materialization/entry_type_definition_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

import '../test_support/map_entry_type_definition_lookup.dart';

void main() {
  EntryTypeDefinition defFor(String id) => EntryTypeDefinition(
    id: id,
    version: '1',
    name: id,
    widgetId: 'any_widget_v1',
    widgetConfig: const <String, Object?>{},
  );

  group('EntryTypeDefinitionLookup contract', () {
    test(
      'REQ-d00121-A: returns the matching definition when id is registered',
      () {
        final epistaxis = defFor('epistaxis_event');
        final survey = defFor('nose_hht_survey');
        final EntryTypeDefinitionLookup lookup = MapEntryTypeDefinitionLookup({
          'epistaxis_event': epistaxis,
          'nose_hht_survey': survey,
        });

        expect(lookup.lookup('epistaxis_event'), same(epistaxis));
        expect(lookup.lookup('nose_hht_survey'), same(survey));
      },
    );

    test('REQ-d00121-A: returns null when id is not registered', () {
      final EntryTypeDefinitionLookup lookup = MapEntryTypeDefinitionLookup({
        'epistaxis_event': defFor('epistaxis_event'),
      });

      expect(lookup.lookup('unknown_type'), isNull);
    });

    test('REQ-d00121-A: empty registry returns null for every query', () {
      final EntryTypeDefinitionLookup lookup = MapEntryTypeDefinitionLookup(
        const {},
      );

      expect(lookup.lookup('epistaxis_event'), isNull);
      expect(lookup.lookup(''), isNull);
    });
  });

  group('MapEntryTypeDefinitionLookup test double', () {
    test('wraps the provided map without copying references', () {
      final def = defFor('x');
      final lookup = MapEntryTypeDefinitionLookup({'x': def});

      expect(identical(lookup.lookup('x'), def), isTrue);
    });

    test('fromDefinitions constructs a lookup from a list of definitions', () {
      final a = defFor('a');
      final b = defFor('b');

      final lookup = MapEntryTypeDefinitionLookup.fromDefinitions([a, b]);

      expect(lookup.lookup('a'), same(a));
      expect(lookup.lookup('b'), same(b));
      expect(lookup.lookup('c'), isNull);
    });

    test('fromDefinitions rejects duplicate ids to prevent silent registry '
        'shadowing', () {
      final a1 = defFor('a');
      final a2 = defFor('a');

      expect(
        () => MapEntryTypeDefinitionLookup.fromDefinitions([a1, a2]),
        throwsArgumentError,
      );
    });
  });
}

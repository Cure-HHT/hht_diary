import 'package:event_sourcing_datastore/src/entry_type_definition.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _validJson() => <String, Object?>{
  'id': 'epistaxis_event',
  'registered_version': 1,
  'name': 'Nosebleed',
  'widget_id': 'epistaxis_form_v1',
  'widget_config': <String, Object?>{},
  'effective_date_path': null,
  'destination_tags': null,
};

/// Verifies REQ-d00116-A, REQ-d00116-B, REQ-d00116-C, REQ-d00116-D,
/// REQ-d00116-F, REQ-d00116-G. (REQ-d00116-E — materializer fallback — is
/// covered by tests in Phase 3 when the materializer consumes this type.)
void main() {
  group('EntryTypeDefinition', () {
    // Verifies: REQ-d00116-A+B+C+D+E — all five required fields present.
    test(
      'REQ-d00116-A,B,C,D,E: constructs with all required fields; getters round-trip',
      () {
        const def = EntryTypeDefinition(
          id: 'epistaxis_event',
          registeredVersion: 1,
          name: 'Nosebleed',
          widgetId: 'epistaxis_form_v1',
          widgetConfig: {},
        );

        expect(def.id, 'epistaxis_event');
        expect(def.registeredVersion, 1);
        expect(def.name, 'Nosebleed');
        expect(def.widgetId, 'epistaxis_form_v1');
        expect(def.widgetConfig, const <String, dynamic>{});
        expect(def.effectiveDatePath, isNull);
        expect(def.destinationTags, isNull);
      },
    );

    // Verifies: REQ-d00116-F — optional JSON path for materializer.
    test(
      'REQ-d00116-F: effectiveDatePath accepts a dotted JSON path when supplied',
      () {
        const def = EntryTypeDefinition(
          id: 'epistaxis_event',
          registeredVersion: 1,
          name: 'Nosebleed',
          widgetId: 'epistaxis_form_v1',
          widgetConfig: {},
          effectiveDatePath: 'startTime',
        );
        expect(def.effectiveDatePath, 'startTime');
      },
    );

    // Verifies: REQ-d00116-G — optional destination tags list.
    test('REQ-d00116-G: destinationTags accepts a list of strings', () {
      const def = EntryTypeDefinition(
        id: 'hht_qol_survey',
        registeredVersion: 1,
        name: 'HHT Quality of Life',
        widgetId: 'survey_renderer_v1',
        widgetConfig: {},
        destinationTags: ['clinical', 'uat'],
      );
      expect(def.destinationTags, const ['clinical', 'uat']);
    });

    // Verifies: REQ-d00116-E — widget_config round-trips arbitrary JSON.
    test('REQ-d00116-E: widgetConfig round-trips arbitrary nested JSON', () {
      final payload = <String, dynamic>{
        'instrument': 'NOSE-HHT',
        'questions': [
          {'id': 'q1', 'text': 'Nasal obstruction', 'scale': 0},
          {'id': 'q2', 'text': 'Runny nose', 'scale': 0},
        ],
        'scoring': {
          'max': 100,
          'weights': [1, 2, 1],
        },
      };

      final def = EntryTypeDefinition(
        id: 'nose_hht_survey',
        registeredVersion: 1,
        name: 'NOSE HHT Questionnaire',
        widgetId: 'survey_renderer_v1',
        widgetConfig: payload,
      );

      final roundTripped = EntryTypeDefinition.fromJson(def.toJson());
      expect(roundTripped.widgetConfig, payload);
    });

    // Verifies: REQ-d00116-A+B+C+D+E+F+G — toJson emits snake_case keys.
    test('toJson emits snake_case keys for every field', () {
      const def = EntryTypeDefinition(
        id: 'epistaxis_event',
        registeredVersion: 1,
        name: 'Nosebleed',
        widgetId: 'epistaxis_form_v1',
        widgetConfig: {'variant': 'full'},
        effectiveDatePath: 'startTime',
        destinationTags: ['clinical'],
      );

      expect(def.toJson(), {
        'id': 'epistaxis_event',
        'registered_version': 1,
        'name': 'Nosebleed',
        'widget_id': 'epistaxis_form_v1',
        'widget_config': {'variant': 'full'},
        'effective_date_path': 'startTime',
        'destination_tags': ['clinical'],
        'materialize': true,
      });
    });

    // Verifies: REQ-d00116-F+G — toJson preserves nulls for optional fields.
    test(
      'REQ-d00116-F,G: toJson emits null for absent effective_date_path and destination_tags',
      () {
        const def = EntryTypeDefinition(
          id: 'epistaxis_event',
          registeredVersion: 1,
          name: 'Nosebleed',
          widgetId: 'epistaxis_form_v1',
          widgetConfig: {},
        );

        final json = def.toJson();
        expect(json['effective_date_path'], isNull);
        expect(json['destination_tags'], isNull);
      },
    );

    // Verifies: round-trip preserves all fields including nulls.
    test('toJson/fromJson round-trip preserves all fields', () {
      const def = EntryTypeDefinition(
        id: 'epistaxis_event',
        registeredVersion: 2,
        name: 'Nosebleed',
        widgetId: 'epistaxis_form_v1',
        widgetConfig: {'variant': 'full'},
        effectiveDatePath: 'startTime',
        destinationTags: ['clinical', 'uat'],
      );

      final roundTripped = EntryTypeDefinition.fromJson(def.toJson());
      expect(roundTripped, equals(def));
    });

    group('fromJson validation', () {
      // Verifies: REQ-d00116-A — missing id rejected.
      test('REQ-d00116-A: missing id throws FormatException', () {
        final bad = _validJson()..remove('id');
        expect(() => EntryTypeDefinition.fromJson(bad), throwsFormatException);
      });

      // Verifies: REQ-d00116-B — missing registered_version rejected.
      test(
        'REQ-d00116-B: missing registered_version throws FormatException',
        () {
          final bad = _validJson()..remove('registered_version');
          expect(
            () => EntryTypeDefinition.fromJson(bad),
            throwsFormatException,
          );
        },
      );

      // Verifies: REQ-d00116-C — missing name rejected.
      test('REQ-d00116-C: missing name throws FormatException', () {
        final bad = _validJson()..remove('name');
        expect(() => EntryTypeDefinition.fromJson(bad), throwsFormatException);
      });

      // Verifies: REQ-d00116-D — missing widget_id rejected.
      test('REQ-d00116-D: missing widget_id throws FormatException', () {
        final bad = _validJson()..remove('widget_id');
        expect(() => EntryTypeDefinition.fromJson(bad), throwsFormatException);
      });

      // Verifies: REQ-d00116-E — missing widget_config rejected.
      test('REQ-d00116-E: missing widget_config throws FormatException', () {
        final bad = _validJson()..remove('widget_config');
        expect(() => EntryTypeDefinition.fromJson(bad), throwsFormatException);
      });

      // Verifies: absent optional fields default to null.
      test('absent optional fields default to null', () {
        final minimal = <String, Object?>{
          'id': 'x',
          'registered_version': 1,
          'name': 'x',
          'widget_id': 'w',
          'widget_config': const <String, Object?>{},
        };
        final def = EntryTypeDefinition.fromJson(minimal);
        expect(def.effectiveDatePath, isNull);
        expect(def.destinationTags, isNull);
      });

      // Verifies: REQ-d00116-G — destination_tags parsed to List<String>.
      test('REQ-d00116-G: destination_tags JSON list becomes List<String>', () {
        final input = _validJson()
          ..['destination_tags'] = <dynamic>['clinical', 'uat'];
        final def = EntryTypeDefinition.fromJson(input);
        expect(def.destinationTags, const ['clinical', 'uat']);
      });

      // Verifies: REQ-d00116-D — non-string widget_id rejected.
      test('REQ-d00116-D: non-string widget_id throws FormatException', () {
        final bad = _validJson()..['widget_id'] = 42;
        expect(() => EntryTypeDefinition.fromJson(bad), throwsFormatException);
      });
    });

    group('value equality', () {
      // Verifies: equal fields produce equal entries.
      test('equal fields produce equal entries with equal hashCodes', () {
        const a = EntryTypeDefinition(
          id: 'epistaxis_event',
          registeredVersion: 1,
          name: 'Nosebleed',
          widgetId: 'epistaxis_form_v1',
          widgetConfig: {'variant': 'full'},
          effectiveDatePath: 'startTime',
          destinationTags: ['clinical'],
        );
        const b = EntryTypeDefinition(
          id: 'epistaxis_event',
          registeredVersion: 1,
          name: 'Nosebleed',
          widgetId: 'epistaxis_form_v1',
          widgetConfig: {'variant': 'full'},
          effectiveDatePath: 'startTime',
          destinationTags: ['clinical'],
        );

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('any field difference breaks equality', () {
        const base = EntryTypeDefinition(
          id: 'epistaxis_event',
          registeredVersion: 1,
          name: 'Nosebleed',
          widgetId: 'epistaxis_form_v1',
          widgetConfig: {},
        );

        expect(
          base,
          isNot(
            equals(
              EntryTypeDefinition(
                id: 'nose_hht_survey',
                registeredVersion: base.registeredVersion,
                name: base.name,
                widgetId: base.widgetId,
                widgetConfig: base.widgetConfig,
              ),
            ),
          ),
        );
        expect(
          base,
          isNot(
            equals(
              EntryTypeDefinition(
                id: base.id,
                registeredVersion: 2,
                name: base.name,
                widgetId: base.widgetId,
                widgetConfig: base.widgetConfig,
              ),
            ),
          ),
        );
      });

      // Verifies: REQ-d00116-E — deep inequality through nested widgetConfig.
      // A difference at depth ≥ 2 inside widgetConfig must break equality,
      // so a degraded deep-equality implementation would be caught.
      test(
        'REQ-d00116-E: nested widgetConfig difference at depth >= 2 breaks equality',
        () {
          const a = EntryTypeDefinition(
            id: 'nose_hht_survey',
            registeredVersion: 1,
            name: 'NOSE HHT',
            widgetId: 'survey_renderer_v1',
            widgetConfig: <String, Object?>{
              'scoring': <String, Object?>{
                'weights': <int>[1, 2, 1],
              },
            },
          );
          const b = EntryTypeDefinition(
            id: 'nose_hht_survey',
            registeredVersion: 1,
            name: 'NOSE HHT',
            widgetId: 'survey_renderer_v1',
            widgetConfig: <String, Object?>{
              'scoring': <String, Object?>{
                'weights': <int>[1, 2, 2], // differs at depth 3
              },
            },
          );
          expect(a, isNot(equals(b)));
        },
      );

      // Verifies: REQ-d00116-G — empty list and null are distinct.
      // Tests both equality and JSON output.
      test(
        'REQ-d00116-G: destinationTags empty list is distinct from null (equality)',
        () {
          const withNull = EntryTypeDefinition(
            id: 'x',
            registeredVersion: 1,
            name: 'x',
            widgetId: 'w',
            widgetConfig: {},
          );
          const withEmpty = EntryTypeDefinition(
            id: 'x',
            registeredVersion: 1,
            name: 'x',
            widgetId: 'w',
            widgetConfig: {},
            destinationTags: <String>[],
          );
          expect(withNull, isNot(equals(withEmpty)));
          expect(withNull.destinationTags, isNull);
          expect(withEmpty.destinationTags, isEmpty);
        },
      );

      test(
        'REQ-d00116-G: destinationTags empty list vs null surface differently in toJson',
        () {
          const withNull = EntryTypeDefinition(
            id: 'x',
            registeredVersion: 1,
            name: 'x',
            widgetId: 'w',
            widgetConfig: {},
          );
          const withEmpty = EntryTypeDefinition(
            id: 'x',
            registeredVersion: 1,
            name: 'x',
            widgetId: 'w',
            widgetConfig: {},
            destinationTags: <String>[],
          );
          expect(withNull.toJson()['destination_tags'], isNull);
          expect(withEmpty.toJson()['destination_tags'], isEmpty);
        },
      );
    });
  });

  group('REQ-d00140-C: materialize flag', () {
    test('defaults to true', () {
      const def = EntryTypeDefinition(
        id: 'x',
        registeredVersion: 1,
        name: 'X',
        widgetId: 'w',
        widgetConfig: <String, Object?>{},
      );
      expect(def.materialize, isTrue);
    });

    test('false round-trips through JSON', () {
      const def = EntryTypeDefinition(
        id: 'x',
        registeredVersion: 1,
        name: 'X',
        widgetId: 'w',
        widgetConfig: <String, Object?>{},
        materialize: false,
      );
      expect(def.materialize, isFalse);
      final map = def.toJson();
      expect(map['materialize'], isFalse);
      final roundTripped = EntryTypeDefinition.fromJson(map);
      expect(roundTripped.materialize, isFalse);
    });

    test('absent "materialize" in JSON defaults to true', () {
      final def = EntryTypeDefinition.fromJson(<String, Object?>{
        'id': 'x',
        'registered_version': 1,
        'name': 'X',
        'widget_id': 'w',
        'widget_config': const <String, Object?>{},
      });
      expect(def.materialize, isTrue);
    });

    test('non-bool "materialize" is rejected', () {
      expect(
        () => EntryTypeDefinition.fromJson(<String, Object?>{
          'id': 'x',
          'registered_version': 1,
          'name': 'X',
          'widget_id': 'w',
          'widget_config': const <String, Object?>{},
          'materialize': 'yes',
        }),
        throwsFormatException,
      );
    });

    test('materialize participates in equality', () {
      const a = EntryTypeDefinition(
        id: 'x',
        registeredVersion: 1,
        name: 'X',
        widgetId: 'w',
        widgetConfig: <String, Object?>{},
      );
      const b = EntryTypeDefinition(
        id: 'x',
        registeredVersion: 1,
        name: 'X',
        widgetId: 'w',
        widgetConfig: <String, Object?>{},
        materialize: false,
      );
      expect(a, isNot(b));
    });
  });

  group('REQ-d00116-B: registered_version replaces version field', () {
    // Verifies: REQ-d00116-B
    test('fromJson rejects missing registered_version', () {
      final m = _validJson()..remove('registered_version');
      expect(() => EntryTypeDefinition.fromJson(m), throwsFormatException);
    });
    // Verifies: REQ-d00116-B
    test('fromJson rejects non-int registered_version', () {
      final m = _validJson()..['registered_version'] = '1';
      expect(() => EntryTypeDefinition.fromJson(m), throwsFormatException);
    });
    // Verifies: REQ-d00116-B
    test('toJson uses snake_case key', () {
      const d = EntryTypeDefinition(
        id: 'demo',
        registeredVersion: 5,
        name: 'Demo',
        widgetId: 'w',
        widgetConfig: <String, Object?>{},
      );
      expect(d.toJson()['registered_version'], 5);
      expect(d.toJson().containsKey('version'), isFalse);
    });
  });
}

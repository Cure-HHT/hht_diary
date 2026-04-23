import 'package:append_only_datastore_demo/demo_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('demoNoteType (EntryTypeDefinition contract, REQ-d00116)', () {
    // Verifies: REQ-d00116 EntryTypeDefinition schema — demo_note declares
    //   id, version, name, widgetId, widgetConfig, effectiveDatePath.
    test('id is "demo_note"', () {
      expect(demoNoteType.id, 'demo_note');
    });
    test('version non-empty', () {
      expect(demoNoteType.version, isNotEmpty);
    });
    test('name non-empty', () {
      expect(demoNoteType.name, isNotEmpty);
    });
    test('widgetId is "demo_note_widget_v1"', () {
      expect(demoNoteType.widgetId, 'demo_note_widget_v1');
    });
    test('effectiveDatePath is "date" (answer-derived)', () {
      expect(demoNoteType.effectiveDatePath, 'date');
    });
  });

  group('action-button entry types (RED / GREEN / BLUE)', () {
    // Verifies: REQ-d00116 EntryTypeDefinition schema + JNY-02 CQRS
    //   discriminator — each action-button type has its own id and a
    //   non-'DiaryEntry' aggregate type stored separately in
    //   demoAggregateTypeByEntryTypeId (EntryTypeDefinition itself has
    //   no aggregateType field in the shipped 4.3 API).
    test('redButtonType.id == "red_button_pressed"', () {
      expect(redButtonType.id, 'red_button_pressed');
    });
    test('greenButtonType.id == "green_button_pressed"', () {
      expect(greenButtonType.id, 'green_button_pressed');
    });
    test('blueButtonType.id == "blue_button_pressed"', () {
      expect(blueButtonType.id, 'blue_button_pressed');
    });
    test('action-button widgetId is "action_button_v1" for each', () {
      expect(redButtonType.widgetId, 'action_button_v1');
      expect(greenButtonType.widgetId, 'action_button_v1');
      expect(blueButtonType.widgetId, 'action_button_v1');
    });
    test('action-button effectiveDatePath is null (point-in-time)', () {
      expect(redButtonType.effectiveDatePath, isNull);
      expect(greenButtonType.effectiveDatePath, isNull);
      expect(blueButtonType.effectiveDatePath, isNull);
    });
  });

  group('demoAggregateTypeByEntryTypeId (CQRS discriminator for JNY-02)', () {
    // Verifies: JNY-02 — action-button events carry a non-'DiaryEntry'
    //   aggregate_type so the materializer skips them and the events
    //   panel shows them with variant aggregate_type.
    test('demo_note maps to "DiaryEntry"', () {
      expect(demoAggregateTypeByEntryTypeId['demo_note'], 'DiaryEntry');
    });
    test('red_button_pressed maps to "RedButtonPressed"', () {
      expect(
        demoAggregateTypeByEntryTypeId['red_button_pressed'],
        'RedButtonPressed',
      );
    });
    test('green_button_pressed maps to "GreenButtonPressed"', () {
      expect(
        demoAggregateTypeByEntryTypeId['green_button_pressed'],
        'GreenButtonPressed',
      );
    });
    test('blue_button_pressed maps to "BlueButtonPressed"', () {
      expect(
        demoAggregateTypeByEntryTypeId['blue_button_pressed'],
        'BlueButtonPressed',
      );
    });
    test('all three action-button aggregate types are != "DiaryEntry"', () {
      const actionIds = <String>[
        'red_button_pressed',
        'green_button_pressed',
        'blue_button_pressed',
      ];
      for (final id in actionIds) {
        expect(demoAggregateTypeByEntryTypeId[id], isNot('DiaryEntry'));
      }
    });
  });

  group('allDemoEntryTypes (REQ-d00134 bootstrap registration)', () {
    // Verifies: REQ-d00134 bootstrapAppendOnlyDatastore takes
    //   List<EntryTypeDefinition>; duplicate id would throw at register.
    test('has exactly four entries', () {
      expect(allDemoEntryTypes.length, 4);
    });
    test('all ids are unique', () {
      final ids = allDemoEntryTypes.map((e) => e.id).toSet();
      expect(ids.length, 4);
    });
    test('covers demo_note + three action-button types', () {
      final ids = allDemoEntryTypes.map((e) => e.id).toSet();
      expect(
        ids,
        containsAll(<String>{
          'demo_note',
          'red_button_pressed',
          'green_button_pressed',
          'blue_button_pressed',
        }),
      );
    });
  });
}

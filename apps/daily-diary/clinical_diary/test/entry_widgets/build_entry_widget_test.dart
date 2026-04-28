// Verifies: REQ-d00115 — widget_id -> widget dispatch.

import 'package:clinical_diary/entry_widgets/build_entry_widget.dart';
import 'package:clinical_diary/entry_widgets/entry_widget_context.dart';
import 'package:clinical_diary/entry_widgets/epistaxis_form_widget.dart';
import 'package:clinical_diary/entry_widgets/survey_renderer_widget.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

EntryWidgetContext _ctx() => EntryWidgetContext(
  entryType: 'test_type',
  aggregateId: 'agg-1',
  widgetConfig: const <String, Object?>{},
  recorder:
      ({
        required entryType,
        required aggregateId,
        required eventType,
        required answers,
        checkpointReason,
        changeReason,
      }) async => null,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('buildEntryWidget', () {
    // Verifies: REQ-d00115 — epistaxis_form_v1 dispatches to EpistaxisFormWidget.
    test('epistaxis_form_v1 returns EpistaxisFormWidget', () {
      final widget = buildEntryWidget(_ctx(), 'epistaxis_form_v1');
      expect(widget, isA<EpistaxisFormWidget>());
    });

    // Verifies: REQ-d00115 — survey_renderer_v1 dispatches to SurveyRendererWidget.
    test('survey_renderer_v1 returns SurveyRendererWidget', () {
      final widget = buildEntryWidget(_ctx(), 'survey_renderer_v1');
      expect(widget, isA<SurveyRendererWidget>());
    });

    // Verifies: REQ-d00115 — unknown widget_id throws ArgumentError.
    test('unknown widget_id throws ArgumentError', () {
      expect(
        () => buildEntryWidget(_ctx(), 'unknown_widget_v99'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('unknown_widget_v99'),
          ),
        ),
      );
    });
  });
}

// Implements: REQ-d00115 — widget_id -> widget dispatch.

import 'package:clinical_diary/entry_widgets/entry_widget_context.dart';
import 'package:clinical_diary/entry_widgets/epistaxis_form_widget.dart';
import 'package:clinical_diary/entry_widgets/survey_renderer_widget.dart';
import 'package:flutter/widgets.dart';

/// Returns the widget for the given [widgetId], bound to [ctx].
///
/// [widgetId] comes from the `widgetId` field of the entry type's
/// `EntryTypeDefinition`. Callers obtain it by looking up the entry type in
/// the registry and forwarding the field here. Two ids are currently
/// supported:
///
/// - `'epistaxis_form_v1'` → [EpistaxisFormWidget]
/// - `'survey_renderer_v1'` → [SurveyRendererWidget]
///
/// Any other value throws [ArgumentError] immediately.
Widget buildEntryWidget(EntryWidgetContext ctx, String widgetId) {
  return switch (widgetId) {
    'epistaxis_form_v1' => EpistaxisFormWidget(ctx),
    'survey_renderer_v1' => SurveyRendererWidget(ctx),
    _ => throw ArgumentError('Unknown widget_id: $widgetId'),
  };
}

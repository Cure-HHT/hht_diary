// Implements: DIARY-DEV-reactive-read-path/A — composite that watches BOTH diary
//   views (canonical finalized + diary-local incomplete) and hands the builder a
//   single spliced DiaryView, so screens never nest two diary ViewBuilders.
import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter/widgets.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

typedef DiaryViewWidgetBuilder = Widget Function(BuildContext, DiaryView);

/// Watches the finalized + incomplete diary views and rebuilds [builder] with a
/// freshly spliced [DiaryView] on every emission.
class DiaryViewBuilder extends StatelessWidget {
  const DiaryViewBuilder({required this.builder, super.key});

  final DiaryViewWidgetBuilder builder;

  static List<DiaryEntryRow> _rows(ViewState<DiaryEntryRow> s) =>
      s is Ready<DiaryEntryRow> ? s.rows.toList() : const <DiaryEntryRow>[];

  @override
  Widget build(BuildContext context) {
    return ViewBuilder<DiaryEntryRow>(
      viewName: diaryEntriesViewName,
      mapper: DiaryEntryRow.fromViewRow,
      aggregateIdOf: (r) => r.aggregateId,
      builder: (context, finalizedState) {
        return ViewBuilder<DiaryEntryRow>(
          viewName: diaryIncompleteViewName,
          mapper: DiaryEntryRow.fromViewRow,
          aggregateIdOf: (r) => r.aggregateId,
          builder: (context, incompleteState) {
            final view = DiaryView(
              finalized: _rows(finalizedState),
              incomplete: _rows(incompleteState),
            );
            return builder(context, view);
          },
        );
      },
    );
  }
}

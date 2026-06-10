import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

/// Subscribes to the `sites_index` projection and exposes the rows as
/// sorted [SiteOptionView]s for the user dialogs (assigned-sites lists,
/// site checklists).
///
/// The wiring twin of `portal_screens`' pure site widgets: this is the
/// only place `sites_index` row shapes are known; the dialogs receive
/// value types.
class SiteOptionsView extends StatelessWidget {
  const SiteOptionsView({super.key, required this.builder});

  /// [loading] is true until the first `EndOfReplay`; [sites] is sorted
  /// by site number.
  final Widget Function(
    BuildContext context,
    List<SiteOptionView> sites,
    bool loading,
  )
  builder;

  static SiteOptionView _fromRow(Map<String, Object?> row) => SiteOptionView(
    id: (row['site_id'] as String?) ?? '?',
    number: (row['site_number'] as String?) ?? '',
    name: (row['site_name'] as String?) ?? '',
  );

  @override
  Widget build(BuildContext context) => ViewBuilder<SiteOptionView>(
    viewName: 'sites_index',
    mapper: _fromRow,
    aggregateIdOf: (s) => s.id,
    builder: (context, state) {
      final rows = switch (state) {
        Loading<SiteOptionView>() => const <SiteOptionView>[],
        Ready<SiteOptionView>(:final rows) => rows,
        Stale<SiteOptionView>(:final lastRows) => lastRows,
      };
      final sorted = <SiteOptionView>[...rows]
        ..sort((a, b) => a.number.compareTo(b.number));
      return builder(context, sorted, state is Loading<SiteOptionView>);
    },
  );
}

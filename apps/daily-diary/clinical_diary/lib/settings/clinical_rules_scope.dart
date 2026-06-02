// Implements: DIARY-DEV-reactive-read-path/C — exposes the current
//   [ClinicalRules] (derived from the settings projection by the app-level
//   ViewBuilder) to the widget tree, so the recording flow enforces the
//   sponsor/user clinical entry rules from the event stream, reactively —
//   never from the non-reactive FeatureFlagService.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter/widgets.dart';

/// Inherited surface for the folded [ClinicalRules]. Fed by the settings
/// `ViewBuilder` in `main.dart` and inserted ABOVE the Navigator (so every
/// route — recording included — reads the live rules). When no scope is present
/// [of] returns permissive defaults (no restriction) so callers always get a
/// usable value.
class ClinicalRulesScope extends InheritedWidget {
  const ClinicalRulesScope({
    required this.rules,
    required super.child,
    super.key,
  });

  final ClinicalRules rules;

  static ClinicalRules of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ClinicalRulesScope>();
    return scope?.rules ?? const ClinicalRules();
  }

  @override
  bool updateShouldNotify(ClinicalRulesScope oldWidget) =>
      rules != oldWidget.rules;
}

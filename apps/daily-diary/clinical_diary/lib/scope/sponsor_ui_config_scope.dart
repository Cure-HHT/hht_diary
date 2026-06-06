// Implements: DIARY-DEV-deployment-config-defaults/A — exposes the resolved
//   SponsorUiConfig (animation gate + font/language allow-sets) to the widget
//   tree, like AppPreferencesScope for user preferences.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter/widgets.dart';

class SponsorUiConfigScope extends InheritedWidget {
  const SponsorUiConfigScope({
    required this.config,
    required super.child,
    super.key,
  });

  final SponsorUiConfig config;

  /// The nearest config, or the code default when no scope is present.
  static SponsorUiConfig of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SponsorUiConfigScope>();
    return scope?.config ?? SponsorUiConfig.codeDefault;
  }

  @override
  bool updateShouldNotify(SponsorUiConfigScope oldWidget) =>
      oldWidget.config != config;
}

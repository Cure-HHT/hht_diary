// Implements: DIARY-DEV-reactive-read-path/C — exposes the current
//   [UserPreferences] (derived from the settings projection by the app-level
//   `ViewBuilder`) to the widget tree, so not-yet-reactive screens can read
//   preferences from context rather than holding their own copy.
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:flutter/widgets.dart';

/// Inherited preferences surface. Fed by the settings `ViewBuilder` in
/// `main.dart`; consumed via [AppPreferencesScope.of]. When no scope is present
/// (e.g. a screen rendered in isolation), [of] returns the default
/// [UserPreferences] so callers always get a usable value.
class AppPreferencesScope extends InheritedWidget {
  const AppPreferencesScope({
    required this.preferences,
    required super.child,
    super.key,
  });

  final UserPreferences preferences;

  static UserPreferences of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppPreferencesScope>();
    return scope?.preferences ?? const UserPreferences();
  }

  /// Non-subscribing read for use OUTSIDE a build method (e.g. a route's
  /// transition-duration getter), where registering an inherited dependency is
  /// inappropriate. Returns defaults when no scope is present.
  static UserPreferences read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppPreferencesScope>();
    return scope?.preferences ?? const UserPreferences();
  }

  @override
  bool updateShouldNotify(AppPreferencesScope oldWidget) =>
      preferences != oldWidget.preferences;
}

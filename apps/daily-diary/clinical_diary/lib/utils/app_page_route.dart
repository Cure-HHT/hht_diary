// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:flutter/material.dart';

/// A custom page route that respects both the build-time `useAnimations`
/// feature flag AND the user's `useAnimation` preference. When either disables
/// animations, page transitions happen instantly.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  /// Animations run only when the feature flag allows them AND the user has not
  /// turned them off in settings. The preference is read non-subscribing from
  /// the navigator's context (AppPreferencesScope sits above the Navigator);
  /// defaults to enabled when no scope/navigator is available yet.
  bool get _animationsEnabled {
    if (!FeatureFlagService.instance.useAnimations) return false;
    final context = navigator?.context;
    if (context == null) return true;
    return AppPreferencesScope.read(context).useAnimation;
  }

  @override
  Duration get transitionDuration =>
      _animationsEnabled ? super.transitionDuration : Duration.zero;

  @override
  Duration get reverseTransitionDuration =>
      _animationsEnabled ? super.reverseTransitionDuration : Duration.zero;
}

/// Extension on BuildContext to provide convenient navigation with animation support.
extension AppNavigator on BuildContext {
  /// Push a new page using AppPageRoute which respects the useAnimations flag.
  Future<T?> pushPage<T>(Widget page, {RouteSettings? settings}) {
    return Navigator.push<T>(
      this,
      AppPageRoute<T>(builder: (_) => page, settings: settings),
    );
  }

  /// Push a new page and remove all previous routes.
  Future<T?> pushAndRemoveAllPages<T>(Widget page, {RouteSettings? settings}) {
    return Navigator.pushAndRemoveUntil<T>(
      this,
      AppPageRoute<T>(builder: (_) => page, settings: settings),
      (_) => false,
    );
  }
}

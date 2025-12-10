// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:flutter/material.dart';

/// A custom page route that respects the useAnimations feature flag.
/// When animations are disabled, page transitions happen instantly.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration {
    if (!FeatureFlagService.instance.useAnimations) {
      return Duration.zero;
    }
    return super.transitionDuration;
  }

  @override
  Duration get reverseTransitionDuration {
    if (!FeatureFlagService.instance.useAnimations) {
      return Duration.zero;
    }
    return super.reverseTransitionDuration;
  }
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

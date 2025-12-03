// Test helpers for widget tests
// Provides localization support and common test utilities

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Wraps a widget with MaterialApp and localization support for testing.
/// This ensures that widgets using AppLocalizations.of(context) work correctly.
Widget wrapWithMaterialApp(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  NavigatorObserver? navigatorObserver,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: theme,
    navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
    home: child,
  );
}

/// Wraps a widget with MaterialApp for testing, using Scaffold as parent.
/// Useful for widgets that need a Scaffold ancestor.
Widget wrapWithScaffold(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return wrapWithMaterialApp(
    Scaffold(body: child),
    locale: locale,
    theme: theme,
  );
}

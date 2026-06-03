import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

/// Portal app theme — thin wrapper around `diary_design_system`'s
/// `buildAppTheme`. Kept as a top-level variable for compatibility with
/// existing `MaterialApp(theme: portalTheme)` call sites in main.dart and
/// integration tests; new code should call `buildAppTheme(...)` directly.
///
/// Status colors (active/attention/at-risk/no-data) used to live here as
/// `StatusColors`. They now live in [AppSemanticColors] — read via
/// `Theme.of(context).extension<AppSemanticColors>()`.
final portalTheme = buildAppTheme(
  font: AppFontFamily.inter,
  brightness: Brightness.light,
);

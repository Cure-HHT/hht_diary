import 'package:flutter/material.dart';

// Design: §7.4 palette lock. Tripwire test in styles_test.dart asserts
// every hex value. Palette is at full brightness for readability on a
// black background, with state cues kept distinct (green = sent,
// red = retrying, magenta = wedged, yellow = draining head / selection
// outline, dark navy = cross-panel selection fill).
class DemoColors {
  const DemoColors._();

  static const Color bg = Color(0xFF000000);
  static const Color fg = Color(0xFFFFFFFF);

  static const Color accent = Color(0xFFFFFF00);
  static const Color sent = Color(0xFF00FF00);
  static const Color pending = Color(0xFFCCCCCC);
  static const Color retrying = Color(0xFFFF0000);
  static const Color wedged = Color(0xFFFF00FF);
  static const Color selected = Color(0xFF001A66);
  static const Color selectedOutline = Color(0xFFFFFF00);
  static const Color border = Color(0xFFFFFFFF);

  static const Color red = Color(0xFFFF0000);
  static const Color green = Color(0xFF00FF00);
  static const Color blue = Color(0xFF0066FF);
}

// Design: §7.4 palette lock. Body is 20px bold monospace; headers are
// 24-28px bold monospace in accent yellow.
class DemoText {
  const DemoText._();

  static const double bodyFontSize = 20.0;
  static const double headerFontSize = 24.0;
  static const String fontFamilyMonospace = 'monospace';
  static const FontWeight fontWeight = FontWeight.bold;

  static const TextStyle body = TextStyle(
    fontSize: bodyFontSize,
    fontFamily: fontFamilyMonospace,
    fontWeight: fontWeight,
    color: DemoColors.fg,
  );
  static const TextStyle header = TextStyle(
    fontSize: headerFontSize,
    fontFamily: fontFamilyMonospace,
    fontWeight: fontWeight,
    color: DemoColors.accent,
  );
}

// Design: §7.4 palette lock — 3px white rectangular border on every
// framed panel and button. Rectangular by choice (no borderRadius).
final Border demoBorder = Border.all(color: DemoColors.border, width: 3.0);

// Design: §7.4 palette lock — 2px yellow rectangular outline wrapped
// around the currently selected row so selection remains visible
// against the darker navy selection fill.
final Border demoSelectedBorder = Border.all(
  color: DemoColors.selectedOutline,
  width: 2.0,
);

import 'package:flutter/material.dart';

// Design: §7.4 palette lock. Tripwire test in styles_test.dart asserts
// every hex value; state cues depend on the 12%-below-max brightness
// palette (green = sent, red = retrying, magenta = exhausted, yellow
// = draining head, blue = cross-panel selection).
class DemoColors {
  const DemoColors._();

  static const Color bg = Color(0xFF000000);
  static const Color fg = Color(0xFFFFFFFF);

  static const Color accent = Color(0xFFE0E000);
  static const Color sent = Color(0xFF00E000);
  static const Color pending = Color(0xFFAAAAAA);
  static const Color retrying = Color(0xFFE00000);
  static const Color exhausted = Color(0xFFE000E0);
  static const Color selected = Color(0xFF0044AA);
  static const Color border = Color(0xFFFFFFFF);

  static const Color red = Color(0xFFE00000);
  static const Color green = Color(0xFF00E000);
  static const Color blue = Color(0xFF005AE0);
}

// Design: §7.4 palette lock. Body is 20px monospace; headers 24-28px
// monospace accented yellow.
class DemoText {
  const DemoText._();

  static const double bodyFontSize = 20.0;
  static const double headerFontSize = 24.0;
  static const String fontFamilyMonospace = 'monospace';

  static const TextStyle body = TextStyle(
    fontSize: bodyFontSize,
    fontFamily: fontFamilyMonospace,
    color: DemoColors.fg,
  );
  static const TextStyle header = TextStyle(
    fontSize: headerFontSize,
    fontFamily: fontFamilyMonospace,
    color: DemoColors.accent,
  );
}

// Design: §7.4 palette lock — 3px white rectangular border on every
// framed panel and button. Rectangular by choice (no borderRadius).
final Border demoBorder = Border.all(color: DemoColors.border, width: 3.0);

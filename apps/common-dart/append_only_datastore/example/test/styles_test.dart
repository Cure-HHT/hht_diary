import 'package:append_only_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoColors palette lock', () {
    // Verifies: design §7.4 palette lock — background/foreground baseline.
    test('bg is pure black 0xFF000000', () {
      expect(DemoColors.bg, const Color(0xFF000000));
    });
    test('fg is pure white 0xFFFFFFFF', () {
      expect(DemoColors.fg, const Color(0xFFFFFFFF));
    });

    // Verifies: design §7.4 palette lock — state cues and section accent.
    test('accent is yellow 0xFFE0E000 (section headers, draining head)', () {
      expect(DemoColors.accent, const Color(0xFFE0E000));
    });
    test('sent is green 0xFF00E000', () {
      expect(DemoColors.sent, const Color(0xFF00E000));
    });
    test('pending is grey 0xFFAAAAAA', () {
      expect(DemoColors.pending, const Color(0xFFAAAAAA));
    });
    test('retrying is red 0xFFE00000 (head in transient retry)', () {
      expect(DemoColors.retrying, const Color(0xFFE00000));
    });
    test('exhausted is magenta 0xFFE000E0 (inert row)', () {
      expect(DemoColors.exhausted, const Color(0xFFE000E0));
    });
    test('selected is blue 0xFF0044AA (cross-panel selection tint)', () {
      expect(DemoColors.selected, const Color(0xFF0044AA));
    });
    test('border is white 0xFFFFFFFF', () {
      expect(DemoColors.border, const Color(0xFFFFFFFF));
    });

    // Verifies: design §7.4 palette lock — action-button colors used by
    // the RED/GREEN/BLUE lifecycle buttons.
    test('action red is 0xFFE00000', () {
      expect(DemoColors.red, const Color(0xFFE00000));
    });
    test('action green is 0xFF00E000', () {
      expect(DemoColors.green, const Color(0xFF00E000));
    });
    test('action blue is 0xFF005AE0', () {
      expect(DemoColors.blue, const Color(0xFF005AE0));
    });
  });

  group('DemoText typography lock', () {
    // Verifies: design §7.4 palette lock — body size fixed at 20.
    test('bodyFontSize is 20.0', () {
      expect(DemoText.bodyFontSize, 20.0);
    });
    // Verifies: design §7.4 — header sizes bounded so the top stack plus
    // column headers stay balanced on a desktop window.
    test('headerFontSize is within inclusive [24, 28]', () {
      expect(DemoText.headerFontSize, inInclusiveRange(24.0, 28.0));
    });
    test('fontFamilyMonospace resolves to "monospace"', () {
      expect(DemoText.fontFamilyMonospace, 'monospace');
    });
    test('body TextStyle uses bodyFontSize and monospace family', () {
      expect(DemoText.body.fontSize, DemoText.bodyFontSize);
      expect(DemoText.body.fontFamily, DemoText.fontFamilyMonospace);
    });
    test('header TextStyle uses headerFontSize and monospace family', () {
      expect(DemoText.header.fontSize, DemoText.headerFontSize);
      expect(DemoText.header.fontFamily, DemoText.fontFamilyMonospace);
    });
  });

  group('demoBorder rectangular-border lock', () {
    // Verifies: design §7.4 — 3px rectangular white border for every
    // framed panel / button.
    test('all four sides have width 3.0 and color DemoColors.border', () {
      expect(demoBorder.top.width, 3.0);
      expect(demoBorder.top.color, DemoColors.border);
      expect(demoBorder.bottom.width, 3.0);
      expect(demoBorder.bottom.color, DemoColors.border);
      expect(demoBorder.left.width, 3.0);
      expect(demoBorder.left.color, DemoColors.border);
      expect(demoBorder.right.width, 3.0);
      expect(demoBorder.right.color, DemoColors.border);
    });
    test('demoBorder is a Border (rectangular; no borderRadius concept)', () {
      expect(demoBorder, isA<Border>());
    });
  });
}

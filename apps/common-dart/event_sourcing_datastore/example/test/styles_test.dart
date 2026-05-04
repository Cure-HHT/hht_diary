import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
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

    // Verifies: design §7.4 palette lock — state cues and section accent
    // at full brightness for readability on a black background.
    test('accent is yellow 0xFFFFFF00 (section headers, draining head)', () {
      expect(DemoColors.accent, const Color(0xFFFFFF00));
    });
    test('sent is green 0xFF00FF00', () {
      expect(DemoColors.sent, const Color(0xFF00FF00));
    });
    test('pending is grey 0xFFCCCCCC', () {
      expect(DemoColors.pending, const Color(0xFFCCCCCC));
    });
    test('retrying is red 0xFFFF0000 (head in transient retry)', () {
      expect(DemoColors.retrying, const Color(0xFFFF0000));
    });
    test('wedged is magenta 0xFFFF00FF (inert row)', () {
      expect(DemoColors.wedged, const Color(0xFFFF00FF));
    });
    test('selected is dark navy 0xFF001A66 (cross-panel selection fill)', () {
      expect(DemoColors.selected, const Color(0xFF001A66));
    });
    test('selectedOutline is yellow 0xFFFFFF00 (selection visibility)', () {
      expect(DemoColors.selectedOutline, const Color(0xFFFFFF00));
    });
    test('border is white 0xFFFFFFFF', () {
      expect(DemoColors.border, const Color(0xFFFFFFFF));
    });

    // Verifies: design §7.4 palette lock — action-button colors used by
    // the RED/GREEN/BLUE lifecycle buttons.
    test('action red is 0xFFFF0000', () {
      expect(DemoColors.red, const Color(0xFFFF0000));
    });
    test('action green is 0xFF00FF00', () {
      expect(DemoColors.green, const Color(0xFF00FF00));
    });
    test('action blue is 0xFF0066FF', () {
      expect(DemoColors.blue, const Color(0xFF0066FF));
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
    test('fontWeight is bold', () {
      expect(DemoText.fontWeight, FontWeight.bold);
    });
    test('body TextStyle uses bodyFontSize, monospace family, bold weight', () {
      expect(DemoText.body.fontSize, DemoText.bodyFontSize);
      expect(DemoText.body.fontFamily, DemoText.fontFamilyMonospace);
      expect(DemoText.body.fontWeight, FontWeight.bold);
    });
    test(
      'header TextStyle uses headerFontSize, monospace family, bold weight',
      () {
        expect(DemoText.header.fontSize, DemoText.headerFontSize);
        expect(DemoText.header.fontFamily, DemoText.fontFamilyMonospace);
        expect(DemoText.header.fontWeight, FontWeight.bold);
      },
    );
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

  group('demoSelectedBorder rectangular-outline lock', () {
    // Verifies: design §7.4 — 2px yellow rectangular outline wrapping
    // the selected row so it stays visible against the navy fill.
    test(
      'all four sides have width 2.0 and color DemoColors.selectedOutline',
      () {
        expect(demoSelectedBorder.top.width, 2.0);
        expect(demoSelectedBorder.top.color, DemoColors.selectedOutline);
        expect(demoSelectedBorder.bottom.width, 2.0);
        expect(demoSelectedBorder.bottom.color, DemoColors.selectedOutline);
        expect(demoSelectedBorder.left.width, 2.0);
        expect(demoSelectedBorder.left.color, DemoColors.selectedOutline);
        expect(demoSelectedBorder.right.width, 2.0);
        expect(demoSelectedBorder.right.color, DemoColors.selectedOutline);
      },
    );
    test('demoSelectedBorder is a Border', () {
      expect(demoSelectedBorder, isA<Border>());
    });
  });
}

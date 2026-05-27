// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//
// Verifies: REQ-d00005-A — banner renders when show=true and flavor is recognised
// Verifies: REQ-d00005-B — banner is hidden for prod / unknown flavor / show=false
// Verifies: REQ-d00005-C — child is always wrapped (banner is overlay, not replacement)

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _knownFlavors = ['local', 'dev', 'qa', 'uat'];
const _knownLabels = {'local': 'LOCAL', 'dev': 'DEV', 'qa': 'QA', 'uat': 'UAT'};

Widget _wrap(Widget w) => MaterialApp(home: Material(child: w));

void main() {
  group('EnvironmentBanner — visible cases', () {
    for (final flavor in _knownFlavors) {
      testWidgets('renders ribbon for "$flavor"', (tester) async {
        await tester.pumpWidget(
          _wrap(
            EnvironmentBanner(
              flavorName: flavor,
              show: true,
              child: const Text('app-content'),
            ),
          ),
        );

        expect(find.text('app-content'), findsOneWidget);
        expect(find.text(_knownLabels[flavor]!), findsOneWidget);
        // Ribbon is an overlay, so child must still be in tree
        expect(find.byType(Text), findsAtLeastNWidgets(2));
      });

      testWidgets('"$flavor" is case-insensitive', (tester) async {
        await tester.pumpWidget(
          _wrap(
            EnvironmentBanner(
              flavorName: flavor.toUpperCase(),
              show: true,
              child: const Text('app-content'),
            ),
          ),
        );
        expect(find.text(_knownLabels[flavor]!), findsOneWidget);
      });
    }
  });

  group('EnvironmentBanner — hidden cases', () {
    testWidgets('hides ribbon when show=false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EnvironmentBanner(
            flavorName: 'dev',
            show: false,
            child: Text('app-content'),
          ),
        ),
      );

      expect(find.text('app-content'), findsOneWidget);
      expect(find.text('DEV'), findsNothing);
    });

    testWidgets('hides ribbon for prod', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EnvironmentBanner(
            flavorName: 'prod',
            child: Text('app-content'),
          ),
        ),
      );

      expect(find.text('app-content'), findsOneWidget);
      // No ribbon — no DEV/QA/UAT/LOCAL labels
      for (final label in _knownLabels.values) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('hides ribbon for unknown flavor', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EnvironmentBanner(
            flavorName: 'staging-x',
            child: Text('app-content'),
          ),
        ),
      );

      expect(find.text('app-content'), findsOneWidget);
      for (final label in _knownLabels.values) {
        expect(find.text(label), findsNothing);
      }
    });
  });

  group('EnvironmentBanner — non-interactive overlay', () {
    testWidgets('ribbon does not block taps on child', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          EnvironmentBanner(
            flavorName: 'dev',
            child: Center(
              child: ElevatedButton(
                onPressed: () => taps += 1,
                child: const Text('TAP-ME'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TAP-ME'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('EnvironmentBanner — golden snapshots', () {
    // Run these locally with `flutter test --update-goldens` once and check
    // the resulting PNG into source control. They guard against accidental
    // visual regressions to the ribbon layout.
    for (final flavor in _knownFlavors) {
      testWidgets('golden $flavor', (tester) async {
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 200,
              height: 200,
              child: EnvironmentBanner(
                flavorName: flavor,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ),
        );
        await expectLater(
          find.byType(EnvironmentBanner),
          matchesGoldenFile('goldens/environment_banner_$flavor.png'),
        );
      }, skip: true); // run with --update-goldens to record initial baselines
    }
  });
}

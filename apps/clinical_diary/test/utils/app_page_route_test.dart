// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Set up flavor for tests
  F.appFlavor = Flavor.dev;

  late FeatureFlagService featureFlagService;

  setUp(() {
    featureFlagService = FeatureFlagService.instance..resetToDefaults();
  });

  tearDown(() {
    featureFlagService.resetToDefaults();
  });

  group('AppPageRoute', () {
    group('navigation behavior with animations disabled', () {
      testWidgets('navigates immediately when animations disabled', (
        tester,
      ) async {
        featureFlagService.useAnimations = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      AppPageRoute<void>(
                        builder: (context) =>
                            const Scaffold(body: Text('Destination')),
                      ),
                    );
                  },
                  child: const Text('Navigate'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Navigate'));
        // Just pump once - should be immediate with no animation
        await tester.pump();

        expect(find.text('Destination'), findsOneWidget);
      });

      testWidgets('pops immediately when animations disabled', (tester) async {
        featureFlagService.useAnimations = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      AppPageRoute<void>(
                        builder: (context) => Scaffold(
                          body: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Go Back'),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Navigate'),
                ),
              ),
            ),
          ),
        );

        // Navigate to destination
        await tester.tap(find.text('Navigate'));
        await tester.pump();

        expect(find.text('Go Back'), findsOneWidget);

        // Go back
        await tester.tap(find.text('Go Back'));
        await tester.pump();

        // Should be back immediately
        expect(find.text('Navigate'), findsOneWidget);
      });
    });

    group('navigation behavior with animations enabled', () {
      testWidgets('navigates with animation when animations enabled', (
        tester,
      ) async {
        featureFlagService.useAnimations = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      AppPageRoute<void>(
                        builder: (context) =>
                            const Scaffold(body: Text('Destination')),
                      ),
                    );
                  },
                  child: const Text('Navigate'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Navigate'));
        // Pump partial animation
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        // Should still be animating (both screens may be visible)
        // Complete animation
        await tester.pumpAndSettle();

        // Now only destination should be visible
        expect(find.text('Destination'), findsOneWidget);
      });
    });

    group('route creation', () {
      testWidgets('creates route with builder', (tester) async {
        featureFlagService.useAnimations = false;

        final route = AppPageRoute<String>(
          builder: (context) => const Scaffold(body: Text('Test Page')),
        );

        expect(route, isA<MaterialPageRoute<String>>());
      });

      testWidgets('creates route with settings', (tester) async {
        featureFlagService.useAnimations = false;

        const settings = RouteSettings(name: '/test', arguments: 'arg');

        final route = AppPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Test')),
          settings: settings,
        );

        expect(route.settings.name, '/test');
        expect(route.settings.arguments, 'arg');
      });

      testWidgets('creates fullscreen dialog route', (tester) async {
        featureFlagService.useAnimations = false;

        final route = AppPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Dialog')),
          fullscreenDialog: true,
        );

        expect(route.fullscreenDialog, true);
      });
    });
  });

  group('AppNavigator extension', () {
    testWidgets('pushPage navigates using AppPageRoute', (tester) async {
      featureFlagService.useAnimations = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  context.pushPage<void>(
                    const Scaffold(body: Text('Extension Destination')),
                  );
                },
                child: const Text('Use Extension'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Use Extension'));
      await tester.pump();

      expect(find.text('Extension Destination'), findsOneWidget);
    });

    testWidgets('pushPage with settings', (tester) async {
      featureFlagService.useAnimations = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  context.pushPage<void>(
                    const Scaffold(body: Text('With Settings')),
                    settings: const RouteSettings(name: '/custom'),
                  );
                },
                child: const Text('Navigate'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pump();

      expect(find.text('With Settings'), findsOneWidget);
    });

    testWidgets('pushAndRemoveAllPages clears stack and navigates', (
      tester,
    ) async {
      featureFlagService.useAnimations = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  context.pushAndRemoveAllPages<void>(
                    const Scaffold(body: Text('New Root')),
                  );
                },
                child: const Text('Replace All'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Replace All'));
      await tester.pump();

      expect(find.text('New Root'), findsOneWidget);
      expect(find.text('Replace All'), findsNothing);
    });

    testWidgets('pushPage respects animations flag when enabled', (
      tester,
    ) async {
      featureFlagService.useAnimations = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  context.pushPage<void>(
                    const Scaffold(body: Text('Animated')),
                  );
                },
                child: const Text('Navigate'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Animation in progress - complete it
      await tester.pumpAndSettle();
      expect(find.text('Animated'), findsOneWidget);
    });
  });
}

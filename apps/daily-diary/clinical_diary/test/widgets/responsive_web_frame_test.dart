// Tests for responsive_web_frame.dart
// Covers: Layout wrapper behavior on web and mobile platforms

import 'package:clinical_diary/widgets/responsive_web_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResponsiveWebFrame', () {
    testWidgets('displays child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveWebFrame(child: Text('Test Content')),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('default maxWidth is 540', (tester) async {
      const frame = ResponsiveWebFrame(child: SizedBox());

      expect(frame.maxWidth, 540);
    });

    testWidgets('accepts custom maxWidth', (tester) async {
      const frame = ResponsiveWebFrame(maxWidth: 800, child: SizedBox());

      expect(frame.maxWidth, 800);
    });

    testWidgets('accepts custom backgroundColor', (tester) async {
      const frame = ResponsiveWebFrame(
        backgroundColor: Colors.red,
        child: SizedBox(),
      );

      expect(frame.backgroundColor, Colors.red);
    });

    testWidgets('backgroundColor defaults to null', (tester) async {
      const frame = ResponsiveWebFrame(child: SizedBox());

      expect(frame.backgroundColor, isNull);
    });

    // Note: kIsWeb is a compile-time constant, so we can only test the
    // non-web behavior in unit tests. The web behavior would need
    // integration tests running in a browser.
    testWidgets('on non-web platform, returns child directly', (tester) async {
      // Skip if running on web
      if (kIsWeb) return;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveWebFrame(
              maxWidth: 300,
              backgroundColor: Colors.blue,
              child: Container(
                key: const Key('content'),
                color: Colors.green,
                width: double.infinity,
              ),
            ),
          ),
        ),
      );

      // On non-web, the child should be returned directly
      expect(find.byKey(const Key('content')), findsOneWidget);

      // The container should not be constrained
      final containerSize = tester.getSize(find.byKey(const Key('content')));
      expect(containerSize.width, greaterThan(300));
    });

    testWidgets('child is required', (tester) async {
      // Verify that child is a required parameter
      const frame = ResponsiveWebFrame(child: Text('Required'));

      expect(frame.child, isA<Text>());
    });
  });
}

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(body: child),
  );
}

void main() {
  group('AppBanner', () {
    testWidgets('renders the message', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AppBanner(
            severity: AppBannerSeverity.info,
            message: 'Just FYI',
          ),
        ),
      );
      expect(find.text('Just FYI'), findsOneWidget);
    });

    testWidgets('renders the title above the message when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AppBanner(
            severity: AppBannerSeverity.success,
            title: 'All saved',
            message: 'Your changes are persisted.',
          ),
        ),
      );
      expect(find.text('All saved'), findsOneWidget);
      expect(find.text('Your changes are persisted.'), findsOneWidget);
    });

    testWidgets('uses the canonical icon per severity', (tester) async {
      for (final entry in {
        AppBannerSeverity.success: Icons.check_circle_outline,
        AppBannerSeverity.warning: Icons.warning_amber_outlined,
        AppBannerSeverity.error: Icons.error_outline,
        AppBannerSeverity.info: Icons.info_outline,
      }.entries) {
        await tester.pumpWidget(
          _harness(AppBanner(severity: entry.key, message: 'msg')),
        );
        expect(find.byIcon(entry.value), findsOneWidget);
      }
    });

    testWidgets('renders the trailing slot when provided', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppBanner(
            severity: AppBannerSeverity.warning,
            message: 'Action required',
            trailing: AppButton(
              variant: AppButtonVariant.tertiary,
              size: AppButtonSize.small,
              label: 'Retry',
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
      'semanticId emits Semantics identifier and exposes message via value',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const AppBanner(
              severity: AppBannerSeverity.error,
              message: 'Sign-in failed.',
              semanticId: 'login.error-banner',
            ),
          ),
        );
        final node = tester.getSemantics(find.byType(AppBanner));
        expect(node.identifier, equals('login.error-banner'));
        expect(node.value, equals('Sign-in failed.'));
      },
    );

    testWidgets('no Semantics wrapper when semanticId is null', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AppBanner(
            severity: AppBannerSeverity.info,
            message: 'Just FYI',
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AppBanner));
      expect(node.identifier, isEmpty);
      expect(node.value, isEmpty);
    });
  });
}

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppBreakpoint> _breakpointAt(WidgetTester tester, double width) async {
  late AppBreakpoint observed;
  await tester.binding.setSurfaceSize(Size(width, 800));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Builder(
        builder: (context) {
          observed = context.breakpoint;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return observed;
}

void main() {
  group('AppBreakpoint', () {
    testWidgets('width < 600 is mobile', (tester) async {
      expect(await _breakpointAt(tester, 320), AppBreakpoint.mobile);
      expect(await _breakpointAt(tester, 599), AppBreakpoint.mobile);
    });

    testWidgets('width 600–1023 is tablet', (tester) async {
      expect(await _breakpointAt(tester, 600), AppBreakpoint.tablet);
      expect(await _breakpointAt(tester, 1023), AppBreakpoint.tablet);
    });

    testWidgets('width >= 1024 is desktop', (tester) async {
      expect(await _breakpointAt(tester, 1024), AppBreakpoint.desktop);
      expect(await _breakpointAt(tester, 1920), AppBreakpoint.desktop);
    });
  });

  group('context.responsive', () {
    Future<T> responsiveAt<T>(
      WidgetTester tester,
      double width, {
      required T mobile,
      T? tablet,
      T? desktop,
    }) async {
      late T observed;
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(
            builder: (context) {
              observed = context.responsive(
                mobile: mobile,
                tablet: tablet,
                desktop: desktop,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return observed;
    }

    testWidgets('picks the value for the current tier', (tester) async {
      expect(
        await responsiveAt(tester, 320, mobile: 16, tablet: 24, desktop: 32),
        equals(16),
      );
      expect(
        await responsiveAt(tester, 800, mobile: 16, tablet: 24, desktop: 32),
        equals(24),
      );
      expect(
        await responsiveAt(tester, 1440, mobile: 16, tablet: 24, desktop: 32),
        equals(32),
      );
    });

    testWidgets('falls back upward when a tier is omitted', (tester) async {
      // desktop omitted → falls back to tablet
      expect(
        await responsiveAt(tester, 1440, mobile: 16, tablet: 24),
        equals(24),
      );
      // tablet + desktop omitted → falls back to mobile
      expect(await responsiveAt(tester, 1440, mobile: 16), equals(16));
    });
  });

  group('ResponsiveBuilder', () {
    testWidgets('renders the desktop builder on wide viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 800));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1440, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ResponsiveBuilder(
              mobile: (_) => const Text('M'),
              tablet: (_) => const Text('T'),
              desktop: (_) => const Text('D'),
            ),
          ),
        ),
      );
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('falls back to mobile when desktop/tablet not provided', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 800));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1440, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ResponsiveBuilder(mobile: (_) => const Text('M')),
          ),
        ),
      );
      expect(find.text('M'), findsOneWidget);
    });
  });
}

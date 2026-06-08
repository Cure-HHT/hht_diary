import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppBadge', () {
    testWidgets('renders the label', (tester) async {
      await tester.pumpWidget(_harness(const AppBadge(label: 'Admin')));
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('outlined variant has a transparent background', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AppBadge(
            label: 'CRA',
            variant: AppBadgeVariant.outlined,
            tone: AppBadgeTone.neutral,
          ),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(Colors.transparent));
    });

    testWidgets('filled variant has a non-transparent background', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AppBadge(
            label: 'Admin',
            variant: AppBadgeVariant.filled,
            tone: AppBadgeTone.danger,
          ),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNot(equals(Colors.transparent)));
    });

    testWidgets(
      'tinted variant uses the tone\'s container color for the background',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const AppBadge(
              label: 'Admin',
              variant: AppBadgeVariant.tinted,
              tone: AppBadgeTone.danger,
            ),
          ),
        );
        final BuildContext ctx = tester.element(find.text('Admin'));
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.color,
          equals(Theme.of(ctx).colorScheme.errorContainer),
          reason:
              'Danger-toned tinted badge must use colorScheme.errorContainer '
              'for the soft pink fill that surrounds the dark label.',
        );
      },
    );

    testWidgets('tinted variant keeps the dark accent for the border + label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AppBadge(
            label: 'Admin',
            variant: AppBadgeVariant.tinted,
            tone: AppBadgeTone.danger,
          ),
        ),
      );
      final BuildContext ctx = tester.element(find.text('Admin'));
      final container = tester.widget<Container>(find.byType(Container));
      final border = (container.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, equals(Theme.of(ctx).colorScheme.error));
    });

    testWidgets('renders trailing widget inside the pill', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AppBadge(
            label: 'Admin',
            tone: AppBadgeTone.danger,
            trailing: Icon(Icons.expand_more),
          ),
        ),
      );
      expect(find.text('Admin'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('tapping the pill with onTap set fires the callback', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          AppBadge(
            label: 'Admin',
            tone: AppBadgeTone.danger,
            trailing: const Icon(Icons.expand_more),
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Admin'));
      expect(taps, 1);
    });

    testWidgets(
      'onTap == null leaves the pill as a passive label — no InkWell',
      (tester) async {
        await tester.pumpWidget(
          _harness(const AppBadge(label: 'CRA', tone: AppBadgeTone.neutral)),
        );
        // No ripple machinery in the passive case.
        expect(find.byType(InkWell), findsNothing);
      },
    );

    testWidgets(
      'interactive pill exposes button semantics announcing the label',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            AppBadge(label: 'Admin', tone: AppBadgeTone.danger, onTap: () {}),
          ),
        );
        expect(
          find.bySemanticsLabel('Admin'),
          findsOneWidget,
          reason:
              'When onTap is set the pill must be reachable as a button '
              'by assistive tech.',
        );
      },
    );

    testWidgets(
      'semanticId emits a Semantics identifier with label exposed via value',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const AppBadge(label: 'Admin', semanticId: 'user.role-badge'),
          ),
        );
        final node = tester.getSemantics(find.byType(AppBadge));
        expect(node.identifier, equals('user.role-badge'));
        expect(node.value, equals('Admin'));
      },
    );
  });
}

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

Widget _harness(Widget child) => MaterialApp(
  theme: buildAppTheme(font: AppFontFamily.inter),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('PortalRole.fromSystemName', () {
    test('resolves known canonical names', () {
      expect(
        PortalRole.fromSystemName('Administrator'),
        equals(PortalRole.administrator),
      );
      expect(
        PortalRole.fromSystemName('StudyCoordinator'),
        equals(PortalRole.studyCoordinator),
      );
      expect(PortalRole.fromSystemName('CRA'), equals(PortalRole.cra));
      expect(
        PortalRole.fromSystemName('SystemOperator'),
        equals(PortalRole.systemOperator),
      );
    });

    test('returns null for unknown names so the widget can fall back', () {
      expect(PortalRole.fromSystemName('UnknownRole'), isNull);
      expect(PortalRole.fromSystemName(''), isNull);
    });
  });

  group('RolePill', () {
    testWidgets('known role + displayName renders the sponsor label, not the '
        'canonical one', (tester) async {
      await tester.pumpWidget(
        _harness(
          const RolePill(
            systemRole: 'StudyCoordinator',
            displayName: 'Site Study Coordinator',
          ),
        ),
      );
      expect(find.text('Site Study Coordinator'), findsOneWidget);
      expect(find.text('Study Coordinator'), findsNothing);
    });

    testWidgets(
      'known role without displayName falls back to canonicalDisplayName',
      (tester) async {
        await tester.pumpWidget(
          _harness(const RolePill(systemRole: 'StudyCoordinator')),
        );
        expect(find.text('Study Coordinator'), findsOneWidget);
      },
    );

    testWidgets(
      'unknown role preserves the raw systemRole string so projection '
      'drift is visible rather than blanked',
      (tester) async {
        await tester.pumpWidget(
          _harness(const RolePill(systemRole: 'NewRoleFromBackend')),
        );
        expect(find.text('NewRoleFromBackend'), findsOneWidget);
      },
    );

    testWidgets('onTap turns the pill into a button reachable to a11y', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(RolePill(systemRole: 'Administrator', onTap: () => taps++)),
      );
      await tester.tap(find.text('Administrator'));
      expect(taps, 1);
    });

    testWidgets('passive pill (no onTap) has no InkWell', (tester) async {
      await tester.pumpWidget(_harness(const RolePill(systemRole: 'CRA')));
      expect(find.byType(InkWell), findsNothing);
    });
  });
}

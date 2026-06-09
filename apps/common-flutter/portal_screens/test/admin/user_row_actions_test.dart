import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

UserRowActionsConfig _config({
  void Function(PortalUserView, UserRowAction)? onAction,
  bool all = true,
  Set<String> inviteSent = const <String>{},
}) => UserRowActionsConfig(
  onAction: onAction ?? (_, _) {},
  canEdit: all,
  canDeactivate: all,
  canReactivate: all,
  canResendInvite: all,
  canUnlock: all,
  inviteSentEmails: inviteSent,
);

void main() {
  group('UserRowActionsConfig.itemsFor', () {
    test('active user: details / edit / deactivate', () {
      expect(_config().itemsFor(MockData.adminUser), const [
        UserRowAction.viewDetails,
        UserRowAction.edit,
        UserRowAction.deactivate,
      ]);
    });

    test('pending user adds resend invite, in Figma order', () {
      expect(_config().itemsFor(MockData.jenniferMartinezPending), const [
        UserRowAction.viewDetails,
        UserRowAction.edit,
        UserRowAction.resendInvite,
        UserRowAction.deactivate,
      ]);
    });

    test('revoked user: details / reactivate only', () {
      expect(_config().itemsFor(MockData.sarahJohnsonInactive), const [
        UserRowAction.viewDetails,
        UserRowAction.reactivate,
      ]);
    });

    test('locked user: details / unlock only', () {
      expect(_config().itemsFor(MockData.lockedUser), const [
        UserRowAction.viewDetails,
        UserRowAction.unlock,
      ]);
    });

    test('without capabilities only View Details remains', () {
      final items = _config(all: false).itemsFor(MockData.adminUser);
      expect(items, const [UserRowAction.viewDetails]);
    });

    test('operator-tier target offers View Details only unless the viewer '
        'can manage the operator tier', () {
      const sysop = PortalUserView(
        email: 'sysop@x.io',
        name: 'Sys Op',
        status: UserStatusView.active,
        assignments: [
          RoleAssignmentView(
            role: 'SystemOperator',
            boundSites: [],
            isWildcard: true,
          ),
        ],
      );
      // Admin viewer (all capability flags, but no operator-tier
      // management): the server would deny every action -> hide them.
      expect(_config().itemsFor(sysop), const [UserRowAction.viewDetails]);

      // SystemOperator viewer: full status-legal menu.
      final operatorViewer = UserRowActionsConfig(
        onAction: (_, _) {},
        canEdit: true,
        canDeactivate: true,
        canManageOperatorTier: true,
      );
      expect(operatorViewer.itemsFor(sysop), const [
        UserRowAction.viewDetails,
        UserRowAction.edit,
        UserRowAction.deactivate,
      ]);
    });

    test('own row never offers Edit or Deactivate '
        '(DIARY-GUI-user-information-modal/K)', () {
      final config = UserRowActionsConfig(
        onAction: (_, _) {},
        canEdit: true,
        canDeactivate: true,
        currentUserEmail: MockData.adminUser.email,
      );
      expect(config.itemsFor(MockData.adminUser), const [
        UserRowAction.viewDetails,
      ]);
      // Other rows are unaffected.
      expect(config.itemsFor(MockData.sarahJohnson), const [
        UserRowAction.viewDetails,
        UserRowAction.edit,
        UserRowAction.deactivate,
      ]);
    });
  });

  group('UserRowMenu', () {
    Future<void> pumpMenu(
      WidgetTester tester, {
      required PortalUserView user,
      required UserRowActionsConfig config,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: UserRowMenu(user: user, config: config),
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('opens and fires onAction for a tapped item', (tester) async {
      final fired = <UserRowAction>[];
      await pumpMenu(
        tester,
        user: MockData.adminUser,
        config: _config(onAction: (_, a) => fired.add(a)),
      );
      expect(find.text('View Details'), findsOneWidget);
      expect(find.text('Edit User'), findsOneWidget);
      await tester.tap(find.text('Deactivate User'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fired, const [UserRowAction.deactivate]);
    });

    testWidgets('invite-sent pending row disables resend as "Invite Sent"', (
      tester,
    ) async {
      final fired = <UserRowAction>[];
      await pumpMenu(
        tester,
        user: MockData.jenniferMartinezPending,
        config: _config(
          onAction: (_, a) => fired.add(a),
          inviteSent: {MockData.jenniferMartinezPending.email},
        ),
      );
      expect(find.text('Resend Invite'), findsNothing);
      expect(find.text('Invite Sent'), findsOneWidget);
      await tester.tap(find.text('Invite Sent'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(fired, isEmpty);
    });

    testWidgets('deactivate renders in the error color', (tester) async {
      await pumpMenu(tester, user: MockData.adminUser, config: _config());
      final text = tester.widget<Text>(find.text('Deactivate User'));
      final theme = buildAppTheme(font: AppFontFamily.inter);
      expect(text.style?.color, theme.colorScheme.error);
    });
  });
}

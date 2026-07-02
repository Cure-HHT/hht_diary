import 'dart:async';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

const _sites = <SiteOptionView>[
  SiteOptionView(id: 'S-001', number: '001', name: 'Memorial Hospital'),
  SiteOptionView(id: 'S-002', number: '002', name: 'Stanford Medical Center'),
];

Future<void> _pumpDialog(WidgetTester tester, Widget dialog) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(font: AppFontFamily.inter),
      home: Scaffold(body: Center(child: dialog)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('UserDetailsDialog', () {
    testWidgets('renders identity, roles, bound sites and pops the picked '
        'action', (tester) async {
      UserRowAction? popped;
      await _pumpDialog(
        tester,
        Builder(
          builder: (context) => AppButton(
            label: 'open',
            onPressed: () async {
              popped = await UserDetailsDialog.show(
                context,
                user: MockData.sarahJohnson,
                sites: _sites,
                actions: const [
                  UserRowAction.viewDetails,
                  UserRowAction.edit,
                  UserRowAction.deactivate,
                ],
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Dr. Sarah Johnson'), findsOneWidget);
      expect(find.text('sjohnson@clinicaltrial.com'), findsOneWidget);
      expect(find.text('Study Coordinator'), findsOneWidget);
      expect(find.text('001 - Memorial Hospital'), findsOneWidget);
      // viewDetails is filtered out of the action list — we're already here.
      expect(find.text('View Details'), findsNothing);

      await tester.tap(find.text('Edit User'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(popped, UserRowAction.edit);
    });

    testWidgets('wildcard scope renders "All sites"; pending shows status '
        'badge', (tester) async {
      await _pumpDialog(
        tester,
        UserDetailsDialog(
          user: MockData.jenniferMartinezPending,
          sites: _sites,
          actions: const [UserRowAction.resendInvite],
        ),
      );
      expect(find.text('Pending'), findsOneWidget);

      await _pumpDialog(
        tester,
        UserDetailsDialog(
          user: MockData.adminUser,
          sites: const [],
          actions: const [],
        ),
      );
      expect(find.text('All sites'), findsOneWidget);
    });

    testWidgets('active user shows the Active status badge in the '
        'identity card', (tester) async {
      await _pumpDialog(
        tester,
        UserDetailsDialog(
          user: MockData.sarahJohnson,
          sites: _sites,
          actions: const [],
        ),
      );
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('invite-sent renders the resend row disabled', (tester) async {
      await _pumpDialog(
        tester,
        UserDetailsDialog(
          user: MockData.jenniferMartinezPending,
          sites: _sites,
          actions: const [UserRowAction.resendInvite],
          inviteSent: true,
        ),
      );
      expect(find.text('Resend Invite'), findsNothing);
      expect(find.text('Invite Sent'), findsOneWidget);
    });

    // Verifies: DIARY-GUI-user-information-modal/N — Figma title is
    //   "User Information".
    // Verifies: DIARY-GUI-user-information-modal/O — each action carries a
    //   visible icon; Resend Invite + Deactivate render their bundled Figma
    //   PNG glyphs (regression for the blank Deactivate ban icon, CUR-1525).
    testWidgets('titled "User Information"; Resend + Deactivate show their '
        'Figma PNG icons', (tester) async {
      await _pumpDialog(
        tester,
        UserDetailsDialog(
          user: MockData.jenniferMartinezPending,
          sites: _sites,
          actions: const [
            UserRowAction.edit,
            UserRowAction.resendInvite,
            UserRowAction.deactivate,
          ],
        ),
      );
      expect(find.text('User Information'), findsOneWidget);
      expect(find.text('User Details'), findsNothing);
      expect(find.text('Edit User'), findsOneWidget);
      expect(find.text('Deactivate User'), findsOneWidget);
      // Resend Invite + Deactivate render bundled PNG glyphs (Image.asset);
      // Edit keeps its MaterialIcons pencil. No action row is left iconless.
      expect(find.byType(Image), findsNWidgets(2));
    });
  });

  group('splitDisplayName', () {
    test('first token vs remainder; round-trips the composed form', () {
      expect(splitDisplayName('Emily Parker'), ('Emily', 'Parker'));
      expect(splitDisplayName('Dr. Emily Parker'), ('Dr.', 'Emily Parker'));
      expect(splitDisplayName('Cher'), ('Cher', ''));
      expect(splitDisplayName('  Emily  Parker '), ('Emily', 'Parker'));
    });
  });

  group('UserFormDialog', () {
    Widget form({
      Future<String?> Function(UserFormData)? onSubmit,
      String? warning,
      Set<String> initialRoles = const <String>{},
      Set<String> initialSites = const <String>{},
      String initialFirstName = '',
      String initialLastName = '',
      String initialEmail = '',
    }) => UserFormDialog(
      title: 'Create User',
      subtitle: 'sub',
      submitLabel: 'Confirm',
      roleOptions: const ['Administrator', 'StudyCoordinator', 'CRA'],
      siteScopedRoles: const {'StudyCoordinator', 'CRA'},
      siteOptions: _sites,
      warning: warning,
      initialFirstName: initialFirstName,
      initialLastName: initialLastName,
      initialEmail: initialEmail,
      initialRoles: initialRoles,
      initialSites: initialSites,
      onSubmit: onSubmit ?? (_) async => null,
    );

    testWidgets('submit stays disabled until name, email and a role are set; '
        'site-scoped roles also require a site', (tester) async {
      await _pumpDialog(tester, form());

      AppButton submit() =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'Confirm'));
      expect(submit().onPressed, isNull);

      await tester.enterText(find.byType(TextFormField).at(0), 'Emily');
      await tester.enterText(find.byType(TextFormField).at(1), 'Parker');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'eparker@clinicaltrial.com',
      );
      await tester.pump();
      expect(submit().onPressed, isNull); // no role yet

      await tester.tap(find.text('Administrator'));
      await tester.pump();
      expect(submit().onPressed, isNotNull); // non-site role suffices

      await tester.tap(find.text('CRA'));
      await tester.pump();
      // Site-scoped role selected, no site -> blocked again, and the
      // checklist appeared.
      expect(submit().onPressed, isNull);
      expect(
        find.textContaining('Assigned Sites', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.text('001 - Memorial Hospital'));
      await tester.pump();
      expect(submit().onPressed, isNotNull);
    });

    // Verifies: DIARY-PRD-user-account-create/A — selecting a site-scoped role
    //   with no Site blocks Save AND shows a clear inline error message (not
    //   just a silently disabled button).
    testWidgets('site-scoped role with no site shows an inline error and '
        'blocks submit', (tester) async {
      await _pumpDialog(
        tester,
        form(
          initialFirstName: 'Emily',
          initialLastName: 'Parker',
          initialEmail: 'eparker@clinicaltrial.com',
        ),
      );
      AppButton submit() =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'Confirm'));

      await tester.tap(find.text('StudyCoordinator'));
      await tester.pump();
      expect(submit().onPressed, isNull);
      expect(
        find.text('Select at least one site for the selected role.'),
        findsOneWidget,
      );

      await tester.tap(find.text('001 - Memorial Hospital'));
      await tester.pump();
      expect(
        find.text('Select at least one site for the selected role.'),
        findsNothing,
      );
      expect(submit().onPressed, isNotNull);
    });

    // Verifies: DIARY-PRD-user-account-edit/C — editing a site-scoped user down
    //   to zero Sites (removing their last Site) blocks Save and surfaces the
    //   inline error. Client guard for the "SC/CRA need >=1 Site" invariant.
    testWidgets('editing a site-scoped user to zero sites blocks Save and '
        'shows the inline error', (tester) async {
      await _pumpDialog(
        tester,
        form(
          initialFirstName: 'Sarah',
          initialLastName: 'Johnson',
          initialEmail: 'sjohnson@clinicaltrial.com',
          initialRoles: const {'StudyCoordinator'},
          initialSites: const {'S-001'},
        ),
      );
      AppButton submit() =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'Confirm'));
      expect(submit().onPressed, isNotNull);

      // Uncheck the only assigned site -> last Site removed.
      await tester.tap(find.text('001 - Memorial Hospital'));
      await tester.pump();
      expect(submit().onPressed, isNull);
      expect(
        find.text('Select at least one site for the selected role.'),
        findsOneWidget,
      );
    });

    testWidgets('malformed email blocks submit and shows the inline error '
        'until corrected', (tester) async {
      await _pumpDialog(
        tester,
        form(
          initialFirstName: 'Emily',
          initialLastName: 'Parker',
          initialRoles: const {'Administrator'},
        ),
      );
      AppButton submit() =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'Confirm'));

      await tester.enterText(find.byType(TextFormField).at(2), 'not-an-email');
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(submit().onPressed, isNull);

      await tester.enterText(
        find.byType(TextFormField).at(2),
        'eparker@clinicaltrial.com',
      );
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsNothing);
      expect(submit().onPressed, isNotNull);
    });

    testWidgets('onSubmit error renders banner and keeps the form open', (
      tester,
    ) async {
      await _pumpDialog(
        tester,
        form(
          initialFirstName: 'X',
          initialLastName: 'Y',
          initialEmail: 'x@y.z',
          initialRoles: const {'Administrator'},
          onSubmit: (_) async => 'Create denied: denied (portal.user.create)',
        ),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Confirm'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.text('Create denied: denied (portal.user.create)'),
        findsOneWidget,
      );
      expect(find.byType(UserFormDialog), findsOneWidget);
    });

    testWidgets('inputs disable while submitting', (tester) async {
      final gate = Completer<String?>();
      await _pumpDialog(
        tester,
        form(
          initialFirstName: 'X',
          initialLastName: 'Y',
          initialEmail: 'x@y.z',
          initialRoles: const {'Administrator'},
          onSubmit: (_) => gate.future,
        ),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Confirm'));
      await tester.pump(const Duration(milliseconds: 50));

      final cancel = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Cancel'),
      );
      expect(cancel.onPressed, isNull);
      // Release the gate so no pending timers leak.
      gate.complete('e');
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('warning banner renders for the edit variant', (tester) async {
      await _pumpDialog(tester, form(warning: 'Active sessions will end.'));
      expect(find.text('Active sessions will end.'), findsOneWidget);
    });

    testWidgets('submitted data carries trimmed fields and selections', (
      tester,
    ) async {
      UserFormData? seen;
      await _pumpDialog(
        tester,
        form(
          initialFirstName: ' Dr. ',
          initialLastName: ' Emily Parker ',
          initialEmail: ' eparker@clinicaltrial.com ',
          initialRoles: const {'StudyCoordinator'},
          initialSites: const {'S-002'},
          onSubmit: (d) async {
            seen = d;
            return null;
          },
        ),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Confirm'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(seen, isNotNull);
      expect(seen!.name, 'Dr. Emily Parker');
      expect(seen!.email, 'eparker@clinicaltrial.com');
      expect(seen!.roles, {'StudyCoordinator'});
      expect(seen!.sites, {'S-002'});
    });
  });

  group('Deactivate / Reactivate dialogs', () {
    testWidgets('deactivate: confirm gated on reason; error stays open', (
      tester,
    ) async {
      final submitted = <String>[];
      var fail = true;
      await _pumpDialog(
        tester,
        DeactivateUserDialog(
          userName: 'Dr. Sarah Johnson',
          onSubmit: (reason) async {
            submitted.add(reason);
            return fail ? 'denied (portal.user.deactivate)' : null;
          },
        ),
      );
      expect(find.textContaining('Dr. Sarah Johnson'), findsOneWidget);
      expect(find.text('Effects of this action:'), findsOneWidget);

      AppButton confirm() =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'Confirm'));
      expect(confirm().onPressed, isNull);
      // Figma: the lifecycle confirms use the primary (navy) button; the
      // destructive consequences are conveyed by the red effects panel.
      expect(confirm().variant, AppButtonVariant.primary);

      await tester.enterText(find.byType(TextFormField), 'offboarded');
      await tester.pump();
      expect(confirm().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(AppButton, 'Confirm'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(submitted, ['offboarded']);
      expect(find.text('denied (portal.user.deactivate)'), findsOneWidget);

      fail = false;
      await tester.tap(find.widgetWithText(AppButton, 'Confirm'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(submitted, hasLength(2));
    });

    testWidgets('reason input is capped at 100 characters '
        '(DIARY-PRD-reason-field-constraints/B)', (tester) async {
      String? seenReason;
      await _pumpDialog(
        tester,
        DeactivateUserDialog(
          userName: 'X',
          onSubmit: (reason) async {
            seenReason = reason;
            return null;
          },
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'a' * 150);
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Confirm'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(seenReason, 'a' * 100);
    });

    testWidgets('reason field renders the live 0/100 counter and the '
        'back-link pops then invokes onBack', (tester) async {
      var wentBack = false;
      await _pumpDialog(
        tester,
        Builder(
          builder: (context) => AppButton(
            label: 'open',
            onPressed: () => DeactivateUserDialog.show(
              context,
              userName: 'X',
              onSubmit: (_) async => null,
              onBack: () => wentBack = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('0/100'), findsOneWidget);
      expect(find.text('← User Information'), findsOneWidget);

      await tester.tap(find.text('← User Information'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(wentBack, isTrue);
      expect(find.byType(DeactivateUserDialog), findsNothing);
    });

    testWidgets('reactivate: primary confirm + info effects panel', (
      tester,
    ) async {
      String? seenReason;
      await _pumpDialog(
        tester,
        ReactivateUserDialog(
          userName: 'Dr. Sarah Johnson',
          onSubmit: (reason) async {
            seenReason = reason;
            return null;
          },
        ),
      );
      final confirm = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Confirm'),
      );
      expect(confirm.variant, AppButtonVariant.primary);

      await tester.enterText(find.byType(TextFormField), 're-joined study');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Confirm'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(seenReason, 're-joined study');
    });
  });
}

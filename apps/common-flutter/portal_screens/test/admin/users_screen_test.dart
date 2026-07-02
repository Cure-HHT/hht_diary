import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<PortalUserView> users,
  bool canCreate = true,
  bool isLoading = false,
  VoidCallback? onCreate,
  int pageSize = 8,
  UserRowActionsConfig? rowActions,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(font: AppFontFamily.inter),
      home: Scaffold(
        body: UsersScreen(
          users: users,
          isLoading: isLoading,
          canCreate: canCreate,
          onCreate: onCreate ?? () {},
          pageSize: pageSize,
          rowActions: rowActions,
        ),
      ),
    ),
  );
  // Avoid pumpAndSettle — Tooltip's animation controller and the
  // loading-state CircularProgressIndicator both keep the frame
  // scheduler busy indefinitely. A small fixed pump is enough for
  // layout to stabilise; individual tests can pump further for
  // debounced search input etc.
  await tester.pump(const Duration(milliseconds: 50));
}

/// Each AppTableTab label appears once in the strip and a second time
/// in any StatusBadge cell that renders the same word. Tapping by raw
/// label text is ambiguous — this finder scopes the tap to the tab
/// strip via the surrounding [AppTableTabs] widget.
Finder _statusTab(String label) =>
    find.descendant(of: find.byType(AppTableTabs), matching: find.text(label));

void main() {
  group('UsersScreen — header', () {
    testWidgets('renders title + subtitle', (tester) async {
      await _pump(tester, users: MockData.users);
      expect(find.text('User Management'), findsOneWidget);
      expect(find.textContaining('Manage portal users'), findsOneWidget);
    });

    testWidgets('Create User CTA hidden when canCreate is false', (
      tester,
    ) async {
      await _pump(tester, users: MockData.users, canCreate: false);
      expect(find.text('Create User'), findsNothing);
    });

    testWidgets('Create User CTA fires onCreate', (tester) async {
      var creates = 0;
      await _pump(tester, users: MockData.users, onCreate: () => creates++);
      await tester.tap(find.text('Create User'));
      await tester.pump();
      expect(creates, 1);
    });
  });

  group('UsersScreen — status filter', () {
    testWidgets('All users tab counts every user, including locked', (
      tester,
    ) async {
      await _pump(tester, users: MockData.users);
      // "All users <N>" must appear on the All tab — assert against the
      // live fixture length rather than a hard-coded number so adding
      // more sample users doesn't require updating this test.
      expect(find.text(MockData.users.length.toString()), findsWidgets);
    });

    testWidgets('Inactive filter shows only revoked users — Q13', (
      tester,
    ) async {
      await _pump(tester, users: MockData.users);
      await tester.tap(_statusTab('Inactive'));
      await tester.pump();

      // sarahJohnsonInactive's email should be visible
      expect(find.text('sjohnson-old@clinicaltrial.com'), findsOneWidget);
      // Locked user must NOT appear in the Inactive tab
      expect(find.text('locked@clinicaltrial.com'), findsNothing);
      // Active users gone
      expect(find.text('admin@clinicaltrial.com'), findsNothing);
    });

    testWidgets('Pending filter narrows to pending users only', (tester) async {
      await _pump(tester, users: MockData.users);
      await tester.tap(_statusTab('Pending'));
      await tester.pump();
      expect(find.text('jmartinez@clinicaltrial.com'), findsOneWidget);
      expect(find.text('newinvite@clinicaltrial.com'), findsOneWidget);
      expect(find.text('admin@clinicaltrial.com'), findsNothing);
    });
  });

  group('UsersScreen — search', () {
    // Verifies: DIARY-GUI-user-management-tabs/H
    testWidgets('search input hint reads "Search by name or email"', (
      tester,
    ) async {
      await _pump(tester, users: MockData.users);
      expect(find.text('Search by name or email'), findsOneWidget);
    });

    // Verifies: DIARY-GUI-user-management-tabs/H+I
    testWidgets('email substring filter narrows the visible rows', (
      tester,
    ) async {
      await _pump(tester, users: MockData.users);
      await tester.enterText(find.byType(TextFormField), 'sjohnson');
      // AppTextField.search debounces 300ms; pump past it.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('sjohnson@clinicaltrial.com'), findsOneWidget);
      expect(find.text('sjohnson-old@clinicaltrial.com'), findsOneWidget);
      expect(find.text('admin@clinicaltrial.com'), findsNothing);
    });

    // Verifies: DIARY-GUI-user-management-tabs/H+I
    testWidgets('full-name substring filter matches on the name column', (
      tester,
    ) async {
      // "emily" appears in the display name "Dr. Emily Parker" but NOT in
      // the email "eparker@clinicaltrial.com" — so a match here proves the
      // predicate searches the full name, not just the email.
      await _pump(tester, users: MockData.users);
      await tester.enterText(find.byType(TextFormField), 'emily');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('eparker@clinicaltrial.com'), findsOneWidget);
      expect(find.text('admin@clinicaltrial.com'), findsNothing);
    });

    // Verifies: DIARY-GUI-user-management-tabs/H+I
    testWidgets('name search is case-insensitive', (tester) async {
      // "EMILY" upper-cased still matches "Dr. Emily Parker" (and never the
      // "eparker" email), proving the name match folds case.
      await _pump(tester, users: MockData.users);
      await tester.enterText(find.byType(TextFormField), 'EMILY');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('eparker@clinicaltrial.com'), findsOneWidget);
      expect(find.text('admin@clinicaltrial.com'), findsNothing);
    });

    testWidgets('search resets pagination to page 1', (tester) async {
      // Pump enough users that page 2 exists.
      final users = List.generate(
        20,
        (i) => PortalUserView(
          email: 'user-${i.toString().padLeft(2, "0")}@example.com',
          name: 'User $i',
          status: UserStatusView.active,
          assignments: const [],
        ),
      );
      await _pump(tester, users: users, pageSize: 8);

      // Sanity: first page shows user-00.
      expect(find.text('user-00@example.com'), findsOneWidget);

      // Type a query that matches a single later user.
      await tester.enterText(find.byType(TextFormField), 'user-15');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // Filtered result fits on page 1 — must NOT be hidden by a stale
      // _page > 1 carried over from the un-searched view.
      expect(find.text('user-15@example.com'), findsOneWidget);
    });
  });

  group('UsersScreen — pagination', () {
    testWidgets('first page slices to the configured page size and shows the '
        'pagination range', (tester) async {
      final users = List.generate(
        20,
        (i) => PortalUserView(
          email: 'user-${i.toString().padLeft(2, "0")}@example.com',
          name: 'User $i',
          status: UserStatusView.active,
          assignments: const [],
        ),
      );
      await _pump(tester, users: users, pageSize: 8);

      // user-07 is the 8th alphabetical → still on page 1.
      expect(find.text('user-07@example.com'), findsOneWidget);
      // user-08 spills onto page 2.
      expect(find.text('user-08@example.com'), findsNothing);

      // Header reflects the range.
      expect(find.textContaining('Viewing 1-8 of 20'), findsOneWidget);
    });
  });

  group('UsersScreen — rendering', () {
    testWidgets('shows wildcard scope as "All sites"', (tester) async {
      await _pump(tester, users: const [MockData.adminUser]);
      expect(find.text('All sites'), findsOneWidget);
    });

    testWidgets(
      'shows "N sites assigned" with a Tooltip carrying the bound site '
      'ids when not wildcard',
      (tester) async {
        await _pump(tester, users: const [MockData.sarahJohnson]);
        expect(find.text('2 sites assigned'), findsOneWidget);
        // Multiple Tooltip widgets exist in the tree (the Create User
        // AppButton wraps one). Pick the Tooltip that's an ancestor of
        // the sites cell's Text — that's the one we care about.
        final sitesTooltip = tester.widget<Tooltip>(
          find
              .ancestor(
                of: find.text('2 sites assigned'),
                matching: find.byType(Tooltip),
              )
              .first,
        );
        expect(sitesTooltip.message, contains('site-1'));
        expect(sitesTooltip.message, contains('site-2'));
      },
    );

    testWidgets('roles column dedupes per user — one chip per distinct role', (
      tester,
    ) async {
      // emilyParker has Administrator + StudyCoordinator (one of each).
      // The chip pill labels render the canonical display names.
      await _pump(tester, users: const [MockData.emilyParker]);
      expect(find.text('Administrator'), findsOneWidget);
      expect(find.text('Study Coordinator'), findsOneWidget);
    });

    testWidgets('empty filtered set surfaces the empty-state copy', (
      tester,
    ) async {
      await _pump(tester, users: MockData.users);
      await tester.enterText(find.byType(TextFormField), 'no-match-anywhere');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.textContaining('No users match'), findsOneWidget);
    });

    testWidgets('isLoading propagates to AppDataTable spinner', (tester) async {
      await _pump(tester, users: const [], isLoading: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('UsersScreen — Playwright instrumentation', () {
    testWidgets('chrome and row kebabs carry semantics identifiers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        users: MockData.users,
        rowActions: UserRowActionsConfig(onAction: (_, _) {}),
      );

      expect(find.bySemanticsIdentifier('users-search'), findsOneWidget);
      expect(find.bySemanticsIdentifier('users-pagination'), findsOneWidget);
      expect(find.bySemanticsIdentifier('users-status-tabs'), findsOneWidget);
      expect(find.bySemanticsIdentifier('users-create'), findsOneWidget);
      // Kebabs are domain-keyed by the row's email — never positional
      // (the list reorders under filters and sorts).
      expect(
        find.bySemanticsIdentifier(
          'user-actions-${MockData.users.first.email}',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('open kebab menu items carry user-action-* identifiers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        users: MockData.users,
        rowActions: UserRowActionsConfig(onAction: (_, _) {}, canEdit: true),
      );

      await tester.tap(
        find.bySemanticsIdentifier(
          'user-actions-${MockData.users.first.email}',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.bySemanticsIdentifier('user-action-viewDetails'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('UsersScreen — row action menu', () {
    // No REQ assertion covers the kebab popover's open/close arbitration;
    // this guards the CUR-1595 fix — opening one row's menu must close any
    // other, so only one popover is ever visible at a time.
    testWidgets('opening a second row menu closes the first', (tester) async {
      // A popover opens just below its kebab and can overlap the
      // immediately-adjacent row, so the two rows under test are kept
      // non-adjacent (sorted by email: a, m, z) and each menu carries a
      // single item — this keeps row Z's kebab clear of row A's popover so
      // the second tap reliably reaches it.
      const rowA = PortalUserView(
        email: 'a-user@clinicaltrial.com',
        name: 'A User',
        status: UserStatusView.active,
        assignments: [],
      );
      const rowMid = PortalUserView(
        email: 'm-user@clinicaltrial.com',
        name: 'M User',
        status: UserStatusView.active,
        assignments: [],
      );
      const rowZ = PortalUserView(
        email: 'z-user@clinicaltrial.com',
        name: 'Z User',
        status: UserStatusView.active,
        assignments: [],
      );
      final handle = tester.ensureSemantics();
      // No capability flags → each row menu shows only "View Details".
      await _pump(
        tester,
        users: const [rowA, rowMid, rowZ],
        rowActions: UserRowActionsConfig(onAction: (_, _) {}),
      );

      // Open row A's menu — its single item (View Details) is visible.
      await tester.tap(
        find.bySemanticsIdentifier('user-actions-${rowA.email}'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.bySemanticsIdentifier('user-action-viewDetails'),
        findsOneWidget,
      );

      // Open row Z's menu — row A's popover must close, leaving exactly one
      // open menu (not two stacked popovers). Two open menus would surface
      // two 'user-action-viewDetails' nodes.
      await tester.tap(
        find.bySemanticsIdentifier('user-actions-${rowZ.email}'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.bySemanticsIdentifier('user-action-viewDetails'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}

// Verifies: DIARY-GUI-audit-log-common/A+B+E
//
// AuditLogsScreen is a CONTROLLED, server-paged table: it renders exactly
// the page of entries it is handed, reports the server's true total in the
// pagination header (never the in-hand row count), and surfaces every
// navigation intent (page flip, page size, search) as a callback instead of
// slicing locally.
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';
// AuditLogRow is internal to the screen (not in the barrel); imported
// directly so the tests can count rendered rows.
import 'package:portal_screens/src/admin/audit_log_row.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<AuditEntryView> entries,
  bool isLoading = false,
  String? errorMessage,
  VoidCallback? onRefresh,
  int page = 1,
  int pageSize = 8,
  int totalCount = 0,
  String searchQuery = '',
  ValueChanged<int>? onPageChanged,
  ValueChanged<int>? onPageSizeChanged,
  ValueChanged<String>? onSearchChanged,
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
        body: AuditLogsScreen(
          entries: entries,
          isLoading: isLoading,
          errorMessage: errorMessage,
          onRefresh: onRefresh ?? () {},
          page: page,
          pageSize: pageSize,
          totalCount: totalCount,
          searchQuery: searchQuery,
          onPageChanged: onPageChanged ?? (_) {},
          onPageSizeChanged: onPageSizeChanged ?? (_) {},
          onSearchChanged: onSearchChanged ?? (_) {},
        ),
      ),
    ),
  );
  // Avoid pumpAndSettle — Tooltip's animation controller and the
  // loading-state CircularProgressIndicator keep the frame scheduler
  // busy indefinitely.
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('AuditLogsScreen — server-paged rendering', () {
    testWidgets('renders every entry it is handed, no local slicing', (
      tester,
    ) async {
      // 6 mock entries with pageSize 4: a locally-paging screen would
      // show 4; the controlled screen must show all 6 — the server
      // already sliced.
      await _pump(
        tester,
        entries: MockData.auditEntries,
        pageSize: 4,
        totalCount: 204,
      );
      expect(
        find.byType(AuditLogRow),
        findsNWidgets(MockData.auditEntries.length),
      );
    });

    testWidgets('pagination header shows the SERVER total, not rows.length', (
      tester,
    ) async {
      await _pump(
        tester,
        entries: MockData.auditEntries,
        page: 1,
        pageSize: 8,
        totalCount: 204,
      );
      expect(find.text('Viewing 1-8 of 204'), findsOneWidget);
    });

    testWidgets('range reflects the controlled page input', (tester) async {
      await _pump(
        tester,
        entries: MockData.auditEntries,
        page: 26,
        pageSize: 8,
        totalCount: 204,
      );
      // Last page: 201-204 of 204.
      expect(find.text('Viewing 201-204 of 204'), findsOneWidget);
    });
  });

  group('AuditLogsScreen — callbacks', () {
    testWidgets('page flip emits onPageChanged, does not reslice locally', (
      tester,
    ) async {
      final flips = <int>[];
      await _pump(
        tester,
        entries: MockData.auditEntries,
        page: 1,
        pageSize: 8,
        totalCount: 204,
        onPageChanged: flips.add,
      );
      await tester.tap(find.text('2'));
      await tester.pump();
      expect(flips, [2]);
      // Still the same rows — fetching page 2 is the wiring layer's job.
      expect(
        find.byType(AuditLogRow),
        findsNWidgets(MockData.auditEntries.length),
      );
    });

    testWidgets('page-size change emits onPageSizeChanged', (tester) async {
      final sizes = <int>[];
      await _pump(
        tester,
        entries: MockData.auditEntries,
        totalCount: 204,
        onPageSizeChanged: sizes.add,
      );
      await tester.tap(find.text('8').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('16').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(sizes, [16]);
    });

    testWidgets('search text emits onSearchChanged after the debounce', (
      tester,
    ) async {
      final queries = <String>[];
      await _pump(
        tester,
        entries: MockData.auditEntries,
        totalCount: 204,
        onSearchChanged: queries.add,
      );
      await tester.enterText(find.byType(TextField), 'emily');
      // AppTextField.search debounces onChanged by 300ms.
      await tester.pump(const Duration(milliseconds: 350));
      expect(queries, ['emily']);
    });
  });

  group('AuditLogsScreen — states', () {
    testWidgets('error state shows message + Retry wired to onRefresh', (
      tester,
    ) async {
      var refreshes = 0;
      await _pump(
        tester,
        entries: const [],
        errorMessage: 'HTTP 500',
        onRefresh: () => refreshes++,
        totalCount: 0,
      );
      expect(find.text("Couldn't load audit entries."), findsOneWidget);
      expect(find.text('HTTP 500'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(refreshes, 1);
    });

    testWidgets('loading overlay renders over current rows', (tester) async {
      await _pump(
        tester,
        entries: MockData.auditEntries,
        isLoading: true,
        totalCount: 204,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byType(AuditLogRow),
        findsNWidgets(MockData.auditEntries.length),
      );
    });

    testWidgets('empty state names the active search query', (tester) async {
      await _pump(
        tester,
        entries: const [],
        searchQuery: 'nobody@example.com',
        totalCount: 0,
      );
      expect(
        find.text('No audit entries match "nobody@example.com".'),
        findsOneWidget,
      );
    });

    testWidgets('empty state without search shows the no-entries copy', (
      tester,
    ) async {
      await _pump(tester, entries: const [], totalCount: 0);
      expect(find.text('No audit entries yet.'), findsOneWidget);
    });
  });

  group('AuditLogsScreen — Playwright instrumentation', () {
    testWidgets('search, pagination and rows carry semantics identifiers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, entries: MockData.auditEntries, totalCount: 204);

      expect(find.bySemanticsIdentifier('audit-search'), findsOneWidget);
      expect(find.bySemanticsIdentifier('audit-pagination'), findsOneWidget);
      // Rows are domain-keyed by event id — never positional (pages and
      // refreshes reorder them).
      expect(
        find.bySemanticsIdentifier(
          'audit-row-${MockData.auditEntries.first.id}',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('expanding a row surfaces its -details identifier', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, entries: MockData.auditEntries, totalCount: 204);

      final id = MockData.auditEntries.first.id;
      expect(find.bySemanticsIdentifier('audit-row-$id-details'), findsNothing);
      await tester.tap(find.bySemanticsIdentifier('audit-row-$id'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.bySemanticsIdentifier('audit-row-$id-details'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}

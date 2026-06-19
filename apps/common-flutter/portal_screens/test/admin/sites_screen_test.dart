import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

void main() {
  const sites = <SiteRowView>[
    SiteRowView(number: '002', name: 'Dev Site Two', id: 'site-2'),
    SiteRowView(number: '001', name: 'Dev Site One', id: 'site-1'),
    SiteRowView(
      number: '003',
      name: 'Dev Site Three',
      id: 'site-3',
      active: false,
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    List<SiteRowView> rows = sites,
    bool isLoading = false,
    void Function(SiteRowView)? onSiteSelected,
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(font: AppFontFamily.inter),
        home: Scaffold(
          body: SitesScreen(
            sites: rows,
            isLoading: isLoading,
            onSiteSelected: onSiteSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('renders header, columns, and rows sorted by site number', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Assigned Sites'), findsOneWidget);
    expect(find.text('Site Number'), findsOneWidget);
    expect(find.text('Site Name'), findsOneWidget);
    expect(find.text('Site ID'), findsOneWidget);

    // Sorted by number regardless of input order.
    final y1 = tester.getTopLeft(find.text('Dev Site One')).dy;
    final y2 = tester.getTopLeft(find.text('Dev Site Two')).dy;
    final y3 = tester.getTopLeft(find.text('Dev Site Three')).dy;
    expect(y1, lessThan(y2));
    expect(y2, lessThan(y3));
  });

  testWidgets('inactive site renders the Inactive badge', (tester) async {
    await pump(tester);
    expect(find.text('Inactive'), findsOneWidget);
  });

  testWidgets('tapping a row fires onSiteSelected with that site', (
    tester,
  ) async {
    SiteRowView? tapped;
    await pump(tester, onSiteSelected: (s) => tapped = s);
    await tester.tap(find.text('Dev Site Two'));
    expect(tapped?.id, 'site-2');
  });

  testWidgets('rows are passive without onSiteSelected', (tester) async {
    await pump(tester);
    // No tap target: tapping must not throw, and there is no click
    // GestureDetector wrapping the rows.
    await tester.tap(find.text('Dev Site One'), warnIfMissed: false);
    await tester.pump();
  });

  testWidgets('empty snapshot renders the no-sites copy', (tester) async {
    await pump(tester, rows: const <SiteRowView>[]);
    expect(find.text('(no sites synced yet)'), findsOneWidget);
  });

  testWidgets('isLoading overlays a spinner', (tester) async {
    await pump(tester, isLoading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

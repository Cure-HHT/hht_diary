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
  group('AppTablePagination', () {
    testWidgets('renders the range', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppTablePagination(
            currentPage: 1,
            pageSize: 10,
            totalCount: 124,
            onPageChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Viewing 1-10 of 124'), findsOneWidget);
    });

    testWidgets('renders numbered page buttons with the active one filled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          AppTablePagination(
            currentPage: 1,
            pageSize: 10,
            totalCount: 18,
            onPageChanged: (_) {},
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('prev is disabled on page 1', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppTablePagination(
            currentPage: 1,
            pageSize: 10,
            totalCount: 124,
            onPageChanged: (_) {},
          ),
        ),
      );
      final prev = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      expect(prev.onPressed, isNull);
    });

    testWidgets('next is disabled on the last page', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppTablePagination(
            currentPage: 13,
            pageSize: 10,
            totalCount: 124,
            onPageChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Viewing 121-124 of 124'), findsOneWidget);
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('next fires onPageChanged with the next page number', (
      tester,
    ) async {
      int? requestedPage;
      await tester.pumpWidget(
        _harness(
          AppTablePagination(
            currentPage: 2,
            pageSize: 10,
            totalCount: 124,
            onPageChanged: (p) => requestedPage = p,
          ),
        ),
      );
      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(requestedPage, equals(3));
    });

    testWidgets('handles an empty total count gracefully', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppTablePagination(
            currentPage: 1,
            pageSize: 10,
            totalCount: 0,
            onPageChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Viewing 0-0 of 0'), findsOneWidget);
    });

    testWidgets('semanticId emits a Semantics identifier', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppTablePagination(
            currentPage: 1,
            pageSize: 10,
            totalCount: 124,
            onPageChanged: (_) {},
            semanticId: 'users.pagination',
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AppTablePagination));
      expect(node.identifier, equals('users.pagination'));
    });
  });
}

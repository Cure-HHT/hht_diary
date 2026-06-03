import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User {
  final String name;
  final String email;
  const _User(this.name, this.email);
}

final _columns = <AppTableColumn<_User>>[
  AppTableColumn(
    key: 'name',
    label: 'Name',
    sortable: true,
    cellBuilder: (_, u) => Text(u.name),
  ),
  AppTableColumn(
    key: 'email',
    label: 'Email',
    cellBuilder: (_, u) => Text(u.email),
  ),
];

Widget _harness(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  group('AppDataTable', () {
    testWidgets('renders column headers and row cells', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppDataTable<_User>(
            columns: _columns,
            rows: const [
              _User('Dr. Emily Parker', 'eparker@clinicaltrial.com'),
              _User('Dr. James Smith', 'jsmith@clinicaltrial.com'),
            ],
          ),
        ),
      );
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Dr. Emily Parker'), findsOneWidget);
      expect(find.text('jsmith@clinicaltrial.com'), findsOneWidget);
    });

    testWidgets('shows the empty state when rows is empty', (tester) async {
      await tester.pumpWidget(
        _harness(AppDataTable<_User>(columns: _columns, rows: const [])),
      );
      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets('uses caller-provided emptyBuilder when given', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppDataTable<_User>(
            columns: _columns,
            rows: const [],
            emptyBuilder: (_) => const Text('No pending users'),
          ),
        ),
      );
      expect(find.text('No pending users'), findsOneWidget);
    });

    testWidgets('renders the error state when error is non-null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          AppDataTable<_User>(
            columns: _columns,
            rows: const [],
            error: 'network unreachable',
          ),
        ),
      );
      expect(find.text('network unreachable'), findsOneWidget);
    });

    testWidgets('shows a loading overlay when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          AppDataTable<_User>(
            columns: _columns,
            rows: const [_User('Dr. Emily Parker', 'e@x.com')],
            isLoading: true,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('onSort fires with the column key and ascending first', (
      tester,
    ) async {
      ({String key, SortDirection direction})? observed;
      await tester.pumpWidget(
        _harness(
          AppDataTable<_User>(
            columns: _columns,
            rows: const [_User('Dr. Emily Parker', 'e@x.com')],
            onSort: (record) => observed = record,
          ),
        ),
      );
      await tester.tap(find.text('Name'));
      await tester.pump();
      expect(observed?.key, equals('name'));
      expect(observed?.direction, equals(SortDirection.ascending));
    });

    testWidgets('onSort toggles to descending on the second tap', (
      tester,
    ) async {
      ({String key, SortDirection direction})? observed;
      await tester.pumpWidget(
        _harness(
          AppDataTable<_User>(
            columns: _columns,
            rows: const [_User('Dr. Emily Parker', 'e@x.com')],
            sortColumnKey: 'name',
            sortDirection: SortDirection.ascending,
            onSort: (record) => observed = record,
          ),
        ),
      );
      await tester.tap(find.text('Name'));
      await tester.pump();
      expect(observed?.direction, equals(SortDirection.descending));
    });
  });
}

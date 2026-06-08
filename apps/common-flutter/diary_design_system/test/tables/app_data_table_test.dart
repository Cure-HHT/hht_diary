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

    testWidgets('rowKey is applied to each row widget', (tester) async {
      // _DataRow is private, so we can't `find.byType(_DataRow)`. Instead,
      // walk up from the row's visible text and assert there's an
      // ancestor element keyed to the row's stable identity. If rowKey
      // weren't plumbed into _DataRow, no such keyed ancestor exists.
      const alice = _User('Alice', 'alice@x.com');
      const bob = _User('Bob', 'bob@x.com');

      await tester.pumpWidget(
        _harness(
          AppDataTable<_User>(
            columns: _columns,
            rows: const [alice, bob],
            rowKey: (u) => ValueKey<String>(u.email),
          ),
        ),
      );

      Key? firstKeyMatching(Finder finder, bool Function(Key) predicate) {
        Key? found;
        tester.element(finder).visitAncestorElements((e) {
          final k = e.widget.key;
          if (k != null && predicate(k)) {
            found = k;
            return false;
          }
          return true;
        });
        return found;
      }

      bool Function(Key) isEmailKey(String email) {
        return (Key k) => k is ValueKey<String> && k.value == email;
      }

      expect(
        firstKeyMatching(find.text('Alice'), isEmailKey('alice@x.com')),
        equals(const ValueKey<String>('alice@x.com')),
      );
      expect(
        firstKeyMatching(find.text('Bob'), isEmailKey('bob@x.com')),
        equals(const ValueKey<String>('bob@x.com')),
      );
    });

    testWidgets(
      'rowKey preserves row Element identity across a row-list reorder',
      (tester) async {
        // With rowKey set, Flutter recycles the row's State by identity —
        // its Element survives a reorder. Without rowKey (the next test),
        // State is recycled by position, so a reorder rebuilds the row
        // at its new position with a fresh Element.
        const alice = _User('Alice', 'alice@x.com');
        const bob = _User('Bob', 'bob@x.com');
        var rows = const <_User>[alice, bob];
        late StateSetter setRows;

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(font: AppFontFamily.inter),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setRows = setState;
                    return AppDataTable<_User>(
                      columns: _columns,
                      rows: rows,
                      rowKey: (u) => ValueKey<String>(u.email),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        Element rowElementFor(String email) {
          late Element found;
          tester
              .element(find.text(email == 'alice@x.com' ? 'Alice' : 'Bob'))
              .visitAncestorElements((e) {
                final k = e.widget.key;
                if (k is ValueKey<String> && k.value == email) {
                  found = e;
                  return false;
                }
                return true;
              });
          return found;
        }

        final aliceBefore = rowElementFor('alice@x.com');

        setRows(() {
          rows = const [bob, alice];
        });
        await tester.pump();

        final aliceAfter = rowElementFor('alice@x.com');
        expect(
          identical(aliceBefore, aliceAfter),
          isTrue,
          reason:
              'rowKey must make Flutter preserve the row Element across a reorder',
        );
      },
    );
  });
}

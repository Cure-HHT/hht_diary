// test/client/app_smoke_test.dart
// Verifies: the dual-pane shell renders both panes without throwing.
import 'package:action_permissions_demo/client/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DualPaneApp renders both panes', (tester) async {
    await tester.pumpWidget(const DualPaneApp());
    // Both panes fire HTTP requests in initState; in widget tests the
    // test binding rejects with 400 and the catch paths leave both panes
    // in a stable error/loading state. ClientPane pushes an Anon
    // snapshot into the cache; ServerInspectorPane shows a loading
    // indicator with an error string. We can't pumpAndSettle because
    // ServerInspectorPane runs a periodic Timer that never quiesces.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('action_permissions_demo'), findsOneWidget);
    // ClientPane (Anon principal):
    expect(find.text('Role: Anon'), findsOneWidget);
    // ServerInspectorPane: in the test binding the HTTP call fails, so
    // the pane stays in its loading-with-error state.
    expect(find.textContaining('error:'), findsOneWidget);
  });
}

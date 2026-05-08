// test/client/app_smoke_test.dart
// Verifies: the dual-pane shell renders both panes without throwing.
import 'package:action_permissions_demo/client/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DualPaneApp renders both panes', (tester) async {
    await tester.pumpWidget(const DualPaneApp());
    // ClientPane.initState fires session/start; in widget tests the HTTP
    // call fails (the test binding rejects with 400) and the catch path
    // pushes an Anon snapshot into the cache. settle() lets that future
    // resolve and the listener rebuild.
    await tester.pumpAndSettle();
    expect(find.text('action_permissions_demo'), findsOneWidget);
    // ClientPane (Anon principal):
    expect(find.text('Role: Anon'), findsOneWidget);
    // ServerInspectorPane stub:
    expect(find.textContaining('inspector pane'), findsOneWidget);
  });
}

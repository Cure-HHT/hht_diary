// test/client/app_smoke_test.dart
// Verifies: the dual-pane shell renders both panes without throwing.
import 'package:action_permissions_demo/client/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DualPaneApp renders both panes', (tester) async {
    await tester.pumpWidget(const DualPaneApp());
    await tester.pump();
    expect(find.text('action_permissions_demo'), findsOneWidget);
    expect(find.textContaining('client pane'), findsOneWidget);
    expect(find.textContaining('inspector pane'), findsOneWidget);
  });
}

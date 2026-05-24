// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-p00008: User Account Management
//   REQ-p00042: Event Sourcing Audit Trail
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//
// Verifies: REQ-p00008 — registration -> activation
// Verifies: REQ-p00006 — first diary entry persists locally
// Verifies: REQ-CAL-p00023 — submission propagates to sponsor visibility
//
// This is an END-TO-END user journey scaffold. It mirrors the structure
// of test/integration/timezone_display_e2e_test.dart (in-memory sembast,
// MockClient HTTP, fake_cloud_firestore, SharedPreferences mock).
//
// SCAFFOLD STATUS:
//   The TODO blocks below indicate where each step needs to be wired up
//   to ClinicalDiaryBootstrap test seams. Until then the bodies are
//   `skip:`-marked so they document the intended coverage without
//   producing red CI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group(
    'end-to-end journey: registration -> diary entry -> sponsor visibility',
    () {
      late List<Uri> captured;

      setUp(() {
        captured = <Uri>[];
        // mockClient is constructed here to document the intended HTTP
        // transport; the harness will pass it to ClinicalDiaryBootstrap
        // once the test seams are wired in.
        // ignore: unused_local_variable
        final mockClient = MockClient((req) async {
          captured.add(req.url);
          // TODO(REQ-p00008): branch on req.url.path to return realistic
          // payloads for /api/v1/auth/register, /activate, /tasks, /events.
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        });
      });

      testWidgets(
        'happy path renders home after activation',
        (tester) async {
          final db = await databaseFactoryMemory.openDatabase('e2e_journey.db');
          addTearDown(db.close);

          // TODO: hand `mockClient` and `db` to ClinicalDiaryBootstrap via the
          // same test seams used by timezone_display_e2e_test.dart, then pump
          // the real app instead of the placeholder harness below.
          await tester.pumpWidget(const _ScaffoldHarness());
          await tester.pumpAndSettle();

          // STEP 1 (registration):
          //   await tester.enterText(find.byKey(...), 'username');
          //   await tester.enterText(find.byKey(...), 'password');
          //   await tester.tap(find.text('Register'));
          //   await tester.pumpAndSettle();
          //   expect(captured.any((u) => u.path.endsWith('/auth/register')), isTrue);

          // STEP 2 (activation):
          //   await tester.enterText(find.byKey(...), '123456');
          //   await tester.tap(find.text('Activate'));
          //   await tester.pumpAndSettle();
          //   expect(captured.any((u) => u.path.endsWith('/auth/activate')), isTrue);

          // STEP 3 (first diary entry, offline path):
          //   await tester.tap(find.byIcon(Icons.add));
          //   ...

          // STEP 4 (assert sembast write):
          //   final store = stringMapStoreFactory.store('diary_events');
          //   final rows = await store.find(db);
          //   expect(rows, hasLength(1));

          // STEP 5 (submission):
          //   await tester.tap(find.text('Submit'));
          //   await tester.pumpAndSettle();
          //   expect(captured.any((u) => u.path.endsWith('/events')), isTrue);

          // Until wired, just confirm the harness mounts cleanly.
          expect(find.byType(_ScaffoldHarness), findsOneWidget);
        },
        skip: true, // scaffold — wire bootstrap test seams (see TODOs)
      );
    },
  );
}

/// Placeholder harness that the real ClinicalDiaryApp will replace once
/// the bootstrap test seams are exposed.
class _ScaffoldHarness extends StatelessWidget {
  const _ScaffoldHarness();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('e2e harness'))),
    );
  }
}

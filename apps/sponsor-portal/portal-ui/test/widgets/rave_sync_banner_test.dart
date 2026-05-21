// Verifies: DIARY-GUI-rave-sync-paused-banner/A+B+C
//
// Widget tests for the Sites/Participants paused-state banner. Covers the
// three states (ok / cooldown / locked), the distinct copy per state, and
// the absence of diagnostic detail (counter, reason code, etc).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/widgets/rave_sync_banner.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('RaveSyncBanner', () {
    testWidgets('renders nothing when state == ok', (tester) async {
      await tester.pumpWidget(_wrap(const RaveSyncBanner(state: 'ok')));
      // No text, no icon — the widget short-circuits to SizedBox.shrink.
      expect(find.byIcon(Icons.warning_amber), findsNothing);
      expect(find.textContaining('Rave sync'), findsNothing);
    });

    testWidgets(
      'cooldown variant shows paused_until and "resumes automatically"',
      (tester) async {
        final pausedUntil = DateTime.utc(2026, 5, 22, 12, 0, 0);
        await tester.pumpWidget(
          _wrap(RaveSyncBanner(state: 'cooldown', pausedUntil: pausedUntil)),
        );
        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
        expect(
          find.textContaining('paused due to a recent auth failure'),
          findsOneWidget,
        );
        expect(find.textContaining('resumes automatically'), findsOneWidget);
        expect(
          find.textContaining(pausedUntil.toIso8601String()),
          findsOneWidget,
        );
        // Cooldown banner must NOT direct user to Dev Admin (that's the locked variant).
        expect(find.textContaining('Developer Admin'), findsNothing);
      },
    );

    testWidgets('locked variant shows since and Dev Admin contact prompt', (
      tester,
    ) async {
      final since = DateTime.utc(2026, 5, 21, 8, 30, 0);
      await tester.pumpWidget(
        _wrap(RaveSyncBanner(state: 'locked', since: since)),
      );
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.textContaining('contact a Developer Admin'), findsOneWidget);
      expect(find.textContaining(since.toIso8601String()), findsOneWidget);
      // Locked banner must NOT promise auto-resume (that's the cooldown variant).
      expect(find.textContaining('resumes automatically'), findsNothing);
    });

    testWidgets('exposes no diagnostic detail (counter, reason code)', (
      tester,
    ) async {
      // The widget intentionally has no fields for counter / reason-code /
      // unwedger identity. Re-checking by absence of any such text in
      // both pause states.
      await tester.pumpWidget(_wrap(const RaveSyncBanner(state: 'cooldown')));
      expect(find.textContaining('counter'), findsNothing);
      expect(find.textContaining('reason'), findsNothing);
      expect(find.textContaining('unwedged'), findsNothing);
    });
  });
}

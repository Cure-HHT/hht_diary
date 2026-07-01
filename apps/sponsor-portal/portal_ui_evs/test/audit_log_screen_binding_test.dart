// Verifies: DIARY-GUI-audit-log-common/A+B+E
//
// AuditLogScreenBinding owns the server-side paging loop: it fetches ONE
// page per request (limit/offset), refetches when the screen reports a page
// flip / page-size change / settled search, forwards the server's true
// total, and surfaces fetch failures as the screen's error state.
import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_ui_evs/src/audit_log_screen_binding.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

Map<String, Object?> _row(int seq) => <String, Object?>{
  'event_id': 'evt-$seq',
  'sequence': seq,
  'timestamp': '2026-06-09T12:00:00.000Z',
  'entry_type': 'user_created',
  'event_type': 'user_created',
  'aggregate_type': 'portal_user',
  'aggregate_id': 'u-$seq',
  'initiator': <String, Object?>{
    'kind': 'user',
    'label': 'admin@reference.local',
  },
};

/// Fake /audit server: 204 unfiltered events (3 when a `q` is present,
/// unless overridden via [filteredTotal]), reverse-chronological, sliced
/// per limit/offset like the real handler.
MockClient _auditServer(
  List<http.Request> requests, {
  int total = 204,
  int Function()? filteredTotal,
  Set<int> failOnRequest = const {},
}) {
  return MockClient((request) async {
    requests.add(request);
    if (failOnRequest.contains(requests.length)) {
      return http.Response('boom', 500);
    }
    final params = request.url.queryParameters;
    final limit = int.parse(params['limit']!);
    final offset = int.parse(params['offset']!);
    final q = params['q'] ?? '';
    final effectiveTotal = q.isEmpty ? total : (filteredTotal ?? () => 3)();
    final top = effectiveTotal - offset;
    final rows = <Map<String, Object?>>[
      for (var s = top; s > top - limit && s >= 1; s--) _row(s),
    ];
    return http.Response(
      jsonEncode(<String, Object?>{
        'rows': rows,
        'count': rows.length,
        'total': effectiveTotal,
        'offset': offset,
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );
  });
}

FakeReaction _authedAdmin() => FakeReaction(
  initialAuthStatus: Authenticated(
    principal: Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    ),
  ),
  initialPermission: EffectiveAuthorization(
    activeRole: 'Administrator',
    rolePermissions: {Permission('portal.audit.view')},
    scopeAssignments: const <ScopeAssignment>[],
  ),
);

Future<void> _pumpBinding(
  WidgetTester tester, {
  required http.Client client,
  FakeReaction? fake,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  // Not pumpReactionWidget: that helper mounts a default-theme
  // MaterialApp, but the screen's design-system widgets (AppButton
  // etc.) require buildAppTheme.
  await tester.pumpWidget(
    ReActionScope(
      scope: fake ?? _authedAdmin(),
      child: MaterialApp(
        theme: buildAppTheme(font: AppFontFamily.inter),
        home: Scaffold(
          body: AuditLogScreenBinding(
            identityCredential: 'cred-123',
            serverUrl: 'http://portal.test',
            httpClient: client,
          ),
        ),
      ),
    ),
  );
  // Drain the initial fetch (MockClient resolves on a microtask) and
  // the setState frame it schedules. Avoid pumpAndSettle — Tooltip's
  // controller keeps the scheduler busy.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('initial fetch asks for page 1 and renders the true total', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await _pumpBinding(tester, client: _auditServer(requests));

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/audit');
    expect(requests.single.url.queryParameters['limit'], '8');
    expect(requests.single.url.queryParameters['offset'], '0');
    expect(requests.single.url.queryParameters.containsKey('q'), isFalse);
    // `<identityCredential>|<activeRole>` Bearer shape.
    expect(
      requests.single.headers['Authorization'],
      'Bearer cred-123|Administrator',
    );
    expect(find.text('Viewing 1-8 of 204'), findsOneWidget);
  });

  testWidgets('page flip fetches that page with the matching offset', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await _pumpBinding(tester, client: _auditServer(requests));

    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(requests, hasLength(2));
    expect(requests.last.url.queryParameters['offset'], '8');
    expect(find.text('Viewing 9-16 of 204'), findsOneWidget);
  });

  testWidgets('paging to the LAST page reaches the oldest entries', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await _pumpBinding(tester, client: _auditServer(requests));

    // 204 events / 8 per page -> last page is 26 (rows 201-204).
    await tester.tap(find.text('26'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(requests.last.url.queryParameters['offset'], '200');
    expect(find.text('Viewing 201-204 of 204'), findsOneWidget);
  });

  testWidgets('page-size change refetches from page 1 with the new limit', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await _pumpBinding(tester, client: _auditServer(requests));

    await tester.tap(find.text('8').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('16').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 50));

    expect(requests.last.url.queryParameters['limit'], '16');
    expect(requests.last.url.queryParameters['offset'], '0');
    expect(find.text('Viewing 1-16 of 204'), findsOneWidget);
  });

  testWidgets('search refetches server-side from page 1 with q', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await _pumpBinding(tester, client: _auditServer(requests));

    await tester.enterText(find.byType(TextField), 'admin@reference.local');
    // The screen's search field debounces by 300ms before reporting.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 50));

    expect(requests.last.url.queryParameters['q'], 'admin@reference.local');
    expect(requests.last.url.queryParameters['offset'], '0');
    // The fake server reports 3 matches — the header must show the
    // filtered total, proving the screen reflects server-side search.
    expect(find.text('Viewing 1-3 of 3'), findsOneWidget);
  });

  testWidgets('failed page fetch shows the error banner; Retry recovers', (
    tester,
  ) async {
    final requests = <http.Request>[];
    // First request (the initial fetch) fails, the retry succeeds.
    await _pumpBinding(
      tester,
      client: _auditServer(requests, failOnRequest: {1}),
    );

    expect(find.text("Couldn't load audit entries."), findsOneWidget);
    expect(find.text('HTTP 500'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(requests, hasLength(2));
    expect(find.text("Couldn't load audit entries."), findsNothing);
    expect(find.text('Viewing 1-8 of 204'), findsOneWidget);
  });

  testWidgets('snaps back to the last page when the page falls off the end', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var filtered = 100;
    await _pumpBinding(
      tester,
      client: _auditServer(requests, filteredTotal: () => filtered),
    );

    // Search with 100 matches -> 13 pages.
    await tester.enterText(find.byType(TextField), 'admin');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Viewing 1-8 of 100'), findsOneWidget);

    // The match set shrinks server-side to 3 rows; the user then flips
    // to (now-phantom) page 13. The fetch comes back empty with total 3
    // and the binding must snap to the last REAL page, not render an
    // empty phantom page or loop.
    filtered = 3;
    await tester.tap(find.text('13'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Viewing 1-3 of 3'), findsOneWidget);
  });
}

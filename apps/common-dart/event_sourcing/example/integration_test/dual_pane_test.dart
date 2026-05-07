// IMPLEMENTS REQUIREMENTS:
//   REQ-d00122: Destination contract surface
//   REQ-d00152: Native destination wire format

import 'dart:async';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:event_sourcing_datastore_demo/demo_knobs.dart';
import 'package:event_sourcing_datastore_demo/demo_sync_policy.dart';
import 'package:event_sourcing_datastore_demo/demo_types.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/dual_demo_app.dart';
import 'package:event_sourcing_datastore_demo/native_demo_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// Hide sembast's Finder to avoid ambiguity with flutter_test's Finder.
import 'package:sembast/sembast_memory.dart' hide Finder;

class _PaneHandle {
  _PaneHandle({
    required this.datastore,
    required this.backend,
    required this.appState,
    required this.policyNotifier,
    required this.source,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final AppState appState;
  final ValueNotifier<SyncPolicy> policyNotifier;
  final Source source;

  Future<void> tick() async {
    final destinations = datastore.destinations.all();
    for (final dest in destinations) {
      final schedule = await datastore.destinations.scheduleOf(dest.id);
      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        source: source,
      );
    }
    for (final dest in destinations) {
      await drain(dest, backend: backend, policy: policyNotifier.value);
    }
  }
}

Future<_PaneHandle> _mkPane({
  required String dbName,
  required Source source,
  DownstreamBridge? bridge,
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(dbName);
  final backend = SembastBackend(database: db);
  final policyNotifier = ValueNotifier<SyncPolicy>(demoDefaultSyncPolicy);

  final primary = DemoDestination(
    id: 'Primary',
    filter: const SubscriptionFilter(
      entryTypes: <String>[
        'demo_note',
        'red_button_pressed',
        'green_button_pressed',
      ],
    ),
  );
  final secondary = DemoDestination(
    id: 'Secondary',
    allowHardDelete: true,
    filter: const SubscriptionFilter(
      entryTypes: <String>['green_button_pressed', 'blue_button_pressed'],
    ),
  );
  // Two parallel native destinations — user payloads vs system audits —
  // mirror the dual-pane example app's bridging surface.
  final nativeUser = NativeDemoDestination(
    id: 'NativeUser',
    filter: const SubscriptionFilter(
      entryTypes: <String>[
        'demo_note',
        'red_button_pressed',
        'green_button_pressed',
        'blue_button_pressed',
      ],
    ),
    bridge: bridge,
  );
  final nativeAudit = NativeDemoDestination(
    id: 'NativeAudit',
    filter: const SubscriptionFilter(
      entryTypes: <String>[],
      includeSystemEvents: true,
    ),
    bridge: bridge,
  );

  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: source,
    entryTypes: allDemoEntryTypes,
    destinations: <Destination>[primary, secondary, nativeUser, nativeAudit],
    materializers: const <Materializer>[
      DiaryEntriesMaterializer(promoter: identityPromoter),
    ],
    initialViewTargetVersions: const <String, Map<String, int>>{
      'diary_entries': <String, int>{'demo_note': 1},
    },
  );

  final now = DateTime.now().toUtc();
  for (final id in <String>[
    'Primary',
    'Secondary',
    'NativeUser',
    'NativeAudit',
  ]) {
    final schedule = await datastore.destinations.scheduleOf(id);
    if (schedule.startDate == null) {
      await datastore.destinations.setStartDate(
        id,
        now,
        initiator: const AutomationInitiator(service: 'demo-bootstrap'),
      );
    }
  }

  final appState = AppState(
    registry: datastore.destinations,
    policyNotifier: policyNotifier,
  );

  return _PaneHandle(
    datastore: datastore,
    backend: backend,
    appState: appState,
    policyNotifier: policyNotifier,
    source: source,
  );
}

class _EntryTypeLookup implements EntryTypeDefinitionLookup {
  const _EntryTypeLookup(this.registry);
  final EntryTypeRegistry registry;
  @override
  EntryTypeDefinition? lookup(String entryTypeId) => registry.byId(entryTypeId);
}

Future<({_PaneHandle mobile, _PaneHandle portal, Widget app})> _setupDualApp({
  required String testId,
}) async {
  final portal = await _mkPane(
    dbName: 'portal-$testId.db',
    source: const Source(
      hopId: 'portal-server',
      identifier: '11111111-1111-4111-8111-111111111111',
      softwareVersion: 'integ-test',
    ),
  );
  final bridge = DownstreamBridge(portal.datastore.eventStore);
  final mobile = await _mkPane(
    dbName: 'mobile-$testId.db',
    source: const Source(
      hopId: 'mobile-device',
      identifier: '22222222-2222-4222-8222-222222222222',
      softwareVersion: 'integ-test',
    ),
    bridge: bridge,
  );

  // Dummy tick timer: DemoPane only uses the tickController inside
  // resetAll(), which our tests never invoke. The field is non-nullable, so
  // we supply a no-op timer that fires once far in the future.
  final dummyTick = Timer(const Duration(days: 365), () {});
  final lookup = _EntryTypeLookup(mobile.datastore.entryTypes);

  final app = DualDemoApp(
    top: DemoPaneConfig(
      datastore: mobile.datastore,
      backend: mobile.backend,
      appState: mobile.appState,
      entryTypeLookup: lookup,
      dbPath: 'mobile-$testId.db',
      tickController: dummyTick,
      paneLabel: 'MOBILE',
      policyNotifier: mobile.policyNotifier,
    ),
    bottom: DemoPaneConfig(
      datastore: portal.datastore,
      backend: portal.backend,
      appState: portal.appState,
      entryTypeLookup: lookup,
      dbPath: 'portal-$testId.db',
      tickController: dummyTick,
      paneLabel: 'PORTAL',
      policyNotifier: portal.policyNotifier,
    ),
  );
  return (mobile: mobile, portal: portal, app: app);
}

Finder _paneByLabel(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(DemoPane));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Both pane labels render', (tester) async {
    // Use a large window so the demo app's many fixed-width columns do not
    // overflow — the app is designed for wide desktop windows.
    tester.view.physicalSize = const Size(4000, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final setup = await _setupDualApp(testId: 'labels');
    await tester.pumpWidget(setup.app);
    await tester.pumpAndSettle();

    expect(find.text('MOBILE'), findsOneWidget);
    expect(find.text('PORTAL'), findsOneWidget);
  });

  testWidgets('Divider drag resizes panes', (tester) async {
    final setup = await _setupDualApp(testId: 'divider');
    // Use a large window so columns do not overflow.
    tester.view.physicalSize = const Size(4000, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(setup.app);
    await tester.pumpAndSettle();

    final mobilePane = _paneByLabel('MOBILE');
    final portalPane = _paneByLabel('PORTAL');
    final initialMobileSize = tester.getSize(mobilePane);
    final initialPortalSize = tester.getSize(portalPane);

    // The pane divider inside DualDemoApp is the only GestureDetector that
    // handles onVerticalDragUpdate (the column dividers inside DemoPane use
    // onHorizontalDragUpdate). Find it directly and drag it down 200px to
    // grow the top pane and shrink the bottom pane.
    final dividerFinder = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.onVerticalDragUpdate != null &&
          widget.onHorizontalDragUpdate == null,
    );
    expect(dividerFinder, findsOneWidget);

    await tester.drag(dividerFinder, const Offset(0, 200));
    await tester.pumpAndSettle();

    final newMobileSize = tester.getSize(mobilePane);
    final newPortalSize = tester.getSize(portalPane);
    expect(newMobileSize.height, greaterThan(initialMobileSize.height));
    expect(newPortalSize.height, lessThan(initialPortalSize.height));
  });

  testWidgets(
    'Tapping GREEN on mobile produces a GreenButtonPressed row in portal events',
    (tester) async {
      final setup = await _setupDualApp(testId: 'green-sync');
      tester.view.physicalSize = const Size(4000, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(setup.app);
      await tester.pumpAndSettle();

      // Sanity: portal pane shows no GreenButtonPressed row initially.
      expect(
        find.descendant(
          of: _paneByLabel('PORTAL'),
          matching: find.textContaining('GreenButtonPressed'),
        ),
        findsNothing,
      );

      // Tap GREEN inside the mobile pane.
      final greenInMobile = find.descendant(
        of: _paneByLabel('MOBILE'),
        matching: find.widgetWithText(TextButton, 'GREEN'),
      );
      expect(greenInMobile, findsOneWidget);
      await tester.tap(greenInMobile, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Drive sync ticks: mobile fills + drains (bridge delivers to portal);
      // then portal fills + drains its own destinations.
      await setup.mobile.tick();
      await setup.portal.tick();
      await tester.pumpAndSettle();

      // Expect at least one GreenButtonPressed row in the PORTAL pane.
      expect(
        find.descendant(
          of: _paneByLabel('PORTAL'),
          matching: find.textContaining('GreenButtonPressed'),
        ),
        findsAtLeastNWidgets(1),
      );
    },
  );

  testWidgets('Broken Native connection blocks delivery to portal', (
    tester,
  ) async {
    final setup = await _setupDualApp(testId: 'broken');
    tester.view.physicalSize = const Size(4000, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Flip every mobile native destination (NativeUser, NativeAudit) to
    // broken BEFORE pumping or tapping — both lanes feed the bridge.
    for (final n
        in setup.mobile.datastore.destinations
            .all()
            .whereType<NativeDemoDestination>()) {
      n.connection.value = Connection.broken;
    }

    await tester.pumpWidget(setup.app);
    await tester.pumpAndSettle();

    final greenInMobile = find.descendant(
      of: _paneByLabel('MOBILE'),
      matching: find.widgetWithText(TextButton, 'GREEN'),
    );
    await tester.tap(greenInMobile, warnIfMissed: false);
    await tester.pumpAndSettle();

    await setup.mobile.tick();
    await setup.portal.tick();
    await tester.pumpAndSettle();

    // Broken link must not deliver to portal.
    expect(
      find.descendant(
        of: _paneByLabel('PORTAL'),
        matching: find.textContaining('GreenButtonPressed'),
      ),
      findsNothing,
    );
  });

  // Verifies: REQ-d00154-B — `EventStreamPanel` rows render `[L]` for
  //   locally-originated events and `[R]` for events ingested from
  //   another hop. Mobile records a GREEN press locally; after sync,
  //   that event lives on both panes' event logs but with different
  //   originator-identity comparisons:
  //     - Mobile's pane shows the row with `[L]` (originator == self).
  //     - Portal's pane shows the same row with `[R]` (originator was
  //       mobile, not portal).
  testWidgets(
    'REQ-d00154-B: portal pane shows [R] for ingested events; mobile shows [L]',
    (tester) async {
      final setup = await _setupDualApp(testId: 'hop-badge');
      tester.view.physicalSize = const Size(4000, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(setup.app);
      await tester.pumpAndSettle();

      // Tap GREEN inside the mobile pane to record a locally-originated
      // event that the bridge will carry to the portal pane.
      final greenInMobile = find.descendant(
        of: _paneByLabel('MOBILE'),
        matching: find.widgetWithText(TextButton, 'GREEN'),
      );
      expect(greenInMobile, findsOneWidget);
      await tester.tap(greenInMobile, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Drive sync: mobile fills + drains, portal ingests + processes.
      await setup.mobile.tick();
      await setup.portal.tick();
      await tester.pumpAndSettle();

      // Mobile pane: at least one `[L]` row (the locally-recorded GREEN).
      expect(
        find.descendant(
          of: _paneByLabel('MOBILE'),
          matching: find.textContaining('[L] '),
        ),
        findsAtLeastNWidgets(1),
        reason:
            'mobile pane must render at least one [L] row for the GREEN '
            'event it originated locally',
      );

      // Portal pane: at least one `[R]` row (the GREEN ingested from
      // mobile via the downstream bridge).
      expect(
        find.descendant(
          of: _paneByLabel('PORTAL'),
          matching: find.textContaining('[R] '),
        ),
        findsAtLeastNWidgets(1),
        reason:
            'portal pane must render at least one [R] row for the GREEN '
            'event it ingested from mobile',
      );
    },
  );
}

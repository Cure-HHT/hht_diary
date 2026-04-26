// IMPLEMENTS REQUIREMENTS:
//   REQ-d00122: Destination contract surface
//   REQ-d00152: Native destination wire format

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:event_sourcing_datastore_demo/demo_knobs.dart';
import 'package:event_sourcing_datastore_demo/demo_sync_policy.dart';
import 'package:event_sourcing_datastore_demo/demo_types.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/native_demo_destination.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _Pane {
  _Pane({
    required this.datastore,
    required this.backend,
    required this.source,
    required this.policyNotifier,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final Source source;
  final ValueNotifier<SyncPolicy> policyNotifier;

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

Future<_Pane> _mkPane({
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
  final native = NativeDemoDestination(id: 'Native', bridge: bridge);

  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: source,
    entryTypes: allDemoEntryTypes,
    destinations: <Destination>[primary, secondary, native],
    materializers: const <Materializer>[
      DiaryEntriesMaterializer(promoter: identityPromoter),
    ],
    initialViewTargetVersions: const <String, Map<String, int>>{
      'diary_entries': <String, int>{'demo_note': 1},
    },
  );

  final now = DateTime.now().toUtc();
  for (final id in <String>['Primary', 'Secondary', 'Native']) {
    final schedule = await datastore.destinations.scheduleOf(id);
    if (schedule.startDate == null) {
      await datastore.destinations.setStartDate(
        id,
        now,
        initiator: const AutomationInitiator(service: 'demo-bootstrap'),
      );
    }
  }

  return _Pane(
    datastore: datastore,
    backend: backend,
    source: source,
    policyNotifier: policyNotifier,
  );
}

Future<void> _appendDemoNote(_Pane pane, String aggregateId) async {
  await pane.datastore.eventStore.append(
    entryType: 'demo_note',
    entryTypeVersion: 1,
    aggregateId: aggregateId,
    aggregateType: 'DiaryEntry',
    eventType: 'finalized',
    data: const <String, Object?>{
      'answers': <String, Object?>{'title': 't', 'body': 'b'},
    },
    initiator: const UserInitiator('demo-user-1'),
  );
}

void main() {
  group('mobile -> portal one-way sync', () {
    test(
      'three demo_notes appended on mobile arrive in portal with portal-stamped provenance',
      () async {
        final portal = await _mkPane(
          dbName: 'portal-e2e.db',
          source: const Source(
            hopId: 'portal',
            identifier: 'demo-portal',
            softwareVersion: 'test',
          ),
        );
        final bridge = DownstreamBridge(portal.datastore.eventStore);
        final mobile = await _mkPane(
          dbName: 'mobile-e2e.db',
          source: const Source(
            hopId: 'mobile-device',
            identifier: 'demo-device',
            softwareVersion: 'test',
          ),
          bridge: bridge,
        );

        await _appendDemoNote(mobile, 'agg-a');
        await _appendDemoNote(mobile, 'agg-b');
        await _appendDemoNote(mobile, 'agg-c');

        // Two ticks: tick 1 fills the FIFO + drains; the bridge ingests
        // into portal during drain. Tick 2 lets portal's own destinations
        // process the freshly-ingested events.
        await mobile.tick();
        await portal.tick();

        // Filter out the portal's own bootstrap-emitted system audit
        // events (REQ-d00129-J/K) so the assertion stays focused on
        // user payload arriving from mobile.
        final portalEvents = (await portal.backend.findAllEvents())
            .where((e) => !kReservedSystemEntryTypeIds.contains(e.entryType))
            .toList();
        expect(portalEvents.length, 3);
        for (final ev in portalEvents) {
          final provenance = (ev.metadata['provenance'] as List<Object?>)
              .cast<Map<String, Object?>>();
          final hops = provenance.map((p) => p['hop'] as String).toList();
          expect(
            hops,
            containsAllInOrder(<String>['mobile-device', 'portal']),
            reason: 'event ${ev.eventId} provenance hops: $hops',
          );
        }
      },
    );

    test(
      'events appended locally on portal do not flow back to mobile',
      () async {
        final portal = await _mkPane(
          dbName: 'portal-oneway.db',
          source: const Source(
            hopId: 'portal',
            identifier: 'demo-portal',
            softwareVersion: 'test',
          ),
        );
        final bridge = DownstreamBridge(portal.datastore.eventStore);
        final mobile = await _mkPane(
          dbName: 'mobile-oneway.db',
          source: const Source(
            hopId: 'mobile-device',
            identifier: 'demo-device',
            softwareVersion: 'test',
          ),
          bridge: bridge,
        );

        await _appendDemoNote(portal, 'agg-portal-only');
        await portal.tick();
        await mobile.tick();

        // Filter out mobile's own bootstrap-emitted system audit
        // events (REQ-d00129-J/K) so this assertion stays focused on
        // whether portal-originated user payloads leaked back.
        final mobileEvents = (await mobile.backend.findAllEvents())
            .where((e) => !kReservedSystemEntryTypeIds.contains(e.entryType))
            .toList();
        expect(
          mobileEvents,
          isEmpty,
          reason: 'mobile must not receive events from portal (one-way sync)',
        );
      },
    );

    test(
      'mobile.Native connection=broken keeps mobile FIFO pending and portal empty',
      () async {
        final portal = await _mkPane(
          dbName: 'portal-broken.db',
          source: const Source(
            hopId: 'portal',
            identifier: 'demo-portal',
            softwareVersion: 'test',
          ),
        );
        final bridge = DownstreamBridge(portal.datastore.eventStore);
        final mobile = await _mkPane(
          dbName: 'mobile-broken.db',
          source: const Source(
            hopId: 'mobile-device',
            identifier: 'demo-device',
            softwareVersion: 'test',
          ),
          bridge: bridge,
        );

        // Flip mobile's Native to broken before the first tick.
        final native = mobile.datastore.destinations
            .all()
            .whereType<NativeDemoDestination>()
            .single;
        native.connection.value = Connection.broken;

        await _appendDemoNote(mobile, 'agg-stuck');
        await mobile.tick();
        await portal.tick();

        // Filter out portal's own bootstrap-emitted system audit events.
        final portalEvents = (await portal.backend.findAllEvents())
            .where((e) => !kReservedSystemEntryTypeIds.contains(e.entryType))
            .toList();
        expect(
          portalEvents,
          isEmpty,
          reason: 'broken link must not deliver to portal',
        );
        final mobileFifo = await mobile.backend.listFifoEntries('Native');
        expect(
          mobileFifo,
          isNotEmpty,
          reason:
              'broken link must keep mobile.Native FIFO row pending for retry',
        );
      },
    );
  });
}

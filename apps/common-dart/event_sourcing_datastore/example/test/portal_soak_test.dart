// IMPLEMENTS REQUIREMENTS:
//   REQ-d00122: Destination contract surface
//   REQ-d00128: Batch transform, canAddToBatch, maxAccumulateTime
//   REQ-d00152: Native destination wire format

import 'dart:async';
import 'dart:math';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:event_sourcing_datastore_demo/demo_sync_policy.dart';
import 'package:event_sourcing_datastore_demo/demo_types.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/native_demo_destination.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

// ---------------------------------------------------------------------------
// _Pane / _mkPane — inlined from portal_sync_test.dart (private classes
// cannot be imported across test files).
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _appendButtonEvent(_Pane pane, String entryType) async {
  await pane.datastore.eventStore.append(
    entryType: entryType,
    entryTypeVersion: 1,
    aggregateId: 'soak-${entryType.replaceAll('_', '-')}',
    aggregateType: demoAggregateTypeByEntryTypeId[entryType]!,
    eventType: 'finalized',
    data: const <String, Object?>{},
    initiator: const UserInitiator('soak-user'),
  );
}

// ---------------------------------------------------------------------------
// Soak test
// ---------------------------------------------------------------------------

void main() {
  group('soak', () {
    test(
      '60s RGB soak with batched FIFOs',
      () async {
        // ---- Setup -------------------------------------------------------
        final portal = await _mkPane(
          dbName: 'portal-soak.db',
          source: const Source(
            hopId: 'portal',
            identifier: 'demo-portal',
            softwareVersion: 'test',
          ),
        );
        final bridge = DownstreamBridge(portal.datastore.eventStore);
        final mobile = await _mkPane(
          dbName: 'mobile-soak.db',
          source: const Source(
            hopId: 'mobile-device',
            identifier: 'demo-device',
            softwareVersion: 'test',
          ),
          bridge: bridge,
        );

        // ---- Tune mobile knobs -------------------------------------------
        // Primary: batchSize=3, accumulate=3s, zero send latency
        final primary =
            mobile.datastore.destinations.byId('Primary')! as DemoDestination;
        primary.batchSize.value = 3;
        primary.maxAccumulateTimeN.value = const Duration(seconds: 3);
        primary.sendLatency.value = Duration.zero;

        // Secondary: batchSize=4, accumulate=2s, zero send latency
        final secondary =
            mobile.datastore.destinations.byId('Secondary')! as DemoDestination;
        secondary.batchSize.value = 4;
        secondary.maxAccumulateTimeN.value = const Duration(seconds: 2);
        secondary.sendLatency.value = Duration.zero;

        // Native: leave defaults (batchSize=10, accumulate=0), zero latency
        final native = mobile.datastore.destinations
            .all()
            .whereType<NativeDemoDestination>()
            .single;
        native.sendLatency.value = Duration.zero;

        // ---- Portal knobs: zero send latency on all 3 destinations ------
        // Portal destinations default to DemoDestination with sendLatency=10s
        // which would cause portal drain to take 10s per row × many rows.
        // Zero them so drain completes instantly (test uses in-memory
        // backends; production defaults are not changed by this test).
        final portalPrimary =
            portal.datastore.destinations.byId('Primary')! as DemoDestination;
        portalPrimary.sendLatency.value = Duration.zero;
        final portalSecondary =
            portal.datastore.destinations.byId('Secondary')! as DemoDestination;
        portalSecondary.sendLatency.value = Duration.zero;
        // portal.Native has no bridge and default sendLatency=0 already

        // ---- Tick loops --------------------------------------------------
        // Each pane uses a single shared async tick function gated by a
        // per-pane in-flight bool. The periodic timer AND the manual flush
        // sequence both call through this function, so they can never
        // overlap and race on markFinal (which is one-way).
        var mobileSyncInFlight = false;
        var portalSyncInFlight = false;

        Future<void> mobileSyncTick() async {
          if (mobileSyncInFlight) return;
          mobileSyncInFlight = true;
          try {
            final dests = mobile.datastore.destinations.all();
            for (final dest in dests) {
              final schedule = await mobile.datastore.destinations.scheduleOf(
                dest.id,
              );
              await fillBatch(
                dest,
                backend: mobile.backend,
                schedule: schedule,
                source: mobile.source,
              );
            }
            for (final dest in dests) {
              await drain(
                dest,
                backend: mobile.backend,
                policy: mobile.policyNotifier.value,
              );
            }
          } catch (e, s) {
            // ignore: avoid_print
            print('[soak:mobile] tick error: $e\n$s');
          } finally {
            mobileSyncInFlight = false;
          }
        }

        Future<void> portalSyncTick() async {
          if (portalSyncInFlight) return;
          portalSyncInFlight = true;
          try {
            final dests = portal.datastore.destinations.all();
            for (final dest in dests) {
              final schedule = await portal.datastore.destinations.scheduleOf(
                dest.id,
              );
              await fillBatch(
                dest,
                backend: portal.backend,
                schedule: schedule,
                source: portal.source,
              );
            }
            for (final dest in dests) {
              await drain(
                dest,
                backend: portal.backend,
                policy: portal.policyNotifier.value,
              );
            }
          } catch (e, s) {
            // ignore: avoid_print
            print('[soak:portal] tick error: $e\n$s');
          } finally {
            portalSyncInFlight = false;
          }
        }

        final mobileTick = Timer.periodic(
          const Duration(seconds: 1),
          (_) => mobileSyncTick(),
        );
        final portalTick = Timer.periodic(
          const Duration(seconds: 1),
          (_) => portalSyncTick(),
        );

        // ---- 60-second click loop ----------------------------------------
        final rng = Random(42);
        final buttons = <String>[
          'red_button_pressed',
          'green_button_pressed',
          'blue_button_pressed',
        ];
        final clickCounts = <String, int>{'red': 0, 'green': 0, 'blue': 0};
        var totalClicks = 0;

        final clickStart = DateTime.now();
        while (DateTime.now().difference(clickStart).inSeconds < 60) {
          final idx = rng.nextInt(3);
          final entryType = buttons[idx];
          await _appendButtonEvent(mobile, entryType);
          totalClicks++;
          final colorKey = <String>['red', 'green', 'blue'][idx];
          clickCounts[colorKey] = (clickCounts[colorKey] ?? 0) + 1;
          // Random sleep [500ms, 1500ms]
          final sleepMs = 500 + rng.nextInt(1001);
          await Future<void>.delayed(Duration(milliseconds: sleepMs));
        }
        final clickElapsed = DateTime.now().difference(clickStart);

        // ---- Cancel tick timers ------------------------------------------
        // cancel() stops future firings. Any already-queued timer callback
        // that fires after this point will call mobileSyncTick() /
        // portalSyncTick(), which check the in-flight bool and skip if
        // a tick is already running. The flush ticks below use the same
        // guarded functions, so timer bodies and manual flush bodies are
        // mutually exclusive — no double-markFinal is possible.
        mobileTick.cancel();
        portalTick.cancel();

        // ---- Flush sequence: 8 alternating guarded ticks ----------------
        // Use the same guarded tick functions so any late-firing periodic
        // callback and the flush ticks share the in-flight mutex.
        // Wait for the lock to be free before each call so we don't skip.
        for (var i = 0; i < 8; i++) {
          while (mobileSyncInFlight) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          await mobileSyncTick();
          await Future<void>.delayed(const Duration(milliseconds: 250));
          while (portalSyncInFlight) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          await portalSyncTick();
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }

        // ---- Collect results ---------------------------------------------
        // Filter out the system audit events emitted by REQ-d00129-J/K
        // (destination registration + start_date set) so the
        // user-event-count assertions stay focused on the soak's
        // simulated clicks.
        final mobileEvents = (await mobile.backend.findAllEvents())
            .where((e) => !kReservedSystemEntryTypeIds.contains(e.entryType))
            .toList();
        final portalEvents = (await portal.backend.findAllEvents())
            .where((e) => !kReservedSystemEntryTypeIds.contains(e.entryType))
            .toList();

        final mobileFifoPrimary = await mobile.backend.listFifoEntries(
          'Primary',
        );
        final mobileFifoSecondary = await mobile.backend.listFifoEntries(
          'Secondary',
        );
        final mobileFifoNative = await mobile.backend.listFifoEntries('Native');
        final portalFifoPrimary = await portal.backend.listFifoEntries(
          'Primary',
        );
        final portalFifoSecondary = await portal.backend.listFifoEntries(
          'Secondary',
        );
        final portalFifoNative = await portal.backend.listFifoEntries('Native');

        // Batch-size distribution for mobile FIFOs
        Map<int, int> batchSizeDist(List<FifoEntry> entries) {
          final dist = <int, int>{};
          for (final e in entries) {
            final len = e.eventIds.length;
            dist[len] = (dist[len] ?? 0) + 1;
          }
          return dist;
        }

        final primaryDist = batchSizeDist(mobileFifoPrimary);
        final secondaryDist = batchSizeDist(mobileFifoSecondary);
        final nativeDist = batchSizeDist(mobileFifoNative);

        // Per-entryType counts on portal
        final portalByType = <String, int>{};
        for (final ev in portalEvents) {
          portalByType[ev.entryType] = (portalByType[ev.entryType] ?? 0) + 1;
        }

        // ---- Print report ------------------------------------------------
        // ignore: avoid_print
        print('=' * 60);
        // ignore: avoid_print
        print('PORTAL SOAK RESULTS');
        // ignore: avoid_print
        print('=' * 60);
        // ignore: avoid_print
        print(
          'Click phase wall-time: ${clickElapsed.inMilliseconds}ms '
          '(${(clickElapsed.inMilliseconds / 1000).toStringAsFixed(1)}s)',
        );
        // ignore: avoid_print
        print('Total clicks: $totalClicks');
        // ignore: avoid_print
        print('Per-button: $clickCounts');
        // ignore: avoid_print
        print('Mobile events: ${mobileEvents.length}');
        // ignore: avoid_print
        print('Portal events: ${portalEvents.length}');
        // ignore: avoid_print
        print('Portal per-entryType: $portalByType');
        // ignore: avoid_print
        print(
          'Mobile FIFO rows — Primary: ${mobileFifoPrimary.length}, '
          'Secondary: ${mobileFifoSecondary.length}, '
          'Native: ${mobileFifoNative.length}',
        );
        // ignore: avoid_print
        print(
          'Portal FIFO rows — Primary: ${portalFifoPrimary.length}, '
          'Secondary: ${portalFifoSecondary.length}, '
          'Native: ${portalFifoNative.length}',
        );

        String distStr(Map<int, int> dist) {
          final sorted = dist.entries.toList()..sort((a, b) => b.key - a.key);
          return sorted.map((e) => '${e.value} rows×${e.key}evt').join(', ');
        }

        // ignore: avoid_print
        print('Mobile.Primary batch-size dist: ${distStr(primaryDist)}');
        // ignore: avoid_print
        print('Mobile.Secondary batch-size dist: ${distStr(secondaryDist)}');
        // ignore: avoid_print
        print('Mobile.Native batch-size dist: ${distStr(nativeDist)}');
        // ignore: avoid_print
        print(
          'Wedged FIFOs — mobile: ${await mobile.backend.anyFifoWedged()}, '
          'portal: ${await portal.backend.anyFifoWedged()}',
        );
        // ignore: avoid_print
        print('=' * 60);

        // ---- Assertions --------------------------------------------------

        // 1. Total event count parity
        expect(
          mobileEvents.length,
          equals(totalClicks),
          reason:
              'mobile must have exactly $totalClicks events '
              '(got ${mobileEvents.length})',
        );
        expect(
          portalEvents.length,
          equals(totalClicks),
          reason:
              'portal must have exactly $totalClicks events '
              '(got ${portalEvents.length})',
        );

        // 2. Per-entryType counts match between mobile and portal
        final mobileByType = <String, int>{};
        for (final ev in mobileEvents) {
          mobileByType[ev.entryType] = (mobileByType[ev.entryType] ?? 0) + 1;
        }
        for (final entryType in mobileByType.keys) {
          expect(
            portalByType[entryType],
            equals(mobileByType[entryType]),
            reason:
                'portal.$entryType count must match mobile.$entryType count',
          );
        }

        // 3. Provenance chain on every portal event
        for (final ev in portalEvents) {
          final provenanceRaw = ev.metadata['provenance'] as List<Object?>;
          final provenance = provenanceRaw.cast<Map<String, Object?>>();
          final hops = provenance.map((p) => p['hop'] as String).toList();
          expect(
            hops,
            containsAllInOrder(<String>['mobile-device', 'portal']),
            reason:
                'event ${ev.eventId} provenance hops $hops must contain '
                "['mobile-device', 'portal'] in order",
          );
        }

        // 4. No wedged FIFOs on mobile
        expect(
          await mobile.backend.anyFifoWedged(),
          isFalse,
          reason: 'mobile must have no wedged FIFOs after flush',
        );

        // 5. No wedged FIFOs on portal
        expect(
          await portal.backend.anyFifoWedged(),
          isFalse,
          reason: 'portal must have no wedged FIFOs after flush',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

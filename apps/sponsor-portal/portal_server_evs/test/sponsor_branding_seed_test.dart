// Verifies: DIARY-DEV-sponsor-branding-source/C+D — the idempotent boot seed:
//   reads <contentRoot>/<sponsorId>/sponsor-config.json + the logo asset, and
//   appends a sponsor_branding_configured event only when the materialized row
//   is absent or its content (title / asset sha256) has changed.
import 'dart:io';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/sponsor_branding_seed.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await newDatabaseFactoryMemory().openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

Future<int> _brandingEventCount(EventStore store) async {
  var n = 0;
  await for (final e in store.backend.readEventsReverse()) {
    if (e.eventType == 'sponsor_branding_configured') n++;
  }
  return n;
}

/// Lay down `<root>/<sponsorId>/sponsor-config.json` (+ optional logo bytes)
/// and return the root.
Directory _content({
  required String sponsorId,
  required String title,
  List<int>? logoBytes,
}) {
  final dir = Directory.systemTemp.createTempSync('branding_seed_');
  final base = Directory('${dir.path}/$sponsorId')..createSync(recursive: true);
  File('${base.path}/sponsor-config.json').writeAsStringSync(
    '{"sponsorId":"$sponsorId","title":"$title"}',
  );
  if (logoBytes != null) {
    final imgDir = Directory('${base.path}/portal/assets/images')
      ..createSync(recursive: true);
    File('${imgDir.path}/app_logo.png').writeAsBytesSync(logoBytes);
  }
  return dir;
}

void main() {
  test('seeds exactly one event from a sponsor-config.json', () async {
    final store = await _open('sb-seed-1');
    final root = _content(sponsorId: 'reference', title: 'Reference Study');
    addTearDown(() => root.deleteSync(recursive: true));

    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: root.path,
      sponsorId: 'reference',
    );

    expect(await _brandingEventCount(store), 1);
    final rows = await store.backend.findViewRows('sponsor_branding');
    expect(rows.single['title'], 'Reference Study');
  });

  test('running twice on unchanged content -> still one event', () async {
    final store = await _open('sb-seed-2');
    final root = _content(sponsorId: 'reference', title: 'Reference Study');
    addTearDown(() => root.deleteSync(recursive: true));

    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: root.path,
      sponsorId: 'reference',
    );
    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: root.path,
      sponsorId: 'reference',
    );

    expect(await _brandingEventCount(store), 1);
  });

  test('changing the title -> a second event', () async {
    final store = await _open('sb-seed-3');
    final root1 = _content(sponsorId: 'reference', title: 'Reference Study');
    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: root1.path,
      sponsorId: 'reference',
    );
    root1.deleteSync(recursive: true);

    final root2 = _content(sponsorId: 'reference', title: 'New Title');
    addTearDown(() => root2.deleteSync(recursive: true));
    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: root2.path,
      sponsorId: 'reference',
    );

    expect(await _brandingEventCount(store), 2);
    final rows = await store.backend.findViewRows('sponsor_branding');
    expect(rows.single['title'], 'New Title');
  });

  test('logo asset appears in the manifest with a sha256', () async {
    final store = await _open('sb-seed-logo');
    final root = _content(
      sponsorId: 'reference',
      title: 'Reference Study',
      logoBytes: const [1, 2, 3, 4],
    );
    addTearDown(() => root.deleteSync(recursive: true));

    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: root.path,
      sponsorId: 'reference',
    );

    final rows = await store.backend.findViewRows('sponsor_branding');
    final assets = (rows.single['assets'] as List).cast<Map>();
    expect(assets, hasLength(1));
    expect(assets.single['role'], 'logo');
    expect(assets.single['contentType'], 'image/png');
    expect((assets.single['sha256'] as String).isNotEmpty, isTrue);
    expect(assets.single['byteLength'], 4);
  });

  test('missing config file -> zero events, no throw', () async {
    final store = await _open('sb-seed-missing');
    final dir = Directory.systemTemp.createTempSync('branding_seed_empty_');
    addTearDown(() => dir.deleteSync(recursive: true));

    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: dir.path,
      sponsorId: 'reference',
    );

    expect(await _brandingEventCount(store), 0);
  });
}

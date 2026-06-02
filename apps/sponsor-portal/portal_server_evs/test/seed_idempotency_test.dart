// Verifies: DIARY-DEV-portal-durable-event-store/C — re-bootstrapping over a
//   populated backend appends no duplicate seed events.
import 'dart:io';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_io.dart';
import 'package:test/test.dart';

void main() {
  test('second bootstrap over the same backend does not re-seed', () async {
    final dir = Directory.systemTemp.createTempSync('seed_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final dbFactory = databaseFactoryIo;

    Future<int> grantCount(StorageBackend b) async {
      var n = 0;
      await for (final e in b.readEventsReverse()) {
        if (e.entryType == 'role_permission_grant') n++;
      }
      return n;
    }

    final db1 = await dbFactory.openDatabase('${dir.path}/a.db');
    final b1 = SembastBackend(database: db1);
    final boot1 = await bootstrapPortalServer(
        backend: b1, raveClient: DevSeedRaveClient());
    final after1 = await grantCount(b1);
    await boot1.dispose();

    final db2 = await dbFactory.openDatabase('${dir.path}/a.db');
    final b2 = SembastBackend(database: db2);
    final boot2 = await bootstrapPortalServer(
        backend: b2, raveClient: DevSeedRaveClient());
    final after2 = await grantCount(b2);
    await boot2.dispose();

    expect(after1, greaterThan(0));
    expect(after2, equals(after1), reason: 'seed must not duplicate on reboot');
  });
}

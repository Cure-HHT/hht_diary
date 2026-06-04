// Verifies: DIARY-DEV-native-outbound-sync/A — filter selects finalized +
//   tombstone DiaryEntry events, rejects checkpoint and non-diary aggregates;
//   the destination is native (serializesNatively, esd/batch@1 wireFormat).
// Verifies: DIARY-DEV-native-outbound-sync/B — send() classifies HTTP / network
//   / unresolved-url-or-jwt outcomes into SendOk / SendTransient / SendPermanent.

import 'dart:async';
import 'dart:typed_data';

import 'package:clinical_diary/destinations/diary_server_destination.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

StoredEvent _event({
  String aggregateType = 'DiaryEntry',
  String entryType = 'epistaxis_event',
  String eventType = 'finalized',
}) => StoredEvent.synthetic(
  eventId: 'evt-1',
  aggregateId: 'agg-1',
  aggregateType: aggregateType,
  entryType: entryType,
  eventType: eventType,
  data: const {'answers': <String, Object?>{}},
  metadata: const {},
  initiator: const UserInitiator('u-1'),
  clientTimestamp: DateTime.utc(2026, 1, 1),
  eventHash: 'h',
);

DiaryServerDestination _dest({
  required http.Client client,
  Future<Uri?> Function()? resolveIngestUrl,
  Future<String?> Function()? authToken,
}) => DiaryServerDestination(
  client: client,
  resolveIngestUrl:
      resolveIngestUrl ??
      () async => Uri.parse('https://diary.example.com/ingest'),
  authToken: authToken ?? () async => 'jwt-token',
);

WirePayload _payload() => WirePayload(
  bytes: Uint8List.fromList(const [1, 2, 3]),
  contentType: 'application/json',
  transformVersion: null,
);

void main() {
  group('DiaryServerDestination identity + flags', () {
    final d = _dest(client: MockClient((_) async => http.Response('', 200)));

    test('id is primary', () => expect(d.id, 'primary'));
    test('wireFormat is esd/batch@1', () {
      expect(d.wireFormat, 'esd/batch@1');
      expect(d.wireFormat, BatchEnvelope.wireFormat);
    });
    test(
      'serializesNatively is true',
      () => expect(d.serializesNatively, true),
    );
    test('maxAccumulateTime is zero', () {
      expect(d.maxAccumulateTime, Duration.zero);
    });
    test('canAddToBatch always true', () {
      expect(d.canAddToBatch(const [], _event()), true);
      expect(d.canAddToBatch([_event()], _event()), true);
    });
    test('transform throws (native path is unreachable)', () {
      expect(() => d.transform([_event()]), throwsUnimplementedError);
    });
  });

  group('DiaryServerDestination.filter', () {
    final d = _dest(client: MockClient((_) async => http.Response('', 200)));

    test('accepts finalized DiaryEntry', () {
      expect(d.filter.matches(_event(eventType: 'finalized')), true);
    });
    test('accepts tombstone DiaryEntry', () {
      expect(d.filter.matches(_event(eventType: 'tombstone')), true);
    });
    test('rejects checkpoint (drafts stay local)', () {
      expect(d.filter.matches(_event(eventType: 'checkpoint')), false);
    });
    test('rejects non-DiaryEntry aggregate', () {
      expect(
        d.filter.matches(
          _event(aggregateType: 'Settings', entryType: 'user_setting'),
        ),
        false,
      );
    });
  });

  group('DiaryServerDestination.send classification', () {
    test('2xx -> SendOk', () async {
      final d = _dest(
        client: MockClient((_) async => http.Response('ok', 200)),
      );
      expect(await d.send(_payload()), const SendOk());
    });

    test('POSTs canonical bytes verbatim with bearer auth', () async {
      late http.Request captured;
      final d = _dest(
        client: MockClient((req) async {
          captured = req;
          return http.Response('', 200);
        }),
      );
      await d.send(_payload());
      expect(captured.bodyBytes, const [1, 2, 3]);
      expect(captured.headers['authorization'], 'Bearer jwt-token');
      expect(captured.headers['content-type'], contains('application/json'));
      expect(captured.url.toString(), 'https://diary.example.com/ingest');
    });

    test('500 -> SendTransient with httpStatus', () async {
      final d = _dest(
        client: MockClient((_) async => http.Response('boom', 500)),
      );
      final r = await d.send(_payload());
      expect(r, isA<SendTransient>());
      expect((r as SendTransient).httpStatus, 500);
    });

    test('400 -> SendPermanent', () async {
      final d = _dest(
        client: MockClient((_) async => http.Response('bad', 400)),
      );
      expect(await d.send(_payload()), isA<SendPermanent>());
    });

    test(
      '401 -> SendTransient (auth not currently valid; retried, never wedged)',
      () async {
        final d = _dest(
          client: MockClient((_) async => http.Response('no', 401)),
        );
        final r = await d.send(_payload());
        expect(r, isA<SendTransient>());
        expect((r as SendTransient).httpStatus, 401);
      },
    );

    test('ClientException -> SendTransient', () async {
      final d = _dest(
        client: MockClient(
          (_) async => throw http.ClientException('socket down'),
        ),
      );
      final r = await d.send(_payload());
      expect(r, isA<SendTransient>());
      expect((r as SendTransient).httpStatus, isNull);
    });

    test('TimeoutException -> SendTransient', () async {
      final d = _dest(
        client: MockClient((_) async => throw TimeoutException('slow')),
      );
      expect(await d.send(_payload()), isA<SendTransient>());
    });

    test('null ingest URL -> SendTransient (not enrolled)', () async {
      final d = _dest(
        client: MockClient((_) async => http.Response('', 200)),
        resolveIngestUrl: () async => null,
      );
      expect(await d.send(_payload()), isA<SendTransient>());
    });

    test('null auth token -> SendTransient (not enrolled)', () async {
      final d = _dest(
        client: MockClient((_) async => http.Response('', 200)),
        authToken: () async => null,
      );
      expect(await d.send(_payload()), isA<SendTransient>());
    });
  });
}

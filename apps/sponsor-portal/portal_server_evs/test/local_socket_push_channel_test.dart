// Verifies: DIARY-DEV-pluggable-push-transport/C — registry routing by
//   participantId; absent connection -> failure terminal (no throw).
import 'package:comms/comms.dart';
import 'package:portal_server_evs/src/local_push_registry.dart';
import 'package:portal_server_evs/src/local_socket_push_channel.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    PayloadGuard.testOnlyDisable = false;
    PayloadGuard.commonNamePatterns = <RegExp>[];
  });

  group('LocalPushRegistry', () {
    test('delivers to every live connection of the participant', () {
      final registry = LocalPushRegistry();
      final a = <Map<String, dynamic>>[];
      final b = <Map<String, dynamic>>[];
      registry.register('P1', a.add);
      registry.register('P1', b.add);
      registry.register('P2', (_) => fail('P2 must not receive P1 frames'));

      final n = registry.deliver('P1', {'type': 'push'});

      expect(n, equals(2));
      expect(a, hasLength(1));
      expect(b, hasLength(1));
    });

    test('unregister drops the connection; empty participant is removed', () {
      final registry = LocalPushRegistry();
      final got = <Map<String, dynamic>>[];
      final dispose = registry.register('P1', got.add);
      expect(registry.hasConnection('P1'), isTrue);

      dispose();

      expect(registry.hasConnection('P1'), isFalse);
      expect(registry.deliver('P1', {'type': 'push'}), equals(0));
      expect(got, isEmpty);
    });

    test('deliver returns the count INVOKED even if a sink self-unregisters',
        () {
      final registry = LocalPushRegistry();
      var calls = 0;
      late void Function() disposeA;
      // Sink A unregisters itself synchronously when it receives the frame,
      // shrinking the live set mid-delivery.
      disposeA = registry.register('P1', (_) {
        calls++;
        disposeA();
      });
      registry.register('P1', (_) => calls++);

      final n = registry.deliver('P1', {'type': 'push'});

      expect(calls, equals(2), reason: 'both sinks invoked from the snapshot');
      expect(n, equals(2),
          reason: 'count reflects sinks invoked, not live-set size');
    });
  });

  group('LocalSocketPushChannel', () {
    test('name is "local"', () {
      expect(LocalSocketPushChannel(LocalPushRegistry()).name, equals('local'));
    });

    test('routes by participantId and frames data + flowToken', () async {
      final registry = LocalPushRegistry();
      final channel = LocalSocketPushChannel(registry);
      final frames = <Map<String, dynamic>>[];
      registry.register('P1', frames.add);

      final result = await channel.send(
        const PushTarget(
          participantId: 'P1',
          platform: 'linux',
          routingToken: 'device-1',
        ),
        const PushMessage(
          data: {'type': 'questionnaire_assigned', 'flowToken': 'QST1'},
          userVisible: true,
          title: 'New questionnaire',
        ),
      );

      expect(result.success, isTrue);
      expect(result.messageId, equals('local:1'));
      expect(frames, hasLength(1));
      final frame = frames.single;
      expect(frame['type'], equals('push'));
      expect(frame['userVisible'], isTrue);
      expect(frame['title'], equals('New questionnaire'));
      expect(
        frame['data'],
        equals({'type': 'questionnaire_assigned', 'flowToken': 'QST1'}),
      );
    });

    test('no live connection returns failure, never throws', () async {
      final channel = LocalSocketPushChannel(LocalPushRegistry());

      final result = await channel.send(
        const PushTarget(
          participantId: 'NOBODY',
          platform: 'linux',
          routingToken: 'device-x',
        ),
        const PushMessage(data: {'type': 'x'}, userVisible: false),
      );

      expect(result.success, isFalse);
      expect(result.error, equals('no_live_connection'));
    });

    test('PHI in data trips PayloadGuard before delivery', () async {
      final registry = LocalPushRegistry();
      final channel = LocalSocketPushChannel(registry);
      var delivered = 0;
      registry.register('P1', (_) => delivered++);

      await expectLater(
        channel.send(
          const PushTarget(
            participantId: 'P1',
            platform: 'linux',
            routingToken: 'device-1',
          ),
          const PushMessage(
            data: {'type': 'x', 'subject': '999-001-125'},
            userVisible: false,
          ),
        ),
        throwsA(isA<PhiLeakException>()),
      );
      expect(delivered, equals(0));
    });
  });
}

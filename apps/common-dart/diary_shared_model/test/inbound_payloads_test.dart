// Verifies: DIARY-DEV-shared-events-catalog/A+D
//
// Round-trip + no-secrets checks for the two diary-originated inbound payloads
// (fcm_message_received echoes flowToken per P5; fcm_token_registered carries
// the device-routing token).
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

void main() {
  group('FcmMessageReceivedPayload', () {
    test('round-trips with an echoed flowToken (P5)', () {
      const p = FcmMessageReceivedPayload(
        receivedAt: '2025-10-16T08:30:00.000Z',
        channel: InboundChannel.fcm,
        messageType: 'questionnaire_assigned',
        flowToken: 'flow-abc',
      );
      final back = FcmMessageReceivedPayload.fromJson(p.toJson());
      expect(back.receivedAt, '2025-10-16T08:30:00.000Z');
      expect(back.channel, InboundChannel.fcm);
      expect(back.messageType, 'questionnaire_assigned');
      expect(back.flowToken, 'flow-abc');
    });

    test('flowToken is optional (poll backup, no portal token)', () {
      const p = FcmMessageReceivedPayload(
        receivedAt: '2025-10-16T08:30:00.000Z',
        channel: InboundChannel.poll,
        messageType: 'tombstone',
      );
      final json = p.toJson();
      expect(json.containsKey('flowToken'), isFalse);
      expect(
        FcmMessageReceivedPayload.fromJson(json).channel,
        InboundChannel.poll,
      );
    });

    test('rejects an unknown channel', () {
      expect(
        () => FcmMessageReceivedPayload.fromJson(const {
          'received_at': '2025-10-16T08:30:00.000Z',
          'channel': 'carrier-pigeon',
          'message_type': 'tombstone',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('FcmTokenRegisteredPayload', () {
    test('round-trips token + platform + timestamp', () {
      const p = FcmTokenRegisteredPayload(
        token: 'tok-123',
        platform: DevicePlatform.android,
        registeredAt: '2025-10-16T08:30:00.000Z',
      );
      final back = FcmTokenRegisteredPayload.fromJson(p.toJson());
      expect(back.token, 'tok-123');
      expect(back.platform, DevicePlatform.android);
      expect(back.registeredAt, '2025-10-16T08:30:00.000Z');
    });

    // Verifies: DIARY-DEV-pluggable-push-transport/D — the local-stack web/Linux
    //   diary registers a routing token under a non-FCM platform tag.
    test('round-trips the local-stack web/linux platforms', () {
      for (final platform in const [
        DevicePlatform.web,
        DevicePlatform.linux,
        DevicePlatform.macos,
        DevicePlatform.windows,
      ]) {
        final p = FcmTokenRegisteredPayload(
          token: 'device-1',
          platform: platform,
          registeredAt: '2026-06-08T08:30:00.000Z',
        );
        final back = FcmTokenRegisteredPayload.fromJson(p.toJson());
        expect(back.platform, platform);
        expect(DevicePlatform.fromWire(platform.name), platform);
      }
    });

    test(
      'DIARY-DEV-shared-events-catalog/D: no OTP/session/recovery fields',
      () {
        const p = FcmTokenRegisteredPayload(
          token: 'tok-123',
          platform: DevicePlatform.ios,
          registeredAt: '2025-10-16T08:30:00.000Z',
        );
        final json = p.toJson();
        for (final forbidden in const [
          'otp',
          'recovery',
          'session',
          'password',
        ]) {
          expect(json.keys.any((k) => k.toLowerCase() == forbidden), isFalse);
        }
      },
    );
  });
}

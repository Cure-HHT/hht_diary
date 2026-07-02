import 'dart:convert';

import 'package:comms/comms.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Builds an [AdcClient] whose factory always returns the supplied
/// [http.Client] — bypasses real ADC for unit tests.
AdcClient _testAdc(http.Client client) =>
    AdcClient(authFactory: () async => client);

// Verifies: DIARY-DEV-pluggable-push-transport/A — FCM send, response mapping, APNS split
// Verifies: DIARY-DEV-push-payload-phi-safety/A+B — PayloadGuard runs before network egress
void main() {
  setUp(() {
    PayloadGuard.testOnlyDisable = false;
    PayloadGuard.commonNamePatterns = <RegExp>[];
  });

  group('FcmChannel.dispatch', () {
    test('name is "fcm"', () {
      final channel = FcmChannel(projectId: 'cure-hht-admin');
      expect(channel.name, equals('fcm'));
    });

    test('console mode short-circuits before any network call', () async {
      var requestCount = 0;
      final channel = FcmChannel(
        projectId: 'cure-hht-admin',
        consoleMode: true,
        adcClient: _testAdc(
          MockClient((_) async {
            requestCount++;
            return http.Response('', 200);
          }),
        ),
      );

      final result = await channel.dispatch(
        const FcmMessage(
          fcmToken: 'tok-1',
          data: {'type': 'participant_status_update', 'action': 'disconnect'},
          userVisible: true,
          notificationTitle: 'Account Disconnected',
        ),
      );

      expect(requestCount, equals(0));
      expect(result.success, isTrue);
      expect(result.messageId, equals('console-mode'));
    });

    test('200 response maps to success with the FCM resource name', () async {
      final channel = FcmChannel(
        projectId: 'cure-hht-admin',
        adcClient: _testAdc(
          MockClient((request) async {
            expect(
              request.url.toString(),
              equals(
                'https://fcm.googleapis.com/v1/projects/cure-hht-admin/messages:send',
              ),
            );
            return http.Response(
              jsonEncode({
                'name':
                    'projects/cure-hht-admin/messages/0:1700000000000000000',
              }),
              200,
            );
          }),
        ),
      );

      final result = await channel.dispatch(
        const FcmMessage(
          fcmToken: 'tok-1',
          data: {'type': 'questionnaire_finalized'},
          userVisible: true,
          notificationTitle: 'Questionnaire Finalized',
        ),
      );

      expect(result.outcome, equals('success'));
      expect(
        result.messageId,
        equals('projects/cure-hht-admin/messages/0:1700000000000000000'),
      );
    });

    test('404 response maps to unregisteredToken', () async {
      final channel = FcmChannel(
        projectId: 'cure-hht-admin',
        adcClient: _testAdc(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 404,
                  'message': 'Requested entity was not found.',
                  'status': 'NOT_FOUND',
                },
              }),
              404,
            ),
          ),
        ),
      );

      final result = await channel.dispatch(
        const FcmMessage(
          fcmToken: 'dead-token',
          data: {'type': 'participant_status_update'},
          userVisible: true,
          notificationTitle: 'Account Disconnected',
        ),
      );

      expect(result.outcome, equals('unregistered'));
      expect(result.unregistered, isTrue);
      expect(result.success, isFalse);
    });

    test(
      '400 with errorCode UNREGISTERED also maps to unregisteredToken',
      () async {
        final channel = FcmChannel(
          projectId: 'cure-hht-admin',
          adcClient: _testAdc(
            MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'error': {
                    'code': 400,
                    'details': [
                      {
                        '@type':
                            'type.googleapis.com/google.firebase.fcm.v1.FcmError',
                        'errorCode': 'UNREGISTERED',
                      },
                    ],
                  },
                }),
                400,
              ),
            ),
          ),
        );

        final result = await channel.dispatch(
          const FcmMessage(
            fcmToken: 'dead-token',
            data: {'type': 'participant_status_update'},
            userVisible: true,
            notificationTitle: 'Account Disconnected',
          ),
        );

        expect(result.unregistered, isTrue);
      },
    );

    test('500 maps to generic failure (not unregistered)', () async {
      final channel = FcmChannel(
        projectId: 'cure-hht-admin',
        adcClient: _testAdc(
          MockClient((_) async => http.Response('Internal Server Error', 500)),
        ),
      );

      final result = await channel.dispatch(
        const FcmMessage(
          fcmToken: 'tok-1',
          data: {'type': 'participant_status_update'},
          userVisible: true,
          notificationTitle: 'Account Disconnected',
        ),
      );

      expect(result.outcome, equals('failed'));
      expect(result.unregistered, isFalse);
      expect(result.error, contains('500'));
    });

    test(
      'PayloadGuard runs BEFORE the network call — PHI in title throws and skips POST',
      () async {
        var requestCount = 0;
        final channel = FcmChannel(
          projectId: 'cure-hht-admin',
          adcClient: _testAdc(
            MockClient((_) async {
              requestCount++;
              return http.Response('', 200);
            }),
          ),
        );

        expect(
          () => channel.dispatch(
            const FcmMessage(
              fcmToken: 'tok-1',
              data: {'type': 'questionnaire_finalized'},
              userVisible: true,
              // SubjectKey embedded in title — must trip the guard.
              notificationTitle: 'Participant 999-001-125 finalized',
            ),
          ),
          throwsA(isA<PhiLeakException>()),
        );

        // Allow the dispatch future to settle so any pending POST would
        // have fired by now.
        await Future<void>.delayed(Duration.zero);
        expect(requestCount, equals(0));
      },
    );

    test('PayloadGuard catches PHI in data values', () async {
      final channel = FcmChannel(
        projectId: 'cure-hht-admin',
        adcClient: _testAdc(MockClient((_) async => http.Response('', 200))),
      );

      expect(
        () => channel.dispatch(
          const FcmMessage(
            fcmToken: 'tok-1',
            data: {
              'type': 'participant_status_update',
              // Email in payload — must trip.
              'extra': 'coordinator@site.example.com',
            },
            userVisible: true,
            notificationTitle: 'Account Disconnected',
          ),
        ),
        throwsA(isA<PhiLeakException>()),
      );
    });

    group(
      'APNS payload split (DIARY-DEV-pluggable-push-transport / DIARY-PRD-notification-behavior)',
      () {
        test(
          'userVisible=true sends priority=10 with no content-available',
          () async {
            late Map<String, dynamic> sentMessage;
            final channel = FcmChannel(
              projectId: 'cure-hht-admin',
              adcClient: _testAdc(
                MockClient((request) async {
                  final body = jsonDecode(request.body) as Map<String, dynamic>;
                  sentMessage = body['message'] as Map<String, dynamic>;
                  return http.Response(jsonEncode({'name': 'msg-1'}), 200);
                }),
              ),
            );

            await channel.dispatch(
              const FcmMessage(
                fcmToken: 'tok-1',
                data: {'type': 'questionnaire_finalized'},
                userVisible: true,
                notificationTitle: 'Questionnaire Finalized',
                notificationBody: 'Your questionnaire is locked.',
              ),
            );

            final apns = sentMessage['apns'] as Map<String, dynamic>;
            expect(
              apns['headers'],
              equals({'apns-priority': '10', 'apns-push-type': 'alert'}),
              reason:
                  'apns-push-type=alert required on iOS 13+ for user-visible push',
            );
            expect(apns.containsKey('payload'), isFalse);
            // notification block present (system tray).
            expect(sentMessage.containsKey('notification'), isTrue);
          },
        );

        test(
          'userVisible=false sends priority=5 with content-available=1',
          () async {
            late Map<String, dynamic> sentMessage;
            final channel = FcmChannel(
              projectId: 'cure-hht-admin',
              adcClient: _testAdc(
                MockClient((request) async {
                  final body = jsonDecode(request.body) as Map<String, dynamic>;
                  sentMessage = body['message'] as Map<String, dynamic>;
                  return http.Response(jsonEncode({'name': 'msg-1'}), 200);
                }),
              ),
            );

            await channel.dispatch(
              const FcmMessage(
                fcmToken: 'tok-1',
                data: {'type': 'questionnaire_deleted'},
                userVisible: false,
              ),
            );

            final apns = sentMessage['apns'] as Map<String, dynamic>;
            expect(
              apns['headers'],
              equals({'apns-priority': '5', 'apns-push-type': 'background'}),
              reason:
                  'apns-push-type=background required on iOS 13+ — without it '
                  'APNs silently drops the message even though FCM returns 200',
            );
            final apnsPayload = apns['payload'] as Map<String, dynamic>;
            final aps = apnsPayload['aps'] as Map<String, dynamic>;
            expect(aps['content-available'], equals(1));
            expect(sentMessage.containsKey('notification'), isFalse);
          },
        );
      },
    );

    // Verifies: DIARY-DEV-pluggable-push-transport/A — FcmChannel is the FCM
    //   adapter of the neutral PushChannel.send seam; the routingToken becomes
    //   the FCM token and the message maps straight onto the v1 payload.
    group('FcmChannel.send (PushChannel adapter)', () {
      test(
        'maps PushTarget.routingToken -> FCM token + builds v1 payload',
        () async {
          late Map<String, dynamic> sentMessage;
          final channel = FcmChannel(
            projectId: 'cure-hht-admin',
            adcClient: _testAdc(
              MockClient((request) async {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                sentMessage = body['message'] as Map<String, dynamic>;
                return http.Response(jsonEncode({'name': 'msg-7'}), 200);
              }),
            ),
          );

          final result = await channel.send(
            const PushTarget(
              participantId: 'P1',
              platform: 'android',
              routingToken: 'tok-route',
            ),
            const PushMessage(
              data: {'type': 'questionnaire_assigned', 'flowToken': 'QST1'},
              userVisible: true,
              title: 'New questionnaire',
            ),
          );

          expect(result.success, isTrue);
          expect(result.messageId, equals('msg-7'));
          expect(sentMessage['token'], equals('tok-route'));
          expect(
            sentMessage['data'],
            equals({'type': 'questionnaire_assigned', 'flowToken': 'QST1'}),
          );
          final notification =
              sentMessage['notification'] as Map<String, dynamic>;
          expect(notification['title'], equals('New questionnaire'));
        },
      );
    });
  });
}

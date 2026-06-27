import 'package:comms/comms.dart';
import 'package:test/test.dart';

// Verifies: DIARY-DEV-push-payload-phi-safety/A+B+C+D — pattern coverage, rejection, fail-closed, test-only bypass
void main() {
  group('PayloadGuard.assertSafeText', () {
    setUp(() {
      // Reset shared static state so tests don't leak into each other.
      PayloadGuard.testOnlyDisable = false;
      PayloadGuard.commonNamePatterns = <RegExp>[];
    });

    group('subject_key pattern (DIARY-DEV-push-payload-phi-safety)', () {
      test('rejects strict 3-3-3 SubjectKey', () {
        expect(
          () => PayloadGuard.assertSafeText(
            'Participant 999-001-125 was disconnected',
            fieldName: 'envelope.body',
          ),
          throwsA(
            isA<PhiLeakException>()
                .having((e) => e.field, 'field', 'envelope.body')
                .having(
                  (e) => e.matchedPattern,
                  'matchedPattern',
                  'subject_key',
                ),
          ),
        );
      });

      test('rejects extended SubjectKey with uppercase suffix', () {
        // Real-world keys have an optional letter on the middle group.
        expect(
          () => PayloadGuard.assertSafeText(
            'subject 999-001A-125',
            fieldName: 'envelope.title',
          ),
          throwsA(isA<PhiLeakException>()),
        );
      });

      test('does not match a 4-3-3 lookalike', () {
        // \b boundaries mean a longer leading digit run isn't a hit.
        expect(
          () => PayloadGuard.assertSafeText(
            'Order 1234-567-890 confirmed',
            fieldName: 'envelope.body',
          ),
          returnsNormally,
        );
      });

      test('does not match raw 9-digit run', () {
        expect(
          () => PayloadGuard.assertSafeText(
            'Reference 999001125 in audit',
            fieldName: 'envelope.body',
          ),
          returnsNormally,
        );
      });
    });

    group('email pattern (DIARY-DEV-push-payload-phi-safety)', () {
      test('rejects an email address', () {
        expect(
          () => PayloadGuard.assertSafeText(
            'Contact coordinator@site.example.com for help',
            fieldName: 'envelope.body',
          ),
          throwsA(
            isA<PhiLeakException>().having(
              (e) => e.matchedPattern,
              'matchedPattern',
              'email',
            ),
          ),
        );
      });

      test('does not match plain "@" sign without a domain', () {
        expect(
          () => PayloadGuard.assertSafeText(
            'Notify @everyone in the channel',
            fieldName: 'envelope.body',
          ),
          returnsNormally,
        );
      });
    });

    group('common_name patterns (DIARY-DEV-push-payload-phi-safety)', () {
      test('rejects a configured coordinator name', () {
        PayloadGuard.commonNamePatterns = <RegExp>[
          RegExp(r'\bDr\.\s+Watson\b', caseSensitive: false),
        ];
        expect(
          () => PayloadGuard.assertSafeText(
            'Sent by Dr. Watson on Tuesday',
            fieldName: 'envelope.body',
          ),
          throwsA(
            isA<PhiLeakException>().having(
              (e) => e.matchedPattern,
              'matchedPattern',
              'common_name',
            ),
          ),
        );
      });

      test('default empty list is permissive', () {
        // Sponsors that don't bootstrap a list must not see false hits.
        expect(
          () => PayloadGuard.assertSafeText(
            'Account Disconnected',
            fieldName: 'envelope.title',
          ),
          returnsNormally,
        );
      });
    });

    group('real S2 notification titles (regression floor)', () {
      // The notification titles wired in S2 must never trip the guard.
      const safeTitles = <String>[
        'New Questionnaire Available',
        'Questionnaire Unlocked',
        'Questionnaire Finalized',
        'Account Disconnected',
        'Account Reactivated',
        'Trial Started',
      ];

      for (final title in safeTitles) {
        test('"$title" passes', () {
          expect(
            () => PayloadGuard.assertSafeText(title, fieldName: 'title'),
            returnsNormally,
          );
        });
      }
    });

    test(
      'throws PhiLeakException — not a generic Exception (DIARY-DEV-push-payload-phi-safety)',
      () {
        // Type discrimination matters: callers catch PhiLeakException to
        // log severity ERROR; a generic catch would swallow other errors.
        try {
          PayloadGuard.assertSafeText(
            '999-001-125',
            fieldName: 'envelope.title',
          );
          fail('should have thrown');
        } on PhiLeakException catch (e) {
          expect(e.field, equals('envelope.title'));
          expect(e.matchedPattern, equals('subject_key'));
        }
      },
    );

    group('testOnlyDisable bypass (DIARY-DEV-push-payload-phi-safety)', () {
      test('flag bypasses the check in non-release mode', () {
        PayloadGuard.testOnlyDisable = true;
        expect(
          () => PayloadGuard.assertSafeText(
            '999-001-125',
            fieldName: 'envelope.title',
          ),
          returnsNormally,
        );
      });
    });
  });

  group('PayloadGuard.assertSafeStringMap', () {
    setUp(() {
      PayloadGuard.testOnlyDisable = false;
      PayloadGuard.commonNamePatterns = <RegExp>[];
    });

    test('namespaces failing key in the field path', () {
      expect(
        () => PayloadGuard.assertSafeStringMap({
          'type': 'questionnaire_finalized',
          'participant': '999-001-125',
        }, fieldPrefix: 'fcmMessage.data'),
        throwsA(
          isA<PhiLeakException>().having(
            (e) => e.field,
            'field',
            'fcmMessage.data.participant',
          ),
        ),
      );
    });

    test('passes a clean payload', () {
      expect(
        () => PayloadGuard.assertSafeStringMap({
          'type': 'questionnaire_finalized',
          'questionnaire_instance_id': 'inst-123',
          'action': 'lock_task',
        }, fieldPrefix: 'fcmMessage.data'),
        returnsNormally,
      );
    });
  });
}

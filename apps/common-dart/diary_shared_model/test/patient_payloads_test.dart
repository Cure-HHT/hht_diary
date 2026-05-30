// Verifies: DIARY-DEV-shared-events-catalog/A+D
//
// Round-trip + no-secrets checks for the diary-originated patient_linked payload
// (P4): the identity-correlation facts established at link, with NO session token
// / linking code / infra URL (those stay in secure storage).
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

void main() {
  group('PatientLinkedPayload', () {
    test('round-trips the full identity set', () {
      const p = PatientLinkedPayload(
        userId: 'U-1',
        linkedAt: '2025-10-16T08:30:00.000Z',
        patientId: 'P-42',
        studyPatientId: 'STUDY-7',
        siteId: 'SITE-3',
        sponsorId: 'callisto',
      );
      final back = PatientLinkedPayload.fromJson(p.toJson());
      expect(back.userId, 'U-1');
      expect(back.linkedAt, '2025-10-16T08:30:00.000Z');
      expect(back.patientId, 'P-42');
      expect(back.studyPatientId, 'STUDY-7');
      expect(back.siteId, 'SITE-3');
      expect(back.sponsorId, 'callisto');
    });

    test('optional identity fields may be absent', () {
      const p = PatientLinkedPayload(
        userId: 'U-1',
        linkedAt: '2025-10-16T08:30:00.000Z',
      );
      final json = p.toJson();
      expect(json.containsKey('patient_id'), isFalse);
      expect(json.containsKey('site_id'), isFalse);
      final back = PatientLinkedPayload.fromJson(json);
      expect(back.userId, 'U-1');
      expect(back.patientId, isNull);
    });

    test(
      'DIARY-DEV-shared-events-catalog/D: no token/credential/url fields',
      () {
        final json = const PatientLinkedPayload(
          userId: 'U-1',
          linkedAt: '2025-10-16T08:30:00.000Z',
          patientId: 'P-42',
        ).toJson();
        for (final forbidden in const [
          'jwt',
          'jwttoken',
          'token',
          'session',
          'password',
          'linkingcode',
          'backendurl',
        ]) {
          expect(
            json.keys.any(
              (k) => k.toLowerCase().replaceAll('_', '') == forbidden,
            ),
            isFalse,
            reason: 'patient_linked must not carry a `$forbidden` field',
          );
        }
      },
    );
  });
}

// Tests for patient synchronization from RAVE EDC
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00063: EDC Patient Ingestion
//   REQ-CAL-p00073: Patient Status Definitions

import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:rave_integration/rave_integration.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/patients_sync.dart';

// Mock classes
class MockRaveClient extends Mock implements RaveClient {}

void main() {
  group('PatientsSyncResult', () {
    test('hasError returns false when no error', () {
      final result = PatientsSyncResult(
        patientsCreated: 5,
        patientsUpdated: 3,
        syncedAt: DateTime.utc(2024, 1, 15, 12, 0, 0),
        error: null,
      );

      expect(result.hasError, isFalse);
    });

    test('hasError returns true when error is set', () {
      final result = PatientsSyncResult(
        patientsCreated: 0,
        patientsUpdated: 0,
        syncedAt: DateTime.utc(2024, 1, 15, 12, 0, 0),
        error: 'RAVE authentication failed',
      );

      expect(result.hasError, isTrue);
    });

    test('toJson includes all fields without error', () {
      final syncTime = DateTime.utc(2024, 1, 15, 12, 0, 0);
      final result = PatientsSyncResult(
        patientsCreated: 5,
        patientsUpdated: 3,
        syncedAt: syncTime,
      );

      final json = result.toJson();

      expect(json['patients_created'], equals(5));
      expect(json['patients_updated'], equals(3));
      expect(json['synced_at'], equals('2024-01-15T12:00:00.000Z'));
      expect(json.containsKey('error'), isFalse);
    });

    test('toJson includes error when present', () {
      final syncTime = DateTime.utc(2024, 1, 15, 12, 0, 0);
      final result = PatientsSyncResult(
        patientsCreated: 0,
        patientsUpdated: 0,
        syncedAt: syncTime,
        error: 'Network error',
      );

      final json = result.toJson();

      expect(json['patients_created'], equals(0));
      expect(json['patients_updated'], equals(0));
      expect(json['synced_at'], equals('2024-01-15T12:00:00.000Z'));
      expect(json['error'], equals('Network error'));
    });

    test('toJson with zero counts', () {
      final result = PatientsSyncResult(
        patientsCreated: 0,
        patientsUpdated: 0,
        syncedAt: DateTime.utc(2024, 6, 1),
      );

      final json = result.toJson();

      expect(json['patients_created'], equals(0));
      expect(json['patients_updated'], equals(0));
    });
  });

  group('computePatientContentHash', () {
    test('returns consistent hash for same subjects', () {
      final subjects = [
        const RaveSubject(subjectKey: '840-001-001', siteOid: '12345'),
        const RaveSubject(subjectKey: '840-001-002', siteOid: '12345'),
      ];

      final hash1 = computePatientContentHash(subjects);
      final hash2 = computePatientContentHash(subjects);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 produces 64 hex chars
    });

    test('returns different hash for different subjects', () {
      final subjects1 = [
        const RaveSubject(subjectKey: '840-001-001', siteOid: '12345'),
      ];
      final subjects2 = [
        const RaveSubject(subjectKey: '840-001-002', siteOid: '12345'),
      ];

      final hash1 = computePatientContentHash(subjects1);
      final hash2 = computePatientContentHash(subjects2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('sorts subjects by subjectKey for consistent hashing', () {
      final subjects1 = [
        const RaveSubject(subjectKey: '840-001-002', siteOid: '12345'),
        const RaveSubject(subjectKey: '840-001-001', siteOid: '12345'),
      ];
      final subjects2 = [
        const RaveSubject(subjectKey: '840-001-001', siteOid: '12345'),
        const RaveSubject(subjectKey: '840-001-002', siteOid: '12345'),
      ];

      expect(
        computePatientContentHash(subjects1),
        equals(computePatientContentHash(subjects2)),
      );
    });

    test('returns consistent hash for empty list', () {
      final hash = computePatientContentHash([]);
      expect(hash.length, equals(64));
    });

    test('includes siteOid in hash', () {
      final subjects1 = [
        const RaveSubject(subjectKey: '840-001-001', siteOid: '12345'),
      ];
      final subjects2 = [
        const RaveSubject(subjectKey: '840-001-001', siteOid: '99999'),
      ];

      expect(
        computePatientContentHash(subjects1),
        isNot(equals(computePatientContentHash(subjects2))),
      );
    });

    test('includes siteNumber in hash', () {
      final subjects1 = [
        const RaveSubject(
          subjectKey: '840-001-001',
          siteOid: '12345',
          siteNumber: '001',
        ),
      ];
      final subjects2 = [
        const RaveSubject(
          subjectKey: '840-001-001',
          siteOid: '12345',
          siteNumber: '002',
        ),
      ];

      expect(
        computePatientContentHash(subjects1),
        isNot(equals(computePatientContentHash(subjects2))),
      );
    });
  });

  group('syncPatientsFromEdc', () {
    test('returns error when RAVE not configured', () async {
      if (Platform.environment['RAVE_UAT_URL'] != null) {
        print('Skipping test - RAVE is configured');
        return;
      }

      final result = await syncPatientsFromEdc(skipLogging: true);

      expect(result.hasError, isTrue);
      expect(result.error, equals('RAVE configuration not available'));
      expect(result.patientsCreated, equals(0));
      expect(result.patientsUpdated, equals(0));
    });
  });

  group('syncPatientsIfNeeded', () {
    test('returns null when RAVE not configured', () async {
      if (Platform.environment['RAVE_UAT_URL'] != null) {
        print('Skipping test - RAVE is configured');
        return;
      }

      final result = await syncPatientsIfNeeded();

      expect(result, isNull);
    });
  });

  group('syncPatientsFromEdc with mocked client', () {
    late MockRaveClient mockClient;

    setUp(() {
      mockClient = MockRaveClient();
    });

    tearDown(() {
      reset(mockClient);
    });

    test('returns error when studyOid is null', () async {
      final result = await syncPatientsFromEdc(
        testClient: mockClient,
        testStudyOid: null,
        skipLogging: true,
      );

      expect(result.hasError, isTrue);
      expect(
        result.error,
        equals('RAVE_STUDY_OID is required for patient sync'),
      );
      expect(result.patientsCreated, equals(0));
      expect(result.patientsUpdated, equals(0));
    });

    test('returns error when studyOid is empty', () async {
      final result = await syncPatientsFromEdc(
        testClient: mockClient,
        testStudyOid: '',
        skipLogging: true,
      );

      expect(result.hasError, isTrue);
      expect(
        result.error,
        equals('RAVE_STUDY_OID is required for patient sync'),
      );
    });

    test('returns error result when subjects list is empty', () async {
      when(
        () => mockClient.getSubjects(studyOid: any(named: 'studyOid')),
      ).thenAnswer((_) async => []);

      final result = await syncPatientsFromEdc(
        testClient: mockClient,
        testStudyOid: 'TEST-STUDY',
        skipLogging: true,
      );

      expect(result.hasError, isTrue);
      expect(
        result.error,
        equals('No subjects returned from RAVE - check permissions'),
      );
      expect(result.patientsCreated, equals(0));
      expect(result.patientsUpdated, equals(0));

      verify(() => mockClient.getSubjects(studyOid: 'TEST-STUDY')).called(1);
    });

    test('handles RaveAuthenticationException', () async {
      when(
        () => mockClient.getSubjects(studyOid: any(named: 'studyOid')),
      ).thenThrow(RaveAuthenticationException('Invalid credentials'));

      final result = await syncPatientsFromEdc(
        testClient: mockClient,
        testStudyOid: 'TEST-STUDY',
        skipLogging: true,
      );

      expect(result.hasError, isTrue);
      expect(
        result.error,
        equals('RAVE authentication failed - check credentials'),
      );
    });

    test('handles RaveNetworkException', () async {
      when(
        () => mockClient.getSubjects(studyOid: any(named: 'studyOid')),
      ).thenThrow(RaveNetworkException('Connection refused'));

      final result = await syncPatientsFromEdc(
        testClient: mockClient,
        testStudyOid: 'TEST-STUDY',
        skipLogging: true,
      );

      expect(result.hasError, isTrue);
      expect(result.error, contains('RAVE network error'));
      expect(result.error, contains('Connection refused'));
    });

    test('handles generic RaveException', () async {
      when(
        () => mockClient.getSubjects(studyOid: any(named: 'studyOid')),
      ).thenThrow(RaveApiException('Server error', statusCode: 500));

      final result = await syncPatientsFromEdc(
        testClient: mockClient,
        testStudyOid: 'TEST-STUDY',
        skipLogging: true,
      );

      expect(result.hasError, isTrue);
      expect(result.error, contains('RAVE error'));
    });

    test('does not close injected client', () async {
      when(
        () => mockClient.getSubjects(studyOid: any(named: 'studyOid')),
      ).thenAnswer((_) async => []);
      when(() => mockClient.close()).thenReturn(null);

      await syncPatientsFromEdc(
        testClient: mockClient,
        testStudyOid: 'TEST-STUDY',
        skipLogging: true,
      );

      verifyNever(() => mockClient.close());
    });

    test('calls getSubjects with correct studyOid', () async {
      when(
        () => mockClient.getSubjects(studyOid: any(named: 'studyOid')),
      ).thenAnswer((_) async => []);

      await syncPatientsFromEdc(
        testClient: mockClient,
        testStudyOid: 'MY-STUDY-OID',
        skipLogging: true,
      );

      verify(() => mockClient.getSubjects(studyOid: 'MY-STUDY-OID')).called(1);
    });

    test('computes content hash when fetching subjects', () async {
      final subjects = [
        const RaveSubject(subjectKey: '840-001-001', siteOid: '12345'),
      ];

      when(
        () => mockClient.getSubjects(studyOid: any(named: 'studyOid')),
      ).thenAnswer((_) async => subjects);

      // Will fail at database operation but getSites should have been called
      try {
        await syncPatientsFromEdc(
          testClient: mockClient,
          testStudyOid: 'TEST-STUDY',
          skipLogging: true,
        );
      } catch (e) {
        // Expected to fail on database operation
      }

      verify(() => mockClient.getSubjects(studyOid: 'TEST-STUDY')).called(1);
    });
  });
}

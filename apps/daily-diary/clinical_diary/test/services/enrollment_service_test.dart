// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p70007: Linking Code Lifecycle Management

import 'dart:convert';

import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  group('EnrollmentService', () {
    late MockSecureStorage mockStorage;
    late EnrollmentService service;

    setUp(() {
      mockStorage = MockSecureStorage();
      // Pre-set auth JWT token - required for enrollment/linking
      mockStorage.data['auth_jwt'] = 'test-jwt-token';
      mockStorage.data['auth_username'] = 'test-user-id';
    });

    tearDown(() {
      service.dispose();
    });

    group('isEnrolled', () {
      test('returns false when no enrollment exists', () async {
        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final result = await service.isEnrolled();

        expect(result, false);
      });

      test('returns true when enrollment exists', () async {
        final enrollment = UserEnrollment(
          userId: 'user-123',
          jwtToken: 'token-abc',
          enrolledAt: DateTime.now(),
        );
        mockStorage.data['user_enrollment'] = jsonEncode(enrollment.toJson());

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final result = await service.isEnrolled();

        expect(result, true);
      });
    });

    group('getEnrollment', () {
      test('returns null when no enrollment exists', () async {
        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final result = await service.getEnrollment();

        expect(result, isNull);
      });

      test('returns enrollment when exists', () async {
        final enrollment = UserEnrollment(
          userId: 'user-456',
          jwtToken: 'token-xyz',
          enrolledAt: DateTime(2024, 1, 15),
        );
        mockStorage.data['user_enrollment'] = jsonEncode(enrollment.toJson());

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final result = await service.getEnrollment();

        expect(result, isNotNull);
        expect(result!.userId, 'user-456');
        expect(result.jwtToken, 'token-xyz');
      });

      test('returns null for corrupted storage data', () async {
        mockStorage.data['user_enrollment'] = 'not-valid-json';

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final result = await service.getEnrollment();

        expect(result, isNull);
      });
    });

    group('enroll', () {
      // Note: The enroll() method now requires a pre-existing JWT token
      // (set in setUp via mockStorage.data['auth_jwt'])

      test('successfully links with valid 10-character code', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['Content-Type'], 'application/json');
          expect(request.headers['Authorization'], 'Bearer test-jwt-token');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          // Code should be uppercase with dash removed
          expect(body['code'], 'CAXXXXXXXX');

          return http.Response(
            jsonEncode({
              'success': true,
              'patientId': 'patient-123',
              'siteId': 'site-001',
              'siteName': 'Test Site',
              'studyPatientId': 'STUDY-001',
            }),
            200,
          );
        });

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: mockClient,
        );

        final result = await service.enroll('CAXXX-XXXXX');

        expect(result.userId, 'test-user-id');
        expect(result.jwtToken, 'test-jwt-token');
        expect(result.patientId, 'patient-123');
        expect(result.siteId, 'site-001');
        expect(result.siteName, 'Test Site');
        expect(result.enrolledAt, isNotNull);
        expect(result.isLinkedToClinicalTrial, isTrue);

        // Verify it was saved
        final saved = await service.getEnrollment();
        expect(saved, isNotNull);
        expect(saved!.patientId, 'patient-123');
      });

      test('normalizes code to uppercase and removes dash', () async {
        String? capturedCode;
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          capturedCode = body['code'] as String?;
          return http.Response(
            jsonEncode({'success': true, 'patientId': 'p1', 'siteId': 's1'}),
            200,
          );
        });

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: mockClient,
        );

        await service.enroll('CaXxX-yYyYy');

        expect(capturedCode, 'CAXXXYyyyy'.toUpperCase());
      });

      test('trims whitespace from code', () async {
        String? capturedCode;
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          capturedCode = body['code'] as String?;
          return http.Response(
            jsonEncode({'success': true, 'patientId': 'p1', 'siteId': 's1'}),
            200,
          );
        });

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: mockClient,
        );

        await service.enroll('  CABCD-EFGHI  ');

        expect(capturedCode, 'CABCDEFGHI');
      });

      test('throws authRequired when no JWT token exists', () async {
        mockStorage.data.remove('auth_jwt');
        mockStorage.data.remove('user_enrollment');

        final mockClient = MockClient((request) async {
          return http.Response('{}', 200);
        });

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: mockClient,
        );

        expect(
          () => service.enroll('CAXXXXXXXX'),
          throwsA(
            allOf(
              isA<EnrollmentException>(),
              predicate<EnrollmentException>(
                (e) => e.type == EnrollmentErrorType.authRequired,
              ),
            ),
          ),
        );
      });

      test('throws EnrollmentException with codeAlreadyUsed for 409', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Code already used"}', 409);
        });

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: mockClient,
        );

        expect(
          () => service.enroll('CAXXXXXXXX'),
          throwsA(
            allOf(
              isA<EnrollmentException>(),
              predicate<EnrollmentException>(
                (e) => e.type == EnrollmentErrorType.codeAlreadyUsed,
              ),
            ),
          ),
        );
      });

      test('throws EnrollmentException with codeExpired for 410', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Code expired"}', 410);
        });

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: mockClient,
        );

        expect(
          () => service.enroll('CAXXXXXXXX'),
          throwsA(
            allOf(
              isA<EnrollmentException>(),
              predicate<EnrollmentException>(
                (e) => e.type == EnrollmentErrorType.codeExpired,
              ),
            ),
          ),
        );
      });

      test('throws EnrollmentException with invalidCode for 400', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Invalid code"}', 400);
        });

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: mockClient,
        );

        expect(
          () => service.enroll('INVALID'),
          throwsA(
            allOf(
              isA<EnrollmentException>(),
              predicate<EnrollmentException>(
                (e) => e.type == EnrollmentErrorType.invalidCode,
              ),
            ),
          ),
        );
      });

      test('throws EnrollmentException with serverError for 500', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Internal error"}', 500);
        });

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: mockClient,
        );

        expect(
          () => service.enroll('CAXXXXXXXX'),
          throwsA(
            allOf(
              isA<EnrollmentException>(),
              predicate<EnrollmentException>(
                (e) => e.type == EnrollmentErrorType.serverError,
              ),
            ),
          ),
        );
      });

      test(
        'throws EnrollmentException with networkError on ClientException',
        () async {
          final mockClient = MockClient((request) async {
            throw http.ClientException('Network error');
          });

          service = EnrollmentService(
            secureStorage: mockStorage,
            httpClient: mockClient,
          );

          expect(
            () => service.enroll('CAXXXXXXXX'),
            throwsA(
              allOf(
                isA<EnrollmentException>(),
                predicate<EnrollmentException>(
                  (e) => e.type == EnrollmentErrorType.networkError,
                ),
              ),
            ),
          );
        },
      );
    });

    group('clearEnrollment', () {
      test('removes enrollment from storage', () async {
        final enrollment = UserEnrollment(
          userId: 'user-123',
          jwtToken: 'token-abc',
          enrolledAt: DateTime.now(),
        );
        mockStorage.data['user_enrollment'] = jsonEncode(enrollment.toJson());

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        // Verify it exists
        expect(await service.isEnrolled(), true);

        await service.clearEnrollment();

        expect(await service.isEnrolled(), false);
        expect(await service.getEnrollment(), isNull);
      });
    });

    group('getJwtToken', () {
      test('returns null when not enrolled and no auth token', () async {
        // Clear the pre-set auth tokens for this test
        mockStorage.data.remove('auth_jwt');
        mockStorage.data.remove('user_enrollment');

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final token = await service.getJwtToken();

        expect(token, isNull);
      });

      test('returns token when enrolled', () async {
        final enrollment = UserEnrollment(
          userId: 'user-123',
          jwtToken: 'my-jwt-token',
          enrolledAt: DateTime.now(),
        );
        mockStorage.data['user_enrollment'] = jsonEncode(enrollment.toJson());

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final token = await service.getJwtToken();

        expect(token, 'my-jwt-token');
      });
    });
  });

  group('EnrollmentException', () {
    test('toString returns message', () {
      final exception = EnrollmentException(
        'Test error message',
        EnrollmentErrorType.invalidCode,
      );

      expect(exception.toString(), 'Test error message');
    });

    test('stores message and type correctly', () {
      final exception = EnrollmentException(
        'Network failed',
        EnrollmentErrorType.networkError,
      );

      expect(exception.message, 'Network failed');
      expect(exception.type, EnrollmentErrorType.networkError);
    });
  });

  group('EnrollmentErrorType', () {
    test('has all expected values', () {
      expect(
        EnrollmentErrorType.values,
        contains(EnrollmentErrorType.invalidCode),
      );
      expect(
        EnrollmentErrorType.values,
        contains(EnrollmentErrorType.codeAlreadyUsed),
      );
      expect(
        EnrollmentErrorType.values,
        contains(EnrollmentErrorType.codeExpired),
      );
      expect(
        EnrollmentErrorType.values,
        contains(EnrollmentErrorType.authRequired),
      );
      expect(
        EnrollmentErrorType.values,
        contains(EnrollmentErrorType.serverError),
      );
      expect(
        EnrollmentErrorType.values,
        contains(EnrollmentErrorType.networkError),
      );
    });
  });
}

/// Mock implementation of FlutterSecureStorage for testing
class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(data);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.clear();
  }

  @override
  IOSOptions get iOptions => IOSOptions.defaultOptions;

  @override
  AndroidOptions get aOptions => AndroidOptions.defaultOptions;

  @override
  LinuxOptions get lOptions => LinuxOptions.defaultOptions;

  @override
  WebOptions get webOptions => WebOptions.defaultOptions;

  @override
  MacOsOptions get mOptions => MacOsOptions.defaultOptions;

  @override
  WindowsOptions get wOptions => WindowsOptions.defaultOptions;

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => true;

  @override
  Stream<bool> get onCupertinoProtectedDataAvailabilityChanged =>
      Stream.value(true);

  @override
  void registerListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterAllListeners() {}

  @override
  void unregisterAllListenersForKey({required String key}) {}
}

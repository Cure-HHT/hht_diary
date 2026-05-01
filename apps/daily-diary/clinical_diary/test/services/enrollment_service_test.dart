// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-p05004: Disconnection Notification (persistent banner)

import 'dart:convert';

import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  group('EnrollmentService', () {
    late MockSecureStorage mockStorage;
    late EnrollmentService service;

    setUp(() {
      mockStorage = MockSecureStorage();
      // Note: JWT is now returned by /link endpoint, not required beforehand
    });

    tearDown(() {
      service.dispose();
    });

    group('isEnrolled', () {
      test('returns false when no linking exists', () async {
        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final result = await service.isEnrolled();

        expect(result, false);
      });

      test('returns true when linking exists', () async {
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
      test('returns null when no linking exists', () async {
        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        final result = await service.getEnrollment();

        expect(result, isNull);
      });

      test('returns linking when exists', () async {
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
      // Note: The enroll() method no longer requires a pre-existing JWT token
      // The linking code IS the authentication - server returns JWT on success

      test('successfully links with valid 10-character code', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['Content-Type'], 'application/json');
          // No Authorization header - linking code is the auth

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          // Code should be uppercase with dash removed
          expect(body['code'], 'CAXXXXXXXX');

          return http.Response(
            jsonEncode({
              'success': true,
              'jwt': 'server-returned-jwt',
              'userId': 'server-user-id',
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

        expect(result.userId, 'server-user-id');
        expect(result.jwtToken, 'server-returned-jwt');
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
            jsonEncode({
              'success': true,
              'jwt': 'jwt',
              'userId': 'uid',
              'patientId': 'p1',
              'siteId': 's1',
            }),
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
            jsonEncode({
              'success': true,
              'jwt': 'jwt',
              'userId': 'uid',
              'patientId': 'p1',
              'siteId': 's1',
            }),
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

      test('throws serverError when server response missing JWT', () async {
        // Server returns 200 but missing jwt/userId fields
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'success': true, 'patientId': 'p1'}),
            200,
          );
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

      // CUR-1055: device already enrolled tests
      test(
        'throws deviceAlreadyEnrolled when enrollment already in storage',
        () async {
          // Pre-populate storage so the device appears already enrolled
          final existing = UserEnrollment(
            userId: 'existing-user',
            jwtToken: 'existing-jwt',
            enrolledAt: DateTime.now(),
          );
          mockStorage.data['user_enrollment'] = jsonEncode(existing.toJson());
          // CUR-1164: patient is NOT disconnected, so re-enrollment is blocked
          SharedPreferences.setMockInitialValues({
            'patient_disconnected': false,
          });

          var httpCalled = false;
          final mockClient = MockClient((request) async {
            httpCalled = true;
            return http.Response('{}', 200);
          });

          service = EnrollmentService(
            secureStorage: mockStorage,
            httpClient: mockClient,
          );

          await expectLater(
            () => service.enroll('CAXXXXXXXX'),
            throwsA(
              allOf(
                isA<EnrollmentException>(),
                predicate<EnrollmentException>(
                  (e) => e.type == EnrollmentErrorType.deviceAlreadyEnrolled,
                ),
              ),
            ),
          );

          // Server must not be called — check happens client-side
          expect(httpCalled, false);
        },
      );

      test(
        'throws deviceAlreadyEnrolled for 409 with "already linked" message',
        () async {
          final mockClient = MockClient((request) async {
            return http.Response(
              '{"error": "This device is already linked to a study. '
              'Please contact your research coordinator if you need to re-link."}',
              409,
            );
          });

          service = EnrollmentService(
            secureStorage: mockStorage,
            httpClient: mockClient,
          );

          await expectLater(
            () => service.enroll('CAXXXXXXXX'),
            throwsA(
              allOf(
                isA<EnrollmentException>(),
                predicate<EnrollmentException>(
                  (e) => e.type == EnrollmentErrorType.deviceAlreadyEnrolled,
                ),
              ),
            ),
          );
        },
      );

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

        // Use a code with known prefix (CA) to test server's 400 response
        expect(
          () => service.enroll('CASHORT123'),
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

      test(
        'throws EnrollmentException with unknownSponsor for invalid prefix',
        () async {
          final mockClient = MockClient((request) async {
            return http.Response('{"error": "Invalid code"}', 400);
          });

          service = EnrollmentService(
            secureStorage: mockStorage,
            httpClient: mockClient,
          );

          // Code starting with "XX" is not a known sponsor prefix
          expect(
            () => service.enroll('XXINVALID1'),
            throwsA(
              allOf(
                isA<EnrollmentException>(),
                predicate<EnrollmentException>(
                  (e) => e.type == EnrollmentErrorType.unknownSponsor,
                ),
              ),
            ),
          );
        },
      );

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
      test('removes linking from storage', () async {
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
      test('returns null when not linked and no auth token', () async {
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

      test('returns token when linked', () async {
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
        contains(EnrollmentErrorType.deviceAlreadyEnrolled), // CUR-1055
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

    group('disconnection tracking', () {
      late MockSecureStorage mockStorage;
      late EnrollmentService service;

      setUp(() {
        SharedPreferences.setMockInitialValues({});
        mockStorage = MockSecureStorage();
        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );
      });

      tearDown(() {
        service.dispose();
      });

      test('isDisconnected returns false by default', () async {
        final result = await service.isDisconnected();
        expect(result, false);
      });

      test('setDisconnected updates disconnection state', () async {
        await service.setDisconnected(true);
        final result = await service.isDisconnected();
        expect(result, true);
      });

      test('processDisconnectionStatus returns true when disconnected', () {
        final response = {
          'isDisconnected': true,
          'mobileLinkingStatus': 'disconnected',
        };

        final result = service.processDisconnectionStatus(response);
        expect(result, true);
      });

      test('processDisconnectionStatus returns false when connected', () {
        final response = {
          'isDisconnected': false,
          'mobileLinkingStatus': 'connected',
        };

        final result = service.processDisconnectionStatus(response);
        expect(result, false);
      });

      test('processDisconnectionStatus handles missing fields', () {
        final response = <String, dynamic>{};

        final result = service.processDisconnectionStatus(response);
        expect(result, false);
      });

      test('processDisconnectionStatus updates local state', () async {
        final response = {
          'isDisconnected': true,
          'mobileLinkingStatus': 'disconnected',
        };

        service.processDisconnectionStatus(response);

        // Wait for async update
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final result = await service.isDisconnected();
        expect(result, true);
      });
    });

    // CUR-1164: Re-enrollment when disconnected
    group('re-enrollment when disconnected', () {
      late MockSecureStorage mockStorage;
      late EnrollmentService service;

      final validLinkResponse = jsonEncode({
        'jwt': 'new-token',
        'userId': 'user-456',
        'patientId': 'patient-456',
        'linkingCode': 'CAHELLO WORLD',
        'siteId': 'site-1',
        'siteName': 'Test Site',
        'sitePhoneNumber': '+1-555-0000',
        'studyPatientId': 'SP-001',
      });

      setUp(() {
        SharedPreferences.setMockInitialValues({});
        mockStorage = MockSecureStorage();
      });

      tearDown(() {
        service.dispose();
      });

      test('allows re-enrollment when patient is disconnected', () async {
        // Arrange: existing enrollment + disconnected state
        final existing = UserEnrollment(
          userId: 'user-old',
          jwtToken: 'old-token',
          enrolledAt: DateTime.now(),
          backendUrl: 'https://ca.example.com',
          linkingCode: 'CAOLDCODE',
        );
        mockStorage.data['user_enrollment'] = jsonEncode(existing.toJson());
        SharedPreferences.setMockInitialValues({'patient_disconnected': true});

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient(
            (_) async => http.Response(validLinkResponse, 200),
          ),
        );

        // Act: re-enroll — should NOT throw deviceAlreadyEnrolled
        final result = await service.enroll('CAHELLOWORLD');

        expect(result.userId, 'user-456');
        expect(result.jwtToken, 'new-token');
      });

      test(
        'clears disconnected state after successful re-enrollment',
        () async {
          final existing = UserEnrollment(
            userId: 'user-old',
            jwtToken: 'old-token',
            enrolledAt: DateTime.now(),
            backendUrl: 'https://ca.example.com',
            linkingCode: 'CAOLDCODE',
          );
          mockStorage.data['user_enrollment'] = jsonEncode(existing.toJson());
          SharedPreferences.setMockInitialValues({
            'patient_disconnected': true,
          });

          service = EnrollmentService(
            secureStorage: mockStorage,
            httpClient: MockClient(
              (_) async => http.Response(validLinkResponse, 200),
            ),
          );

          await service.enroll('CAHELLOWORLD');

          final isDisconnected = await service.isDisconnected();
          expect(isDisconnected, false);
        },
      );

      test('still blocks re-enrollment when not disconnected', () async {
        // Arrange: existing enrollment, NOT disconnected
        final existing = UserEnrollment(
          userId: 'user-old',
          jwtToken: 'old-token',
          enrolledAt: DateTime.now(),
        );
        mockStorage.data['user_enrollment'] = jsonEncode(existing.toJson());
        SharedPreferences.setMockInitialValues({'patient_disconnected': false});

        service = EnrollmentService(
          secureStorage: mockStorage,
          httpClient: MockClient((_) async => http.Response('', 200)),
        );

        expect(
          () => service.enroll('CAHELLOWORLD'),
          throwsA(
            predicate<EnrollmentException>(
              (e) => e.type == EnrollmentErrorType.deviceAlreadyEnrolled,
            ),
          ),
        );
      });
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

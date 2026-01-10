// IMPLEMENTS REQUIREMENTS:
//   REQ-d00006: Mobile App Build and Release Process

import 'dart:convert';

import 'package:clinical_diary/services/version_check_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VersionCheckService', () {
    late VersionCheckService service;
    late MockClient mockClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('compareVersions', () {
      setUp(() {
        mockClient = MockClient((_) async => http.Response('{}', 200));
        service = VersionCheckService(
          versionUrl: 'https://example.com/version.json',
          httpClient: mockClient,
        );
      });

      test('returns none when versions are equal', () {
        final result = service.compareVersions(local: '1.0.0', remote: '1.0.0');

        expect(result.updateType, equals(UpdateType.none));
        expect(result.hasUpdate, isFalse);
      });

      test('returns optional when remote version is higher', () {
        final result = service.compareVersions(local: '1.0.0', remote: '1.1.0');

        expect(result.updateType, equals(UpdateType.optional));
        expect(result.hasUpdate, isTrue);
        expect(result.isRequired, isFalse);
      });

      test('returns none when local version is higher', () {
        final result = service.compareVersions(local: '2.0.0', remote: '1.0.0');

        expect(result.updateType, equals(UpdateType.none));
        expect(result.hasUpdate, isFalse);
      });

      test('returns required when local is below minVersion', () {
        final result = service.compareVersions(
          local: '1.0.0',
          remote: '2.0.0',
          minVersion: '1.5.0',
        );

        expect(result.updateType, equals(UpdateType.required));
        expect(result.hasUpdate, isTrue);
        expect(result.isRequired, isTrue);
      });

      test('returns optional when local is at minVersion', () {
        final result = service.compareVersions(
          local: '1.5.0',
          remote: '2.0.0',
          minVersion: '1.5.0',
        );

        expect(result.updateType, equals(UpdateType.optional));
        expect(result.hasUpdate, isTrue);
        expect(result.isRequired, isFalse);
      });

      test(
        'returns optional when local is above minVersion but below remote',
        () {
          final result = service.compareVersions(
            local: '1.7.0',
            remote: '2.0.0',
            minVersion: '1.5.0',
          );

          expect(result.updateType, equals(UpdateType.optional));
          expect(result.hasUpdate, isTrue);
          expect(result.isRequired, isFalse);
        },
      );

      test('handles patch version comparison correctly', () {
        final result = service.compareVersions(
          local: '1.0.9',
          remote: '1.0.10',
        );

        expect(result.updateType, equals(UpdateType.optional));
      });

      test('handles version with build number', () {
        final result = service.compareVersions(
          local: '1.0.0+1',
          remote: '1.0.1+5',
        );

        expect(result.updateType, equals(UpdateType.optional));
      });

      test('includes release notes in result', () {
        final result = service.compareVersions(
          local: '1.0.0',
          remote: '1.1.0',
          releaseNotes: 'Bug fixes and improvements',
        );

        expect(result.releaseNotes, equals('Bug fixes and improvements'));
      });

      test('handles complex version comparison (major.minor.patch)', () {
        // Test various scenarios
        expect(
          service.compareVersions(local: '0.7.68', remote: '0.7.70').updateType,
          equals(UpdateType.optional),
        );

        expect(
          service.compareVersions(local: '0.7.70', remote: '0.7.68').updateType,
          equals(UpdateType.none),
        );

        expect(
          service.compareVersions(local: '1.0.0', remote: '0.9.99').updateType,
          equals(UpdateType.none),
        );

        expect(
          service.compareVersions(local: '0.9.99', remote: '1.0.0').updateType,
          equals(UpdateType.optional),
        );
      });
    });

    group('fetchRemoteVersion', () {
      test('parses version.json correctly', () async {
        mockClient = MockClient((request) async {
          expect(request.url.path, contains('version.json'));
          expect(request.url.queryParameters, contains('t')); // Cache-bust

          return http.Response(
            jsonEncode({
              'version': '2.0.0',
              'minVersion': '1.5.0',
              'releaseNotes': 'New features!',
            }),
            200,
          );
        });

        service = VersionCheckService(
          versionUrl: 'https://example.com/version.json',
          httpClient: mockClient,
        );

        final result = await service.fetchRemoteVersion();

        expect(result, isNotNull);
        expect(result!.version, equals('2.0.0'));
        expect(result.minVersion, equals('1.5.0'));
        expect(result.releaseNotes, equals('New features!'));
      });

      test('returns null on HTTP error', () async {
        mockClient = MockClient((_) async => http.Response('Not found', 404));

        service = VersionCheckService(
          versionUrl: 'https://example.com/version.json',
          httpClient: mockClient,
        );

        final result = await service.fetchRemoteVersion();

        expect(result, isNull);
      });

      test('returns null on network error', () async {
        mockClient = MockClient((_) async {
          throw Exception('Network error');
        });

        service = VersionCheckService(
          versionUrl: 'https://example.com/version.json',
          httpClient: mockClient,
        );

        final result = await service.fetchRemoteVersion();

        expect(result, isNull);
      });

      test('handles missing optional fields', () async {
        mockClient = MockClient((_) async {
          return http.Response(jsonEncode({'version': '1.0.0'}), 200);
        });

        service = VersionCheckService(
          versionUrl: 'https://example.com/version.json',
          httpClient: mockClient,
        );

        final result = await service.fetchRemoteVersion();

        expect(result, isNotNull);
        expect(result!.version, equals('1.0.0'));
        expect(result.minVersion, isNull);
        expect(result.releaseNotes, isNull);
      });
    });

    group('shouldCheckForUpdate', () {
      setUp(() {
        mockClient = MockClient((_) async => http.Response('{}', 200));
        service = VersionCheckService(
          versionUrl: 'https://example.com/version.json',
          httpClient: mockClient,
        );
      });

      test('returns true when no previous check exists', () async {
        final result = await service.shouldCheckForUpdate();
        expect(result, isTrue);
      });

      test('returns false when checked within 24 hours', () async {
        await service.recordCheckTime();

        final result = await service.shouldCheckForUpdate();
        expect(result, isFalse);
      });

      test('returns true when last check was more than 24 hours ago', () async {
        // Set last check to 25 hours ago
        final prefs = await SharedPreferences.getInstance();
        final past = DateTime.now().subtract(const Duration(hours: 25));
        await prefs.setInt(
          'version_check_last_time',
          past.millisecondsSinceEpoch,
        );

        final result = await service.shouldCheckForUpdate();
        expect(result, isTrue);
      });
    });

    group('dismissVersion', () {
      setUp(() {
        mockClient = MockClient((_) async => http.Response('{}', 200));
        service = VersionCheckService(
          versionUrl: 'https://example.com/version.json',
          httpClient: mockClient,
        );
      });

      test('marks version as dismissed', () async {
        await service.dismissVersion('1.2.0');

        final isDismissed = await service.isVersionDismissed('1.2.0');
        expect(isDismissed, isTrue);
      });

      test('different version is not dismissed', () async {
        await service.dismissVersion('1.2.0');

        final isDismissed = await service.isVersionDismissed('1.3.0');
        expect(isDismissed, isFalse);
      });

      test('clearDismissedVersion removes dismissed state', () async {
        await service.dismissVersion('1.2.0');
        await service.clearDismissedVersion();

        final isDismissed = await service.isVersionDismissed('1.2.0');
        expect(isDismissed, isFalse);
      });
    });

    group('VersionInfo', () {
      test('fromJson parses all fields', () {
        final json = {
          'version': '1.0.0',
          'minVersion': '0.9.0',
          'releaseNotes': 'Test notes',
        };

        final info = VersionInfo.fromJson(json);

        expect(info.version, equals('1.0.0'));
        expect(info.minVersion, equals('0.9.0'));
        expect(info.releaseNotes, equals('Test notes'));
      });

      test('fromJson handles missing optional fields', () {
        final json = {'version': '1.0.0'};

        final info = VersionInfo.fromJson(json);

        expect(info.version, equals('1.0.0'));
        expect(info.minVersion, isNull);
        expect(info.releaseNotes, isNull);
      });

      test('fromJson uses empty string for missing version', () {
        final json = <String, dynamic>{};

        final info = VersionInfo.fromJson(json);

        expect(info.version, equals(''));
      });
    });

    group('VersionCheckResult', () {
      test('hasUpdate is true for optional updates', () {
        const result = VersionCheckResult(
          updateType: UpdateType.optional,
          remoteVersion: '1.1.0',
          localVersion: '1.0.0',
        );

        expect(result.hasUpdate, isTrue);
        expect(result.isRequired, isFalse);
      });

      test('hasUpdate is true for required updates', () {
        const result = VersionCheckResult(
          updateType: UpdateType.required,
          remoteVersion: '2.0.0',
          localVersion: '1.0.0',
        );

        expect(result.hasUpdate, isTrue);
        expect(result.isRequired, isTrue);
      });

      test('hasUpdate is false when no update needed', () {
        const result = VersionCheckResult(
          updateType: UpdateType.none,
          remoteVersion: '1.0.0',
          localVersion: '1.0.0',
        );

        expect(result.hasUpdate, isFalse);
        expect(result.isRequired, isFalse);
      });
    });
  });
}

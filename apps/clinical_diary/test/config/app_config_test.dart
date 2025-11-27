// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    group('URL configuration', () {
      test('enrollUrl has correct base path', () {
        expect(AppConfig.enrollUrl, contains('hht-diary-mvp.web.app'));
        expect(AppConfig.enrollUrl, contains('/api/'));
        expect(AppConfig.enrollUrl, endsWith('/enroll'));
      });

      test('healthUrl has correct base path', () {
        expect(AppConfig.healthUrl, contains('hht-diary-mvp.web.app'));
        expect(AppConfig.healthUrl, contains('/api/'));
        expect(AppConfig.healthUrl, endsWith('/health'));
      });

      test('syncUrl has correct base path', () {
        expect(AppConfig.syncUrl, contains('hht-diary-mvp.web.app'));
        expect(AppConfig.syncUrl, contains('/api/'));
        expect(AppConfig.syncUrl, endsWith('/sync'));
      });

      test('getRecordsUrl has correct base path', () {
        expect(AppConfig.getRecordsUrl, contains('hht-diary-mvp.web.app'));
        expect(AppConfig.getRecordsUrl, contains('/api/'));
        expect(AppConfig.getRecordsUrl, endsWith('/getRecords'));
      });

      test('all URLs use HTTPS', () {
        expect(AppConfig.enrollUrl, startsWith('https://'));
        expect(AppConfig.healthUrl, startsWith('https://'));
        expect(AppConfig.syncUrl, startsWith('https://'));
        expect(AppConfig.getRecordsUrl, startsWith('https://'));
      });

      test('all URLs are valid URIs', () {
        expect(() => Uri.parse(AppConfig.enrollUrl), returnsNormally);
        expect(() => Uri.parse(AppConfig.healthUrl), returnsNormally);
        expect(() => Uri.parse(AppConfig.syncUrl), returnsNormally);
        expect(() => Uri.parse(AppConfig.getRecordsUrl), returnsNormally);
      });

      test('URLs share common base', () {
        // Extract base from enrollUrl
        final enrollUri = Uri.parse(AppConfig.enrollUrl);
        final healthUri = Uri.parse(AppConfig.healthUrl);
        final syncUri = Uri.parse(AppConfig.syncUrl);
        final getRecordsUri = Uri.parse(AppConfig.getRecordsUrl);

        expect(enrollUri.host, healthUri.host);
        expect(enrollUri.host, syncUri.host);
        expect(enrollUri.host, getRecordsUri.host);
      });
    });

    group('app metadata', () {
      test('appName is non-empty', () {
        expect(AppConfig.appName, isNotEmpty);
        expect(AppConfig.appName, 'Nosebleed Diary');
      });

      test('isDebug is a boolean', () {
        expect(AppConfig.isDebug, isA<bool>());
      });

      test('isDebug defaults to false', () {
        // Without DEBUG environment variable set, should default to false
        expect(AppConfig.isDebug, false);
      });
    });

    group('URL path segments', () {
      test('enroll URL path is /api/enroll', () {
        final uri = Uri.parse(AppConfig.enrollUrl);
        expect(uri.path, '/api/enroll');
      });

      test('health URL path is /api/health', () {
        final uri = Uri.parse(AppConfig.healthUrl);
        expect(uri.path, '/api/health');
      });

      test('sync URL path is /api/sync', () {
        final uri = Uri.parse(AppConfig.syncUrl);
        expect(uri.path, '/api/sync');
      });

      test('getRecords URL path is /api/getRecords', () {
        final uri = Uri.parse(AppConfig.getRecordsUrl);
        expect(uri.path, '/api/getRecords');
      });
    });
  });
}

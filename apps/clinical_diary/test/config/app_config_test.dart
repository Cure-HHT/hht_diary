// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment', () {
    group('fromString', () {
      test('parses dev environment', () {
        expect(AppEnvironment.fromString('dev'), AppEnvironment.dev);
        expect(AppEnvironment.fromString('DEV'), AppEnvironment.dev);
        expect(AppEnvironment.fromString('Dev'), AppEnvironment.dev);
      });

      test('parses test environment', () {
        expect(AppEnvironment.fromString('test'), AppEnvironment.test);
        expect(AppEnvironment.fromString('TEST'), AppEnvironment.test);
      });

      test('parses uat environment', () {
        expect(AppEnvironment.fromString('uat'), AppEnvironment.uat);
        expect(AppEnvironment.fromString('UAT'), AppEnvironment.uat);
      });

      test('parses prod environment', () {
        expect(AppEnvironment.fromString('prod'), AppEnvironment.prod);
        expect(AppEnvironment.fromString('PROD'), AppEnvironment.prod);
      });

      test('defaults to dev for null', () {
        expect(AppEnvironment.fromString(null), AppEnvironment.dev);
      });

      test('defaults to dev for unknown value', () {
        expect(AppEnvironment.fromString('unknown'), AppEnvironment.dev);
        expect(AppEnvironment.fromString(''), AppEnvironment.dev);
      });
    });

    group('showDevTools', () {
      test('returns true for dev environment', () {
        expect(AppEnvironment.dev.showDevTools, true);
      });

      test('returns true for test environment', () {
        expect(AppEnvironment.test.showDevTools, true);
      });

      test('returns false for uat environment', () {
        expect(AppEnvironment.uat.showDevTools, false);
      });

      test('returns false for prod environment', () {
        expect(AppEnvironment.prod.showDevTools, false);
      });
    });

    group('isProductionLike', () {
      test('returns false for dev environment', () {
        expect(AppEnvironment.dev.isProductionLike, false);
      });

      test('returns false for test environment', () {
        expect(AppEnvironment.test.isProductionLike, false);
      });

      test('returns true for uat environment', () {
        expect(AppEnvironment.uat.isProductionLike, true);
      });

      test('returns true for prod environment', () {
        expect(AppEnvironment.prod.isProductionLike, true);
      });
    });

    group('displayName', () {
      test('returns human-readable names', () {
        expect(AppEnvironment.dev.displayName, 'Development');
        expect(AppEnvironment.test.displayName, 'Test');
        expect(AppEnvironment.uat.displayName, 'UAT');
        expect(AppEnvironment.prod.displayName, 'Production');
      });
    });
  });

  group('AppConfig', () {
    group('environment', () {
      test('environment is a valid AppEnvironment', () {
        expect(AppConfig.environment, isA<AppEnvironment>());
      });

      test('showDevTools matches environment setting', () {
        expect(AppConfig.showDevTools, AppConfig.environment.showDevTools);
      });
    });

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

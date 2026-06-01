import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/env_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    setUp(() {
      // Reset to dev profile for each test
      EnvProfile.current = EnvProfile.forEnv(AppEnv.dev);
    });

    tearDown(() {
      EnvProfile.current = EnvProfile.forEnv(AppEnv.dev);
      AppConfig.testApiBaseOverride = null;
    });

    group('environment', () {
      test('environment returns current AppEnv', () {
        EnvProfile.current = EnvProfile.forEnv(AppEnv.dev);
        expect(AppConfig.environment, AppEnv.dev);

        EnvProfile.current = EnvProfile.forEnv(AppEnv.prod);
        expect(AppConfig.environment, AppEnv.prod);
      });

      test('showDevTools delegates to EnvProfile.current', () {
        EnvProfile.current = EnvProfile.forEnv(AppEnv.dev);
        expect(AppConfig.showDevTools, true);

        EnvProfile.current = EnvProfile.forEnv(AppEnv.prod);
        expect(AppConfig.showDevTools, false);
      });

      test('showBanner delegates to EnvProfile.current', () {
        EnvProfile.current = EnvProfile.forEnv(AppEnv.dev);
        expect(AppConfig.showBanner, true);

        EnvProfile.current = EnvProfile.forEnv(AppEnv.prod);
        expect(AppConfig.showBanner, false);
      });

      test('showResetData mirrors EnvProfile for each AppEnv', () {
        for (final env in AppEnv.values) {
          EnvProfile.current = EnvProfile.forEnv(env);
          expect(
            AppConfig.showResetData,
            EnvProfile.current.showResetData,
            reason:
                'AppConfig.showResetData must equal EnvProfile.showResetData for $env',
          );
        }
      });

      test('showResetData is true for uat', () {
        EnvProfile.current = EnvProfile.forEnv(AppEnv.uat);
        expect(AppConfig.showResetData, true);
      });

      test('showResetData is false for prod', () {
        EnvProfile.current = EnvProfile.forEnv(AppEnv.prod);
        expect(AppConfig.showResetData, false);
      });
    });

    group('EnvProfile delegation', () {
      test('apiBase follows the active EnvProfile', () {
        EnvProfile.current = EnvProfile.forEnv(AppEnv.qa);
        expect(
          AppConfig.apiBase,
          'https://diary-service-421945483876.europe-west9.run.app',
        );
      });

      test(
        'showBanner/showDevTools/showResetData follow the active EnvProfile',
        () {
          EnvProfile.current = EnvProfile.forEnv(AppEnv.prod);
          expect(AppConfig.showBanner, isFalse);
          expect(AppConfig.showDevTools, isFalse);
          expect(AppConfig.showResetData, isFalse);
        },
      );

      test('testApiBaseOverride still wins over the profile', () {
        EnvProfile.current = EnvProfile.forEnv(AppEnv.prod);
        AppConfig.testApiBaseOverride = 'http://test.local';
        expect(AppConfig.apiBase, 'http://test.local');
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

    group('API configuration', () {
      test('apiBase returns value from EnvProfile when no override', () {
        AppConfig.testApiBaseOverride = null;
        EnvProfile.current = EnvProfile.forEnv(AppEnv.dev);
        expect(
          AppConfig.apiBase,
          'https://diary-service-1012274191696.europe-west9.run.app',
        );

        EnvProfile.current = EnvProfile.forEnv(AppEnv.prod);
        expect(AppConfig.apiBase, 'https://diary-server.europe-west9.run.app');
      });

      test('apiBase returns test override when set', () {
        AppConfig.testApiBaseOverride = 'https://test-api.example.com';
        expect(AppConfig.apiBase, 'https://test-api.example.com');
      });

      group('endpoint URLs', () {
        setUp(() {
          AppConfig.testApiBaseOverride = 'https://test-api.example.com';
        });

        test('enrollUrl uses /api/v1/user/enroll path', () {
          expect(
            AppConfig.enrollUrl,
            'https://test-api.example.com/api/v1/user/enroll',
          );
        });

        test('healthUrl appends /health to apiBase', () {
          expect(AppConfig.healthUrl, 'https://test-api.example.com/health');
        });

        test('syncUrl uses /api/v1/user/sync path', () {
          expect(
            AppConfig.syncUrl,
            'https://test-api.example.com/api/v1/user/sync',
          );
        });

        test('getRecordsUrl uses /api/v1/user/records path', () {
          expect(
            AppConfig.getRecordsUrl,
            'https://test-api.example.com/api/v1/user/records',
          );
        });

        test('registerUrl uses /api/v1/auth/register path', () {
          expect(
            AppConfig.registerUrl,
            'https://test-api.example.com/api/v1/auth/register',
          );
        });

        test('loginUrl uses /api/v1/auth/login path', () {
          expect(
            AppConfig.loginUrl,
            'https://test-api.example.com/api/v1/auth/login',
          );
        });

        test('changePasswordUrl uses /api/v1/auth/change-password path', () {
          expect(
            AppConfig.changePasswordUrl,
            'https://test-api.example.com/api/v1/auth/change-password',
          );
        });

        test('sponsorConfigUrl uses /api/v1/sponsor/config path', () {
          final url = AppConfig.sponsorConfigUrl('curehht');
          expect(
            url,
            'https://test-api.example.com/api/v1/sponsor/config?sponsorId=curehht',
          );
        });
      });

      test('qaApiKey returns empty string when not configured', () {
        // Since CUREHHT_QA_API_KEY is not set in test environment
        expect(AppConfig.qaApiKey, isEmpty);
      });
    });
  });

  group('MissingConfigException', () {
    test('creates exception with configName and message', () {
      final exception = MissingConfigException('testConfig', 'Test message');
      expect(exception.configName, 'testConfig');
      expect(exception.message, 'Test message');
    });

    test('toString returns formatted string', () {
      final exception = MissingConfigException('myConfig', 'Not set');
      expect(
        exception.toString(),
        'MissingConfigException: myConfig - Not set',
      );
    });
  });
}

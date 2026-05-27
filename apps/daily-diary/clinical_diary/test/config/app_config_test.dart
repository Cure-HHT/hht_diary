// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/env_profile.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flavor enum', () {
    test('has all expected values', () {
      expect(
        Flavor.values,
        containsAll([
          Flavor.local,
          Flavor.dev,
          Flavor.qa,
          Flavor.uat,
          Flavor.prod,
        ]),
      );
      expect(Flavor.values.length, 5);
    });

    test('name property returns correct strings', () {
      expect(Flavor.dev.name, 'dev');
      expect(Flavor.qa.name, 'qa');
      expect(Flavor.uat.name, 'uat');
      expect(Flavor.prod.name, 'prod');
    });
  });

  group('F class', () {
    setUp(() {
      // Reset to dev for each test
      F.appFlavor = Flavor.dev;
    });

    group('appFlavor', () {
      test('can set and get flavor', () {
        F.appFlavor = Flavor.prod;
        expect(F.appFlavor, Flavor.prod);

        F.appFlavor = Flavor.qa;
        expect(F.appFlavor, Flavor.qa);
      });
    });

    group('name', () {
      test('returns flavor name', () {
        F.appFlavor = Flavor.dev;
        expect(F.name, 'dev');

        F.appFlavor = Flavor.prod;
        expect(F.name, 'prod');
      });
    });

    group('title', () {
      test('returns CureHHT Tracker DEV title for dev', () {
        F.appFlavor = Flavor.dev;
        expect(F.title, 'CureHHT Tracker DEV');
      });

      test('returns CureHHT Tracker QA for qa', () {
        F.appFlavor = Flavor.qa;
        expect(F.title, 'CureHHT Tracker QA');
      });

      test('returns CureHHT Tracker for uat', () {
        F.appFlavor = Flavor.uat;
        expect(F.title, 'CureHHT Tracker');
      });

      test('returns CureHHT Tracker title for prod', () {
        F.appFlavor = Flavor.prod;
        expect(F.title, 'CureHHT Tracker');
      });
    });

    group('showDevTools', () {
      test('returns true for dev environment', () {
        F.appFlavor = Flavor.dev;
        expect(F.showDevTools, true);
      });

      test('returns true for qa environment', () {
        F.appFlavor = Flavor.qa;
        expect(F.showDevTools, true);
      });

      test('returns false for uat environment', () {
        F.appFlavor = Flavor.uat;
        expect(F.showDevTools, false);
      });

      test('returns false for prod environment', () {
        F.appFlavor = Flavor.prod;
        expect(F.showDevTools, false);
      });
    });

    group('showBanner', () {
      test('returns true for dev environment', () {
        F.appFlavor = Flavor.dev;
        expect(F.showBanner, true);
      });

      test('returns true for qa environment', () {
        F.appFlavor = Flavor.qa;
        expect(F.showBanner, true);
      });

      test('returns false for uat environment', () {
        F.appFlavor = Flavor.uat;
        expect(F.showBanner, false);
      });

      test('returns false for prod environment', () {
        F.appFlavor = Flavor.prod;
        expect(F.showBanner, false);
      });
    });
  });

  group('FlavorConfig', () {
    test('dev has correct values', () {
      expect(FlavorConfig.dev.name, 'dev');
      expect(
        FlavorConfig.dev.apiBase,
        'https://diary-service-1012274191696.europe-west9.run.app',
      );
      expect(FlavorConfig.dev.environment, 'dev');
      expect(FlavorConfig.dev.showDevTools, true);
      expect(FlavorConfig.dev.showBanner, true);
      expect(FlavorConfig.dev.sponsorBackends['CA'], isNotNull);
    });

    test('qa has correct values', () {
      expect(FlavorConfig.qa.name, 'qa');
      expect(
        FlavorConfig.qa.apiBase,
        'https://diary-service-421945483876.europe-west9.run.app',
      );
      expect(FlavorConfig.qa.environment, 'qa');
      expect(FlavorConfig.qa.showDevTools, true);
      expect(FlavorConfig.qa.showBanner, true);
      expect(FlavorConfig.qa.sponsorBackends['CA'], isNotNull);
    });

    test('uat has correct values', () {
      expect(FlavorConfig.uat.name, 'uat');
      expect(
        FlavorConfig.uat.apiBase,
        'https://diary-service-768644809588.europe-west9.run.app',
      );
      expect(FlavorConfig.uat.environment, 'uat');
      expect(FlavorConfig.uat.showDevTools, false);
      expect(FlavorConfig.uat.showBanner, false);
      expect(FlavorConfig.uat.sponsorBackends['CA'], isNotNull);
    });

    test('prod has correct values', () {
      expect(FlavorConfig.prod.name, 'prod');
      expect(
        FlavorConfig.prod.apiBase,
        'https://diary-server.europe-west9.run.app',
      );
      expect(FlavorConfig.prod.environment, 'prod');
      expect(FlavorConfig.prod.showDevTools, false);
      expect(FlavorConfig.prod.showBanner, false);
      expect(FlavorConfig.prod.sponsorBackends['CA'], isNotNull);
    });

    group('byName', () {
      test('returns correct flavor for valid names', () {
        expect(FlavorConfig.byName('dev'), FlavorConfig.dev);
        expect(FlavorConfig.byName('qa'), FlavorConfig.qa);
        expect(FlavorConfig.byName('uat'), FlavorConfig.uat);
        expect(FlavorConfig.byName('prod'), FlavorConfig.prod);
      });

      test('is case insensitive', () {
        expect(FlavorConfig.byName('DEV'), FlavorConfig.dev);
        expect(FlavorConfig.byName('Dev'), FlavorConfig.dev);
        expect(FlavorConfig.byName('PROD'), FlavorConfig.prod);
      });

      test('defaults to dev for unknown value', () {
        expect(FlavorConfig.byName('unknown'), FlavorConfig.dev);
        expect(FlavorConfig.byName(''), FlavorConfig.dev);
      });
    });

    group('all', () {
      test('contains all flavors', () {
        expect(FlavorConfig.all.length, 5);
        expect(FlavorConfig.all, contains(FlavorConfig.local));
        expect(FlavorConfig.all, contains(FlavorConfig.dev));
        expect(FlavorConfig.all, contains(FlavorConfig.qa));
        expect(FlavorConfig.all, contains(FlavorConfig.uat));
        expect(FlavorConfig.all, contains(FlavorConfig.prod));
      });
    });
  });

  group('FlavorValues', () {
    test('dartDefine generates correct APP_FLAVOR argument', () {
      expect(FlavorConfig.dev.dartDefine, '--dart-define=APP_FLAVOR=dev');
      expect(FlavorConfig.qa.dartDefine, '--dart-define=APP_FLAVOR=qa');
      expect(FlavorConfig.uat.dartDefine, '--dart-define=APP_FLAVOR=uat');
      expect(FlavorConfig.prod.dartDefine, '--dart-define=APP_FLAVOR=prod');
    });
  });

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
        expect(AppConfig.apiBase, FlavorConfig.dev.apiBase);

        EnvProfile.current = EnvProfile.forEnv(AppEnv.prod);
        expect(AppConfig.apiBase, FlavorConfig.prod.apiBase);
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

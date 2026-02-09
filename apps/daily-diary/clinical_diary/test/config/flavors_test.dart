// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/flavors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flavor enum', () {
    test('has all expected values', () {
      expect(Flavor.values, hasLength(4));
      expect(Flavor.values, contains(Flavor.dev));
      expect(Flavor.values, contains(Flavor.qa));
      expect(Flavor.values, contains(Flavor.uat));
      expect(Flavor.values, contains(Flavor.prod));
    });

    test('dev has correct name', () {
      expect(Flavor.dev.name, 'dev');
    });

    test('qa has correct name', () {
      expect(Flavor.qa.name, 'qa');
    });

    test('uat has correct name', () {
      expect(Flavor.uat.name, 'uat');
    });

    test('prod has correct name', () {
      expect(Flavor.prod.name, 'prod');
    });
  });

  group('F (Flavor accessor)', () {
    // Save and restore the flavor between tests
    Flavor? savedFlavor;

    setUp(() {
      try {
        savedFlavor = F.appFlavor;
      } catch (_) {
        savedFlavor = null;
      }
    });

    tearDown(() {
      if (savedFlavor != null) {
        F.appFlavor = savedFlavor!;
      }
    });

    group('appFlavor', () {
      test('can be set and retrieved', () {
        F.appFlavor = Flavor.dev;
        expect(F.appFlavor, Flavor.dev);

        F.appFlavor = Flavor.prod;
        expect(F.appFlavor, Flavor.prod);
      });
    });

    group('name', () {
      test('returns dev for dev flavor', () {
        F.appFlavor = Flavor.dev;
        expect(F.name, 'dev');
      });

      test('returns qa for qa flavor', () {
        F.appFlavor = Flavor.qa;
        expect(F.name, 'qa');
      });

      test('returns uat for uat flavor', () {
        F.appFlavor = Flavor.uat;
        expect(F.name, 'uat');
      });

      test('returns prod for prod flavor', () {
        F.appFlavor = Flavor.prod;
        expect(F.name, 'prod');
      });
    });

    group('title', () {
      test('returns "CureHHT Tracker DEV" for dev flavor', () {
        F.appFlavor = Flavor.dev;
        expect(F.title, 'CureHHT Tracker DEV');
      });

      test('returns "CureHHT Tracker QA" for qa flavor', () {
        F.appFlavor = Flavor.qa;
        expect(F.title, 'CureHHT Tracker QA');
      });

      test('returns "CureHHT Tracker" for uat flavor', () {
        F.appFlavor = Flavor.uat;
        expect(F.title, 'CureHHT Tracker');
      });

      test('returns "CureHHT Tracker" title for prod flavor', () {
        F.appFlavor = Flavor.prod;
        expect(F.title, 'CureHHT Tracker');
      });
    });

    group('showDevTools', () {
      test('returns true for dev flavor', () {
        F.appFlavor = Flavor.dev;
        expect(F.showDevTools, true);
      });

      test('returns true for qa flavor', () {
        F.appFlavor = Flavor.qa;
        expect(F.showDevTools, true);
      });

      test('returns false for uat flavor', () {
        F.appFlavor = Flavor.uat;
        expect(F.showDevTools, false);
      });

      test('returns false for prod flavor', () {
        F.appFlavor = Flavor.prod;
        expect(F.showDevTools, false);
      });
    });

    group('showBanner', () {
      test('returns true for dev flavor', () {
        F.appFlavor = Flavor.dev;
        expect(F.showBanner, true);
      });

      test('returns true for qa flavor', () {
        F.appFlavor = Flavor.qa;
        expect(F.showBanner, true);
      });

      test('returns false for uat flavor', () {
        F.appFlavor = Flavor.uat;
        expect(F.showBanner, false);
      });

      test('returns false for prod flavor', () {
        F.appFlavor = Flavor.prod;
        expect(F.showBanner, false);
      });
    });
  });

  group('FlavorConfig', () {
    group('static constants', () {
      test('dev has correct values', () {
        expect(FlavorConfig.dev.name, 'dev');
        expect(
          FlavorConfig.dev.apiBase,
          'https://diary-server-1012274191696.europe-west9.run.app',
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
          'https://diary-server-qa.europe-west9.run.app',
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
          'https://diary-server-uat.europe-west9.run.app',
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
    });

    group('byName', () {
      test('returns dev for "dev"', () {
        expect(FlavorConfig.byName('dev'), FlavorConfig.dev);
      });

      test('returns qa for "qa"', () {
        expect(FlavorConfig.byName('qa'), FlavorConfig.qa);
      });

      test('returns uat for "uat"', () {
        expect(FlavorConfig.byName('uat'), FlavorConfig.uat);
      });

      test('returns prod for "prod"', () {
        expect(FlavorConfig.byName('prod'), FlavorConfig.prod);
      });

      test('is case insensitive', () {
        expect(FlavorConfig.byName('DEV'), FlavorConfig.dev);
        expect(FlavorConfig.byName('QA'), FlavorConfig.qa);
        expect(FlavorConfig.byName('UAT'), FlavorConfig.uat);
        expect(FlavorConfig.byName('PROD'), FlavorConfig.prod);
      });

      test('returns dev for unknown name', () {
        expect(FlavorConfig.byName('unknown'), FlavorConfig.dev);
        expect(FlavorConfig.byName(''), FlavorConfig.dev);
        expect(FlavorConfig.byName('staging'), FlavorConfig.dev);
      });
    });

    group('all', () {
      test('contains all flavors', () {
        expect(FlavorConfig.all, hasLength(4));
        expect(FlavorConfig.all, contains(FlavorConfig.dev));
        expect(FlavorConfig.all, contains(FlavorConfig.qa));
        expect(FlavorConfig.all, contains(FlavorConfig.uat));
        expect(FlavorConfig.all, contains(FlavorConfig.prod));
      });
    });
  });

  group('FlavorValues', () {
    test('constructor sets all properties', () {
      const values = FlavorValues(
        name: 'test',
        apiBase: 'https://test.api.com',
        environment: 'testing',
        showDevTools: true,
        showBanner: false,
        sponsorBackends: {'CA': 'https://test-sponsor.example.com'},
      );

      expect(values.name, 'test');
      expect(values.apiBase, 'https://test.api.com');
      expect(values.environment, 'testing');
      expect(values.showDevTools, true);
      expect(values.showBanner, false);
      expect(values.sponsorBackends['CA'], 'https://test-sponsor.example.com');
    });

    group('dartDefine', () {
      test('returns correct format for dev', () {
        expect(FlavorConfig.dev.dartDefine, '--dart-define=APP_FLAVOR=dev');
      });

      test('returns correct format for qa', () {
        expect(FlavorConfig.qa.dartDefine, '--dart-define=APP_FLAVOR=qa');
      });

      test('returns correct format for uat', () {
        expect(FlavorConfig.uat.dartDefine, '--dart-define=APP_FLAVOR=uat');
      });

      test('returns correct format for prod', () {
        expect(FlavorConfig.prod.dartDefine, '--dart-define=APP_FLAVOR=prod');
      });
    });
  });
}

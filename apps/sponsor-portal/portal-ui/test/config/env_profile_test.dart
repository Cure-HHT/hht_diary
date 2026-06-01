// Verifies: DIARY-DEV-runtime-environment-resolution/A+B+C+D
import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/config/env_profile.dart';

void main() {
  group('EnvProfile.fromServerName', () {
    // Verifies: DIARY-DEV-runtime-environment-resolution/C
    test('resolves each known environment name', () {
      expect(EnvProfile.fromServerName('local').env, AppEnv.local);
      expect(EnvProfile.fromServerName('dev').env, AppEnv.dev);
      expect(EnvProfile.fromServerName('qa').env, AppEnv.qa);
      expect(EnvProfile.fromServerName('uat').env, AppEnv.uat);
      expect(EnvProfile.fromServerName('prod').env, AppEnv.prod);
    });

    // Verifies: DIARY-DEV-runtime-environment-resolution/C
    test('is case-insensitive and trims whitespace', () {
      expect(EnvProfile.fromServerName('  PROD ').env, AppEnv.prod);
      expect(EnvProfile.fromServerName('Qa').env, AppEnv.qa);
    });

    // Verifies: DIARY-DEV-runtime-environment-resolution/B
    test('defaults to dev for an absent environment value', () {
      expect(EnvProfile.fromServerName(null).env, AppEnv.dev);
      expect(EnvProfile.fromServerName('').env, AppEnv.dev);
    });

    // Verifies: DIARY-DEV-runtime-environment-resolution/B
    test('defaults to dev for an unrecognised environment value', () {
      expect(EnvProfile.fromServerName('staging').env, AppEnv.dev);
    });
  });

  group('EnvProfile presentation', () {
    // Verifies: DIARY-DEV-runtime-environment-resolution/C
    test('non-prod environments show the banner and dev tools', () {
      for (final env in [AppEnv.local, AppEnv.dev, AppEnv.qa]) {
        final p = EnvProfile.forEnv(env);
        expect(p.showBanner, isTrue, reason: '$env should show banner');
        expect(p.showDevTools, isTrue, reason: '$env should show dev tools');
      }
    });

    // Verifies: DIARY-DEV-runtime-environment-resolution/D
    test('prod hides the banner and dev tools', () {
      final prod = EnvProfile.forEnv(AppEnv.prod);
      expect(prod.showBanner, isFalse);
      expect(prod.showDevTools, isFalse);
    });

    // Verifies: DIARY-DEV-runtime-environment-resolution/D
    test('uat hides the banner and dev tools', () {
      final uat = EnvProfile.forEnv(AppEnv.uat);
      expect(uat.showBanner, isFalse);
      expect(uat.showDevTools, isFalse);
    });

    // Verifies: DIARY-DEV-runtime-environment-resolution/C
    test('title and name reflect the environment', () {
      expect(EnvProfile.forEnv(AppEnv.dev).title, 'Portal DEV');
      expect(EnvProfile.forEnv(AppEnv.prod).title, 'Clinical Trial Portal');
      expect(EnvProfile.forEnv(AppEnv.qa).name, 'qa');
    });
  });

  group('EnvProfile.current', () {
    test('defaults to dev before bootstrap resolves it', () {
      expect(EnvProfile.current.env, AppEnv.dev);
    });
  });
}

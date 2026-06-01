// Verifies: DIARY-DEV-runtime-environment-resolution/A+C
import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/config/app_config.dart';
import 'package:sponsor_portal_ui/config/env_profile.dart';
import 'package:sponsor_portal_ui/services/identity_config_service.dart';

void main() {
  group('AppConfig.initializeFromServer', () {
    // Verifies: DIARY-DEV-runtime-environment-resolution/A+C
    test('resolves EnvProfile from the server-reported environment', () {
      const config = IdentityPlatformConfig(
        apiKey: 'k',
        appId: '1:1:web:1',
        projectId: 'p',
        authDomain: 'p.firebaseapp.com',
        environment: 'qa',
      );

      AppConfig.initializeFromServer(config, apiBaseUrl: 'https://qa.example');

      expect(EnvProfile.current.env, AppEnv.qa);
      expect(AppConfig.values.apiBaseUrl, 'https://qa.example');
      expect(AppConfig.values.firebaseApiKey, 'k');
    });

    // Verifies: DIARY-DEV-runtime-environment-resolution/B
    test('defaults to dev when the server reports no environment', () {
      const config = IdentityPlatformConfig(
        apiKey: 'k',
        appId: '1:1:web:1',
        projectId: 'p',
        authDomain: 'p.firebaseapp.com',
      );

      AppConfig.initializeFromServer(config, apiBaseUrl: 'https://x.example');

      expect(EnvProfile.current.env, AppEnv.dev);
    });
  });

  group('AppConfig.initializeLocal', () {
    test('resolves to the local environment with emulator placeholders', () {
      AppConfig.initializeLocal();

      expect(EnvProfile.current.env, AppEnv.local);
      expect(AppConfig.values.firebaseProjectId, 'demo-local-stack');
      expect(AppConfig.values.firebaseAuthDomain, 'localhost');
    });
  });

  group('AppConfig.validateConfig', () {
    test('passes for the local environment without Firebase config', () {
      AppConfig.initializeLocal();
      expect(AppConfig.validateConfig, returnsNormally);
    });

    test('throws for a deployed environment with missing Firebase config', () {
      const config = IdentityPlatformConfig(
        apiKey: '',
        appId: '',
        projectId: 'p',
        authDomain: 'p.firebaseapp.com',
        environment: 'prod',
      );
      AppConfig.initializeFromServer(config, apiBaseUrl: 'https://p.example');

      expect(AppConfig.validateConfig, throwsStateError);
    });
  });
}

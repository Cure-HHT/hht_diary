import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/sponsor_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SponsorRegistry.getBackendUrlForCode', () {
    tearDown(() => AppConfig.testApiBaseOverride = null);

    test(
      'valid sponsor prefix returns the active backend (AppConfig.apiBase)',
      () {
        AppConfig.testApiBaseOverride = 'https://backend.example.test';
        // 'CAXXXXXXXX': prefix 'CA' maps to the registered Callisto sponsor.
        // extractPrefix strips dashes, uppercases, and takes the first 2 chars.
        expect(
          SponsorRegistry.getBackendUrlForCode('CAXXXXXXXX'),
          'https://backend.example.test',
        );
      },
    );

    test('unknown sponsor prefix throws SponsorRegistryException', () {
      // 'ZZXXXXXXXX': prefix 'ZZ' is well-formed (>=2 chars) so extractPrefix
      // succeeds, but getByPrefix returns null for 'ZZ' (not in _sponsors),
      // which triggers the SponsorRegistryException unknown-sponsor path.
      expect(
        () => SponsorRegistry.getBackendUrlForCode('ZZXXXXXXXX'),
        throwsA(isA<SponsorRegistryException>()),
      );
    });
  });
}

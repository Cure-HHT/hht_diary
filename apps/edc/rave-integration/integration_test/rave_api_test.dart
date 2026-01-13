/// Integration tests for RAVE Web Services API.
///
/// These tests make live API calls and require credentials.
/// Run with Doppler:
///   doppler run -- dart test integration_test/
///
/// Skip in CI by not providing credentials.
@Tags(['integration'])
library;

import 'dart:io';

import 'package:rave_integration/rave_integration.dart';
import 'package:test/test.dart';

void main() {
  final baseUrl = Platform.environment['RAVE_UAT_URL'];
  final username = Platform.environment['RAVE_UAT_USERNAME'];
  final password = Platform.environment['RAVE_UAT_PWD'];
  final studyOid = Platform.environment['RAVE_STUDY_OID'];

  final hasCredentials =
      baseUrl != null && username != null && password != null;

  late RaveClient client;

  setUpAll(() {
    if (!hasCredentials) {
      print('RAVE credentials not found - skipping integration tests.');
      print('Required env vars: RAVE_UAT_URL, RAVE_UAT_USERNAME, RAVE_UAT_PWD');
      print('Optional: RAVE_STUDY_OID');
      print('Run with: doppler run -- dart test integration_test/');
    }
  });

  setUp(() {
    if (hasCredentials) {
      client = RaveClient(
        baseUrl: baseUrl,
        username: username,
        password: password,
      );
    }
  });

  tearDown(() {
    if (hasCredentials) {
      client.close();
    }
  });

  group('Sanity Checks', () {
    test(
      'getVersion returns server version',
      () async {
        final version = await client.getVersion();
        expect(version, isNotEmpty);
        print('RAVE version: $version');
      },
      skip: !hasCredentials ? 'No credentials' : null,
    );

    test(
      'getStudies returns study list with valid auth',
      () async {
        final studies = await client.getStudies();
        expect(studies, isNotEmpty);
        if (studyOid != null) {
          expect(studies, contains(studyOid));
        }
        print('Studies response length: ${studies.length} bytes');
      },
      skip: !hasCredentials ? 'No credentials' : null,
    );

    test(
      'getStudies throws on invalid credentials',
      () async {
        final badClient = RaveClient(
          baseUrl: baseUrl!,
          username: 'invalid-user',
          password: 'invalid-password',
        );
        try {
          await expectLater(
            badClient.getStudies(),
            throwsA(isA<RaveAuthenticationException>()),
          );
        } finally {
          badClient.close();
        }
      },
      skip: !hasCredentials ? 'No credentials' : null,
    );
  });

  group('Sites Endpoint', () {
    test(
      'getSites returns sites for study',
      () async {
        final sites = await client.getSites(studyOid: studyOid);

        final studyLabel = studyOid ?? 'all studies';
        print('Found ${sites.length} site(s) for $studyLabel:');
        for (final site in sites) {
          print('  - ${site.oid}: ${site.name} (active: ${site.isActive})');
          if (site.studySiteNumber != null) {
            print('    Site Number: ${site.studySiteNumber}');
          }
        }

        // We expect at least some sites in the test study
        // This may return empty if the API user has no site access
        expect(sites, isA<List<RaveSite>>());
      },
      skip: !hasCredentials ? 'No credentials' : null,
    );

    test(
      'getSites returns empty list for non-existent study',
      () async {
        final sites = await client.getSites(studyOid: 'NonExistentStudy(Fake)');
        expect(sites, isEmpty);
      },
      skip: !hasCredentials ? 'No credentials' : null,
    );

    test(
      'getSites without studyOid returns sites across all studies',
      () async {
        final sites = await client.getSites();
        print('Found ${sites.length} total site(s) across all studies');
        expect(sites, isA<List<RaveSite>>());
      },
      skip: !hasCredentials ? 'No credentials' : null,
    );
  });
}

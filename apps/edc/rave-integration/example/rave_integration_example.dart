import 'dart:io';

import 'package:rave_integration/rave_integration.dart';

/// Example usage of the RAVE integration client.
///
/// Required environment variables (via Doppler):
///   - RAVE_UAT_URL: RAVE instance URL
///   - RAVE_UAT_USERNAME: API username
///   - RAVE_UAT_PWD: API password
///
/// Optional:
///   - RAVE_STUDY_OID: Study OID to fetch sites for
///
/// Run with Doppler:
/// ```bash
/// doppler run -- dart run example/rave_integration_example.dart
/// ```
Future<void> main() async {
  final baseUrl = Platform.environment['RAVE_UAT_URL'];
  final username = Platform.environment['RAVE_UAT_USERNAME'];
  final password = Platform.environment['RAVE_UAT_PWD'];
  final studyOid = Platform.environment['RAVE_STUDY_OID'];

  if (baseUrl == null || username == null || password == null) {
    print(
      'Error: RAVE_UAT_URL, RAVE_UAT_USERNAME, and RAVE_UAT_PWD must be set.',
    );
    print(
      'Run with: doppler run -- dart run example/rave_integration_example.dart',
    );
    exit(1);
  }

  final client = RaveClient(
    baseUrl: baseUrl,
    username: username,
    password: password,
  );

  try {
    // Sanity check 1: Version (no auth required)
    print('Checking RAVE connectivity...');
    final version = await client.getVersion();
    print('  RAVE version: $version');

    // Sanity check 2: Studies (requires auth)
    print('\nVerifying authentication...');
    final studies = await client.getStudies();
    print('  Authentication successful!');
    print('  Studies response length: ${studies.length} bytes');

    // Get sites for the study
    final studyLabel = studyOid ?? 'all studies';
    print('\nFetching sites for $studyLabel...');
    final sites = await client.getSites(studyOid: studyOid);

    if (sites.isEmpty) {
      print('  No sites found (or no permission).');
    } else {
      print('  Found ${sites.length} site(s):');
      for (final site in sites) {
        print('    - ${site.oid}: ${site.name}');
        print('      Active: ${site.isActive}');
        print('      Site Number: ${site.studySiteNumber ?? "N/A"}');
      }
    }
  } on RaveAuthenticationException {
    print('Error: Authentication failed. Check credentials.');
    exit(1);
  } on RaveNetworkException catch (e) {
    print('Error: Network issue - $e');
    exit(1);
  } on RaveException catch (e) {
    print('Error: $e');
    exit(1);
  } finally {
    client.close();
  }
}

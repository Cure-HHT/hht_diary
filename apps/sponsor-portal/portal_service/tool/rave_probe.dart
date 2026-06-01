// Live-verify-once RAVE probe.
//
// Reuses the existing `rave_integration` RaveClient to fetch Sites + Subjects
// from RAVE/Medidata EDC and print their real field shapes, so we can confirm
// creds/endpoints still work before finalizing event payloads.
//
// This tool writes NO new HTTP/auth code — all transport and parsing go
// through RaveClient / its OdmParser. It never echoes secrets
// (URL/username/password).
//
// Run:
//   dart run tool/rave_probe.dart
// (creds RAVE_UAT_URL / RAVE_UAT_USERNAME / RAVE_UAT_PWD read from the env;
// the session is expected to be launched under `doppler run`).

import 'dart:io';

import 'package:rave_integration/rave_integration.dart';

Future<void> main() async {
  final env = Platform.environment;
  final url = env['RAVE_UAT_URL'];
  final username = env['RAVE_UAT_USERNAME'];
  final password = env['RAVE_UAT_PWD'];

  if (url == null ||
      url.isEmpty ||
      username == null ||
      username.isEmpty ||
      password == null ||
      password.isEmpty) {
    stderr.writeln(
      'ERROR: missing RAVE creds. Need RAVE_UAT_URL, RAVE_UAT_USERNAME, '
      'RAVE_UAT_PWD in the environment (e.g. run under `doppler run`). '
      'Not printing any values.',
    );
    exitCode = 2;
    return;
  }

  final client = RaveClient(
    baseUrl: url,
    username: username,
    password: password,
  );

  try {
    // 1. Connectivity (no auth).
    final version = await client.getVersion();
    stdout.writeln('getVersion(): $version');

    // 2. Auth check. getStudies() returns raw ODM XML and the rave_integration
    // OdmParser has no study-OID extractor, so we just confirm the call
    // succeeds (auth OK) and report the body length — we do NOT print the body
    // (it may contain study identifiers we don't need to echo here). The
    // study OID we actually use is recovered from getSites() below, which is
    // the only typed path the library exposes.
    final studiesXml = await client.getStudies();
    stdout.writeln(
      'getStudies(): OK (auth succeeded), '
      'response length ${studiesXml.length} chars',
    );

    // 3. Sites across all accessible studies (studyOid: null). Each RaveSite
    // carries its own studyOid, which we use to drive getSubjects().
    final sites = await client.getSites();
    stdout.writeln('');
    stdout.writeln('getSites(studyOid: <all>): ${sites.length} site(s)');
    for (final s in sites.take(5)) {
      stdout.writeln('  RaveSite{');
      stdout.writeln('    oid: ${s.oid}');
      stdout.writeln('    name: ${s.name}');
      stdout.writeln('    isActive: ${s.isActive}');
      stdout.writeln('    studySiteNumber: ${s.studySiteNumber}');
      stdout.writeln('    studyOid: ${s.studyOid}');
      stdout.writeln('    metaDataVersionOid: ${s.metaDataVersionOid}');
      stdout.writeln('    effectiveDate: ${s.effectiveDate}');
      stdout.writeln('  }');
    }

    final studyOid = sites
        .map((s) => s.studyOid)
        .firstWhere((o) => o != null && o.isNotEmpty, orElse: () => null);

    // 4. Subjects (requires a study OID).
    stdout.writeln('');
    if (studyOid == null) {
      stdout.writeln(
        'getSubjects: SKIPPED — no studyOid present on any returned site.',
      );
    } else {
      final subjects = await client.getSubjects(studyOid: studyOid);
      stdout.writeln(
        'getSubjects(studyOid: $studyOid): '
        '${subjects.length} subject(s)',
      );
      for (final sub in subjects.take(5)) {
        stdout.writeln('  RaveSubject{');
        stdout.writeln('    subjectKey: ${sub.subjectKey}');
        stdout.writeln('    siteOid: ${sub.siteOid}');
        stdout.writeln('    siteNumber: ${sub.siteNumber}');
        stdout.writeln('  }');
      }
    }

    stdout.writeln('');
    stdout.writeln('PROBE OK');
  } catch (e, st) {
    stderr.writeln('PROBE FAILED: $e');
    stderr.writeln(st);
    exitCode = 1;
  } finally {
    client.close();
  }
}

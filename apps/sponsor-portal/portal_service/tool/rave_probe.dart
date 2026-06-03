// Live-verify-once RAVE probe.
//
// Reuses the existing `rave_integration` RaveClient to fetch Sites + Subjects
// from RAVE/Medidata EDC and confirm their field SHAPES (null vs non-null +
// runtime type), so we can confirm creds/endpoints still work before
// finalizing event payloads.
//
// This tool writes NO new HTTP/auth code — all transport and parsing go
// through RaveClient / its OdmParser.
//
// REDACTION RULES (this RAVE instance is sponsor-identifying):
//   - NEVER print the URL, username, or password.
//   - NEVER print raw field VALUES (site oids/names, subject keys, study
//     oids, site numbers, etc).
//   - Print ONLY structural info: field name, null vs non-null, runtime type,
//     and counts. The getVersion() web-services version string is not
//     sensitive and may be printed.
//
// Run:
//   dart run tool/rave_probe.dart
// (creds RAVE_UAT_URL / RAVE_UAT_USERNAME / RAVE_UAT_PWD read from the env;
// the session is expected to be launched under `doppler run`).

import 'dart:io';

import 'package:rave_integration/rave_integration.dart';

/// Renders a single field as a redacted shape: `<label>: null` or
/// `<label>: non-null <RuntimeType>`. Never echoes the value itself.
String _shape(String label, Object? value) =>
    value == null ? '$label: null' : '$label: non-null ${value.runtimeType}';

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
    // 1. Connectivity (no auth). Version string is not sensitive.
    final version = await client.getVersion();
    stdout.writeln('getVersion(): $version');

    // 2. Auth check. getStudies() returns raw ODM XML; we confirm the call
    // succeeds (auth OK) and report ONLY the body length — never the body.
    final studiesXml = await client.getStudies();
    stdout.writeln(
      'getStudies(): OK (auth succeeded), '
      'response length ${studiesXml.length} chars',
    );

    // 3. Sites across all accessible studies (studyOid: null).
    final sites = await client.getSites();
    stdout.writeln('');
    stdout.writeln('getSites(studyOid: <all>): count = ${sites.length}');
    if (sites.isNotEmpty) {
      final s = sites.first;
      stdout.writeln('  first RaveSite field shapes (no values):');
      stdout.writeln('    ${_shape('RaveSite.oid', s.oid)}');
      stdout.writeln('    ${_shape('RaveSite.name', s.name)}');
      stdout.writeln('    ${_shape('RaveSite.isActive', s.isActive)}');
      stdout.writeln(
        '    ${_shape('RaveSite.studySiteNumber', s.studySiteNumber)}',
      );
      stdout.writeln('    ${_shape('RaveSite.studyOid', s.studyOid)}');
      stdout.writeln(
        '    ${_shape('RaveSite.metaDataVersionOid', s.metaDataVersionOid)}',
      );
      stdout.writeln(
        '    ${_shape('RaveSite.effectiveDate', s.effectiveDate)}',
      );
    }

    // 4. Study OID for getSubjects(): prefer explicit RAVE_STUDY_OID env var,
    // else fall back to the first site's studyOid. Never printed either way.
    final envStudyOid = env['RAVE_STUDY_OID'];
    final String? studyOid;
    if (envStudyOid != null && envStudyOid.isNotEmpty) {
      studyOid = envStudyOid;
      stdout.writeln('');
      stdout.writeln(
        'study OID source: RAVE_STUDY_OID env var (value redacted)',
      );
    } else {
      studyOid = sites
          .map((s) => s.studyOid)
          .firstWhere((o) => o != null && o.isNotEmpty, orElse: () => null);
      stdout.writeln('');
      stdout.writeln('study OID source: first site studyOid (value redacted)');
    }

    // 5. Subjects (requires a study OID).
    stdout.writeln('');
    if (studyOid == null) {
      stdout.writeln(
        'getSubjects: SKIPPED — no study OID available '
        '(RAVE_STUDY_OID unset and no site studyOid).',
      );
    } else {
      final subjects = await client.getSubjects(studyOid: studyOid);
      stdout.writeln(
        'getSubjects(studyOid: <redacted>): '
        'count = ${subjects.length}',
      );
      if (subjects.isNotEmpty) {
        final sub = subjects.first;
        stdout.writeln('  first RaveSubject field shapes (no values):');
        stdout.writeln(
          '    ${_shape('RaveSubject.subjectKey', sub.subjectKey)}',
        );
        stdout.writeln('    ${_shape('RaveSubject.siteOid', sub.siteOid)}');
        stdout.writeln(
          '    ${_shape('RaveSubject.siteNumber', sub.siteNumber)}',
        );
      }
    }

    stdout.writeln('');
    stdout.writeln('PROBE OK');
  } catch (e, st) {
    // The exception message could conceivably contain the URL; print only the
    // exception TYPE and the stack trace (which has no secret values). If you
    // need the message, inspect locally — do not commit it.
    stderr.writeln('PROBE FAILED: ${e.runtimeType}');
    stderr.writeln(st);
    exitCode = 1;
  } finally {
    client.close();
  }
}

// Test helper: load the bundled reference sponsor's role-permissions.yaml — the
// single source of truth for the role->permission grant matrix. portal_service
// is dart:io-free in lib (the platform package), so the YAML is supplied by the
// caller; tests that exercise enforcement against the real matrix load it here
// by walking up from the test's CWD to the repo root (the dir containing
// deployment/reference-sponsor), mirroring resolveSponsorConfigDir in
// portal_server_evs without taking a dependency on that package.
import 'dart:io';

const String _kReferenceYamlFromRepoRoot =
    'deployment/reference-sponsor/deployment/sponsor/role-permissions.yaml';

/// Read the bundled reference sponsor role-permissions.yaml as a String.
String referenceRoleGrantsYaml() {
  var d = Directory.current.absolute;
  while (true) {
    final candidate = File('${d.path}/$_kReferenceYamlFromRepoRoot');
    if (candidate.existsSync()) return candidate.readAsStringSync();
    final parent = d.parent;
    if (parent.path == d.path) {
      throw StateError(
        'could not locate $_kReferenceYamlFromRepoRoot walking up from '
        '${Directory.current.path}',
      );
    }
    d = parent;
  }
}

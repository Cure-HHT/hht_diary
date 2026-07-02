// Implements: CAL-OPS-sponsor-config-dir/A+B — all sponsor configuration lives
//   in ONE directory, discovered from a single inert SPONSOR_CONFIG_DIR pointer
//   (no per-environment config values). Unset resolves to the bundled reference
//   sponsor — a real, complete config, not a degenerate in-code default.
import 'dart:io';

/// Relative path (from the platform repo root) of the bundled reference
/// sponsor's config dir. Used only when SPONSOR_CONFIG_DIR is unset
/// (local/CI/tests); deployed images always set SPONSOR_CONFIG_DIR=/app/sponsor.
const String _kReferenceSponsorDirFromRepoRoot =
    'deployment/reference-sponsor/deployment/sponsor';

/// Resolve the one sponsor-config directory.
///
/// - `SPONSOR_CONFIG_DIR` set (deployed): use it verbatim; fail fast if absent.
/// - unset (local/CI/test): the bundled reference sponsor, located by walking
///   up from the current directory to the repo root (the dir containing
///   `deployment/reference-sponsor`).
String resolveSponsorConfigDir(Map<String, String> env) {
  final configured = env['SPONSOR_CONFIG_DIR']?.trim();
  if (configured != null && configured.isNotEmpty) {
    if (!Directory(configured).existsSync()) {
      throw StateError(
        'SPONSOR_CONFIG_DIR="$configured" is set but the directory does not exist',
      );
    }
    return configured;
  }
  return _locateReferenceSponsorDir();
}

/// Read `<dir>/role-permissions.yaml`, failing fast if absent.
String loadRolePermissionsYaml(String dir) {
  final file = File('$dir/role-permissions.yaml');
  if (!file.existsSync()) {
    throw StateError(
      'role-permissions.yaml not found in sponsor config dir "$dir"; '
      'verify SPONSOR_CONFIG_DIR points to a valid sponsor bundle',
    );
  }
  return file.readAsStringSync();
}

/// Implements: DIARY-DEV-role-permissions-seed/C
///   — the platform-required minimum SystemOperator grants. A sponsor's
///   role-permissions.yaml SystemOperator block MUST be a superset of these.
const Set<String> kSystemOperatorMinimumPermissions = <String>{
  'portal.rave.unwedge',
  'portal.user.create',
  'portal.user.create_admin',
  'portal.user.create_sysop',
  'portal.user.grant_role',
  'portal.user.edit',
  'portal.user.deactivate',
  'portal.user.reactivate',
  'portal.user.unlock',
  'portal.user.resend_activation',
  'portal.user.assign_role',
  'portal.user.assign_site',
  'portal.user.revoke_role',
  'portal.user.revoke_site',
  'portal.user.delete_pending',
  'portal.site.view',
  'portal.rave.view_sync',
  'portal.user.view_accounts',
};

String _locateReferenceSponsorDir() {
  var d = Directory.current.absolute;
  while (true) {
    final candidate = Directory('${d.path}/$_kReferenceSponsorDirFromRepoRoot');
    if (candidate.existsSync()) return candidate.absolute.path;
    final parent = d.parent;
    if (parent.path == d.path) {
      throw StateError(
        'could not locate the bundled reference sponsor '
        '($_kReferenceSponsorDirFromRepoRoot) walking up from '
        '${Directory.current.path}; set SPONSOR_CONFIG_DIR explicitly',
      );
    }
    d = parent;
  }
}

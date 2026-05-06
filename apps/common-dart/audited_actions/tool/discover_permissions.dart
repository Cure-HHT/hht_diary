// IMPLEMENTS REQUIREMENTS:
//   REQ-d00169-D: CLI driver for the permission discovery emitter.
//
// Usage (CLI shape; the deploying app wires this with its own registry):
//
//   dart run audited_actions:discover_permissions \
//     --output migrations/<n>_permissions_<date>.sql
//
// In-process usage (deploying app calls emitPermissionsMigrationSql
// directly with its populated permission set):
//
//   import 'package:audited_actions/src/permission_discovery.dart';
//   final sql = emitPermissionsMigrationSql(
//     declared: myAppPermissions, // Set<String>
//     existing: await readExistingFromDb(),
//   );

import 'dart:io';

/// Smoke entry point. Without an injected permission set, prints usage.
/// Deploying apps wrap this with their own permission-loading code.
void main(List<String> args) {
  stderr.writeln(
    'discover_permissions: this is a thin entry point. To use:\n'
    '  - Collect declared permissions from your app as a Set<String>.\n'
    '  - Call emitPermissionsMigrationSql(declared: ..., existing: ...).\n'
    '  - Write the result to your migrations directory.\n'
    '\n'
    'See lib/src/permission_discovery.dart for the API contract.',
  );
}

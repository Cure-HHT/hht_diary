// Verifies: DIARY-OPS-single-promotable-artifact/A
//
// Guardrail: the portal_server container is a single promotable image whose
// environment-specific behavior derives exclusively from runtime environment
// variables (read via Platform.environment, e.g. DatabaseConfig.fromEnvironment
// and IdentityConfig). No deployment-environment identity (dev/qa/uat/prod) may
// be baked into the binary via a compile-time --dart-define.
//
// This test scans the server-reachable source for primitive
// `String/int/bool.fromEnvironment('KEY')` reads (the only Dart construct that
// bakes a value into the AOT snapshot) and fails if any KEY names a deployment
// environment. It does NOT flag custom `*.fromEnvironment()` factories — those
// read Platform.environment at runtime, which is the intended mechanism.

import 'dart:io';

import 'package:test/test.dart';

/// Compile-time dart-define keys that would brand the image with an
/// environment identity. Reading any of these via String/int/bool
/// .fromEnvironment defeats the single-promotable-artifact guarantee.
const _forbiddenCompileTimeKeys = {
  'ENVIRONMENT',
  'DEPLOY_ENV',
  'APP_ENV',
  'ENV',
  'STAGE',
  'FLAVOR',
  'APP_FLAVOR',
  'BUILD_ENV',
  'DEPLOYMENT',
  'TARGET_ENV',
};

/// Matches `String.fromEnvironment('KEY'`, `int.fromEnvironment("KEY"`, etc.
final _compileTimeRead = RegExp(
  r'''(?:String|int|bool)\.fromEnvironment\(\s*['"]([A-Z0-9_]+)['"]''',
);

/// Source trees compiled into the portal_server binary: its own bin + lib, and
/// the portal_functions package it links.
const _scanDirs = ['bin', 'lib', '../portal_functions/lib'];

void main() {
  test(
    'portal_server bakes no deployment-environment identity into the image',
    () {
      final foundKeys = <String>{};
      final offenders = <String>[];
      var filesScanned = 0;

      for (final dir in _scanDirs) {
        final root = Directory(dir);
        if (!root.existsSync()) continue;
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          filesScanned++;
          for (final m in _compileTimeRead.allMatches(
            entity.readAsStringSync(),
          )) {
            final key = m.group(1)!;
            foundKeys.add(key);
            if (_forbiddenCompileTimeKeys.contains(key)) {
              offenders.add('${entity.path}: String.fromEnvironment($key)');
            }
          }
        }
      }

      // Non-vacuity guard: the scan must actually reach the binary's source.
      // The version constants are always present; if we found none, the scan
      // paths are wrong and the test would pass for the wrong reason.
      expect(
        filesScanned,
        greaterThan(0),
        reason: 'scanned no Dart files — check _scanDirs paths',
      );
      expect(
        foundKeys,
        contains('PORTAL_SERVER_VERSION'),
        reason: 'expected to find the version dart-define; scan may be broken',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'portal_server compiles in a deployment-environment identity. '
            'Environment behavior must derive from runtime Platform.environment '
            '(e.g. the ENVIRONMENT var), not a --dart-define. Offenders:\n'
            '${offenders.join('\n')}',
      );
    },
  );
}

// Verifies: DIARY-OPS-single-promotable-artifact/A
//
// Guardrail: the diary-service container is a single promotable image whose
// environment-specific behavior derives exclusively from runtime environment
// variables (read via Platform.environment, e.g. DatabaseConfig.fromEnvironment).
// No deployment-environment identity (dev/qa/uat/prod) may be baked into the
// binary via a compile-time --dart-define.
//
// This test scans the server-reachable source for primitive
// `String/int/bool.fromEnvironment('KEY')` reads (the only Dart construct that
// bakes a value into the AOT snapshot) and fails if any KEY names a deployment
// environment. It does NOT flag custom `*.fromEnvironment()` factories — those
// read Platform.environment at runtime, which is the intended mechanism.

import 'dart:io';

import 'package:test/test.dart';

/// Compile-time dart-define keys that would brand the image with an
/// environment identity.
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

/// Source trees compiled into the diary-service binary: its own bin + lib, and
/// the diary_functions package it links.
const _scanDirs = ['bin', 'lib', '../diary_functions/lib'];

void main() {
  test(
    'diary-service bakes no deployment-environment identity into the image',
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
      expect(
        filesScanned,
        greaterThan(0),
        reason: 'scanned no Dart files — check _scanDirs paths',
      );
      expect(
        foundKeys,
        contains('DIARY_SERVER_VERSION'),
        reason: 'expected to find the version dart-define; scan may be broken',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'diary-service compiles in a deployment-environment identity. '
            'Environment behavior must derive from runtime Platform.environment '
            '(e.g. the ENVIRONMENT var), not a --dart-define. Offenders:\n'
            '${offenders.join('\n')}',
      );
    },
  );
}

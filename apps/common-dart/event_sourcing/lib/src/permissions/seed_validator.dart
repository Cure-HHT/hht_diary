// lib/src/permissions/seed_validator.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00175-B (unknown permission name -> invalid),
//   REQ-d00175-C (grant key absent from roles list -> invalid),
//   REQ-d00175-D (role missing from grants -> invalid),
//   REQ-d00175-E (role/permission name containing ':' -> invalid).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';

@immutable
sealed class SeedValidationResult {
  const SeedValidationResult();
}

final class SeedValid extends SeedValidationResult {
  const SeedValid();
}

final class SeedInvalid extends SeedValidationResult {
  const SeedInvalid(this.errors);
  final List<String> errors;
}

class SeedValidator {
  SeedValidationResult validate(PermissionSeed seed, Set<Permission> declared) {
    final errors = <String>[];
    final declaredNames = declared.map((p) => p.name).toSet();

    // REQ-d00175-E: name colon check on roles.
    for (final role in seed.roles) {
      if (role.contains(':')) {
        errors.add("role name contains ':': $role");
      }
    }
    // REQ-d00175-E: name colon check on permissions.
    for (final entry in seed.grants.entries) {
      for (final perm in entry.value) {
        if (perm.contains(':')) {
          errors.add("permission name contains ':': $perm");
        }
      }
    }

    // REQ-d00175-C: every grant key must be in roles.
    for (final role in seed.grants.keys) {
      if (!seed.roles.contains(role)) {
        errors.add('grant key "$role" not in roles list');
      }
    }

    // REQ-d00175-D: every role must have a grant entry.
    for (final role in seed.roles) {
      if (!seed.grants.containsKey(role)) {
        errors.add('role "$role" missing from grants');
      }
    }

    // REQ-d00175-B: every granted permission name must be in declared.
    for (final entry in seed.grants.entries) {
      for (final perm in entry.value) {
        if (!declaredNames.contains(perm)) {
          errors.add(
            'permission "$perm" granted to "${entry.key}" not declared by any Action',
          );
        }
      }
    }

    return errors.isEmpty ? const SeedValid() : SeedInvalid(errors);
  }
}

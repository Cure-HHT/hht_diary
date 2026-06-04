// Parses a sponsor-supplied "seeded users" config (JSON) into a
// [RoleAssignmentSeed]. Deployed environments point PORTAL_SEED_USERS_PATH at a
// file bundled by the sponsor repo (e.g. SystemOperator-only for dev, who then
// provision the first admins); local/test runs omit it and fall back to the
// in-code convenience seed.
//
// The library applies the seed idempotently (diffs against user_role_scopes and
// emits only missing role_assigned events), so this file is re-read and applied
// on every boot — additions in an edited config propagate on redeploy; entries
// removed from the config surface as drift and are NOT auto-unassigned (revoke
// is an explicit action), per bootstrap_role_assignments.dart.
//
// Implements: DIARY-DEV-portal-seed-config/A+B
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';

/// Parse a seed-users JSON document into a [RoleAssignmentSeed].
///
/// Shape:
/// ```json
/// {
///   "users": [
///     { "userId": "operator-1", "assignments": [
///         { "role": "SystemOperator", "scope": { "class": "tier", "wildcard": true } },
///         { "role": "SystemOperator", "scope": { "class": "site", "wildcard": true } }
///     ]}
///   ]
/// }
/// ```
/// Scope encodings:
/// - `{ "total": true }`                       -> [TotalWildcardScope]
/// - `{ "class": C, "wildcard": true }`        -> [ValueWildcardScope]
/// - `{ "class": C, "value": V }`              -> [BoundScope]
RoleAssignmentSeed parseSeedUsers(String jsonSource) {
  final Object? doc;
  try {
    doc = jsonDecode(jsonSource);
  } on FormatException catch (e) {
    throw FormatException('seed-users: invalid JSON ($e)');
  }
  if (doc is! Map) {
    throw const FormatException('seed-users: root must be a JSON object');
  }
  final users = doc['users'];
  if (users is! List) {
    throw const FormatException('seed-users: "users" must be a list');
  }
  final entries = <RoleAssignmentSeedEntry>[];
  for (final u in users) {
    if (u is! Map) {
      throw const FormatException('seed-users: each user must be an object');
    }
    final userId = u['userId'];
    if (userId is! String || userId.trim().isEmpty) {
      throw const FormatException(
          'seed-users: each user needs a non-empty userId');
    }
    final assignments = u['assignments'];
    if (assignments is! List || assignments.isEmpty) {
      throw FormatException(
          'seed-users: "$userId" needs a non-empty assignments list');
    }
    for (final a in assignments) {
      if (a is! Map) {
        throw FormatException(
            'seed-users: "$userId" assignment must be an object');
      }
      final role = a['role'];
      if (role is! String || role.trim().isEmpty) {
        throw FormatException(
            'seed-users: "$userId" assignment needs a non-empty role');
      }
      entries.add(RoleAssignmentSeedEntry(
        userId: userId.trim(),
        role: role.trim(),
        scope: _parseScope(a['scope'], userId),
      ));
    }
  }
  return RoleAssignmentSeed(entries: entries);
}

ScopeValue _parseScope(Object? raw, String userId) {
  if (raw is! Map) {
    throw FormatException('seed-users: "$userId" scope must be an object');
  }
  if (raw['total'] == true) return const TotalWildcardScope();
  final cls = raw['class'];
  if (cls is! String || cls.trim().isEmpty) {
    throw FormatException(
        'seed-users: "$userId" scope needs "class" (or "total": true)');
  }
  if (raw['wildcard'] == true) return ValueWildcardScope(class_: cls.trim());
  final value = raw['value'];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException(
        'seed-users: "$userId" scope needs "value" or "wildcard": true');
  }
  return BoundScope(class_: cls.trim(), value: value.trim());
}

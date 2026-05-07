// lib/src/permissions/bootstrap_action_permissions.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00178-B (top-level bootstrap sequence: load -> validate -> apply
//   -> construct policy).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:event_sourcing/src/permissions/authorization_policy_bootstrap.dart';
import 'package:event_sourcing/src/permissions/event_seed_applier.dart';
import 'package:event_sourcing/src/permissions/materialized_view_role_matrix_reader.dart';
import 'package:event_sourcing/src/permissions/seed_validator.dart';
import 'package:event_sourcing/src/permissions/table_backed_authorization_policy.dart';
import 'package:event_sourcing/src/permissions/yaml_seed_loader.dart';

/// Bootstraps the role-permission matrix from a YAML seed.
///
/// Provide either [yamlPath] (loads from disk) or [yamlSource] (loads from
/// string); supplying both, or neither, is a programmer error.
Future<AuthorizationPolicyBootstrap> bootstrapActionPermissions({
  required EventStore eventStore,
  required Set<Permission> declaredPermissions,
  String? yamlPath,
  String? yamlSource,
  Initiator seedInitiator = const AutomationInitiator(
    service: 'event_sourcing_permissions_seed',
  ),
}) async {
  if ((yamlPath == null) == (yamlSource == null)) {
    throw ArgumentError(
      'exactly one of yamlPath or yamlSource must be provided',
    );
  }

  // 1. Load seed.
  final loader = YamlSeedLoader();
  final seed = yamlSource != null
      ? loader.loadFromString(yamlSource)
      : loader.loadFromFile(yamlPath!);

  // 2. Validate.
  final validation = SeedValidator().validate(seed, declaredPermissions);
  if (validation is SeedInvalid) {
    return PolicyFailSafe(validation.errors);
  }

  // 3. Apply seed (emit missing grants).
  final applier = EventSeedApplier(
    eventStore: eventStore,
    seedInitiator: seedInitiator,
  );
  await applier.apply(seed, declaredPermissions);

  // 4. Wrap in TableBackedAuthorizationPolicy over MaterializedViewRoleMatrixReader.
  final reader = MaterializedViewRoleMatrixReader(eventStore.backend);
  final policy = TableBackedAuthorizationPolicy(reader);
  return PolicyReady(policy);
}

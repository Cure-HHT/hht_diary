import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'site_options.dart';
import 'user_account_flows.dart';
import 'user_account_logic.dart';

// Implements: DIARY-DEV-user-account-projection/A+C

/// Create-user dialog wiring (Figma: User Managment / Create New User).
///
/// Renders the shared [UserFormDialog] over a `sites_index`
/// subscription, and on Confirm dispatches `ACT-USR-001` followed by
/// the role/site assignment plan, sequentially, through the action
/// submitter. Validation errors surface inside the dialog's error
/// banner; the dialog pops only on full success.
///
/// [offerSystemOperator] widens the role list for principals that hold
/// `portal.user.grant_role` (SystemOperator assignment is parse-denied
/// for everyone else, so offering it would be a dead checkbox).
class CreateUserDialog extends StatelessWidget {
  const CreateUserDialog({super.key, this.offerSystemOperator = false});

  final bool offerSystemOperator;

  @override
  Widget build(BuildContext context) {
    final roles = <String>[
      PortalRole.administrator.systemName,
      PortalRole.studyCoordinator.systemName,
      PortalRole.cra.systemName,
      if (offerSystemOperator) PortalRole.systemOperator.systemName,
    ];
    return SiteOptionsView(
      builder: (context, sites, sitesLoading) => UserFormDialog(
        title: 'Create User',
        subtitle:
            'Add a new study coordinator, CRA, or admin to '
            'the system.',
        submitLabel: 'Confirm',
        roleOptions: roles,
        siteScopedRoles: {
          for (final r in roles)
            if (roleScopeKind(r) == RoleScopeKind.site) r,
        },
        roleDisplayName: portalRoleDisplayName,
        siteOptions: sites,
        sitesLoading: sitesLoading,
        onSubmit: (data) => _create(context, data),
      ),
    );
  }

  Future<String?> _create(BuildContext context, UserFormData data) async {
    final client = ActionClient(ReActionScope.of(context).actionSubmitter);
    final sites = data.sites.toList();
    try {
      final created = await client.submit(
        ActionSubmission(
          actionName: createUserAction,
          rawInput: <String, Object?>{
            'email': data.email,
            'name': data.name,
            'activationExpiresAt': activationExpiresAtFromNow(),
            'roles': data.roles.toList(),
            'sites': sites,
          },
        ),
      );
      if (created is! DispatchSuccess && created is! DispatchIdempotencyHit) {
        return 'Create denied: ${dispatchDenialLabel(created)}';
      }

      final plan = planAssignmentChanges(
        desired: <DesiredAssignment>[
          for (final r in data.roles)
            DesiredAssignment(
              role: r,
              sites: roleScopeKind(r) == RoleScopeKind.site ? sites : const [],
            ),
        ],
        current: const <CurrentTuple>[],
      );
      return await submitAll(
        client,
        assignmentSubmissions(plan, data.email, roleScopesJsonFor),
      );
    } catch (e) {
      return 'Failed: $e';
    }
  }
}

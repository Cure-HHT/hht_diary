import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'site_options.dart';
import 'user_account_logic.dart';

/// Human label for a denied/failed dispatch — shown inside dialog error
/// banners.
String dispatchDenialLabel(DispatchResult<Object?> r) => switch (r) {
  DispatchAuthorizationDenied(:final permission) => 'denied ($permission)',
  DispatchValidationDenied(:final error) => 'invalid ($error)',
  DispatchParseDenied(:final error) => 'parse ($error)',
  DispatchUnknownAction(:final requestedName) => 'unknown ($requestedName)',
  DispatchExecutionFailed(:final error) => 'failed ($error)',
  _ => 'denied',
};

/// Submits [submissions] in order, stopping at the first failure.
/// Returns null when everything committed, or a user-facing error.
Future<String?> submitAll(
  ActionClient client,
  List<ActionSubmission> submissions,
) async {
  for (final s in submissions) {
    final r = await client.submit(s);
    if (r is! DispatchSuccess && r is! DispatchIdempotencyHit) {
      return '${s.actionName}: ${dispatchDenialLabel(r)}';
    }
  }
  return null;
}

/// Canonical display label for a backend role name (e.g.
/// `StudyCoordinator` -> "Study Coordinator").
String portalRoleDisplayName(String role) =>
    PortalRole.fromSystemName(role)?.canonicalDisplayName ?? role;

/// Submits one action and returns null on success / an error label.
Future<String?> _submitOne(
  BuildContext context,
  String actionName,
  Map<String, Object?> rawInput,
) async {
  final client = ActionClient(ReActionScope.of(context).actionSubmitter);
  try {
    final r = await client.submit(
      ActionSubmission(actionName: actionName, rawInput: rawInput),
    );
    if (r is! DispatchSuccess && r is! DispatchIdempotencyHit) {
      return dispatchDenialLabel(r);
    }
    return null;
  } catch (e) {
    return 'Failed: $e';
  }
}

/// Opens the User Details dialog with the user's bound sites resolved
/// from `sites_index`. Resolves to the follow-up action the user picked
/// from the dialog's action list, or null on Close.
Future<UserRowAction?> showUserDetailsFlow(
  BuildContext context, {
  required PortalUserView user,
  required UserRowActionsConfig config,
}) => showDialog<UserRowAction>(
  context: context,
  builder: (_) => SiteOptionsView(
    builder: (context, sites, _) {
      final bound = user.boundSites.toSet();
      return UserDetailsDialog(
        user: user,
        sites: [
          for (final s in sites)
            if (bound.contains(s.id)) s,
        ],
        actions: config.itemsFor(user),
        inviteSent: config.inviteSentFor(user),
      );
    },
  ),
);

/// Opens the Edit User dialog pre-filled from [user]; on Save dispatches
/// the profile edit (when changed) followed by the assignment diff.
/// Resolves to true when something was submitted successfully.
// Implements: DIARY-GUI-user-information-modal/M
// Implements: DIARY-PRD-user-account-edit/E — assignment changes dispatch
//   immediately on save; enforcement is server-side.
Future<bool?> showEditUserFlow(
  BuildContext context, {
  required PortalUserView user,
  bool offerSystemOperator = false,
  VoidCallback? onBack,
}) {
  final roles = <String>[
    PortalRole.administrator.systemName,
    PortalRole.studyCoordinator.systemName,
    PortalRole.cra.systemName,
    // Keep an already-assigned SystemOperator visible/uncheckable-aware
    // even when the editor can't grant it, so saving doesn't silently
    // revoke a role the form never displayed.
    if (offerSystemOperator ||
        user.distinctRoles.contains(PortalRole.systemOperator.systemName))
      PortalRole.systemOperator.systemName,
  ];
  final (firstName, lastName) = splitDisplayName(user.name);
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SiteOptionsView(
      builder: (context, sites, sitesLoading) => UserFormDialog(
        title: 'Edit User',
        subtitle:
            'Update user details and site assignments. Changes take '
            'effect immediately and cannot be reversed automatically.',
        submitLabel: 'Save Changes',
        roleOptions: roles,
        siteScopedRoles: {
          for (final r in roles)
            if (roleScopeKind(r) == RoleScopeKind.site) r,
        },
        roleDisplayName: portalRoleDisplayName,
        siteOptions: sites,
        sitesLoading: sitesLoading,
        initialFirstName: firstName,
        initialLastName: lastName,
        initialEmail: user.email,
        initialRoles: user.distinctRoles.toSet(),
        initialSites: user.boundSites.toSet(),
        warningTitle: 'Active sessions will be terminated',
        warning:
            'The user will need to log in again to see their updated '
            'permissions.',
        onBack: onBack,
        onSubmit: (data) => _saveEdit(context, user, data),
      ),
    ),
  );
}

Future<String?> _saveEdit(
  BuildContext context,
  PortalUserView user,
  UserFormData data,
) async {
  final client = ActionClient(ReActionScope.of(context).actionSubmitter);
  final sites = data.sites.toList();
  final plan = planAssignmentChanges(
    desired: <DesiredAssignment>[
      for (final r in data.roles)
        DesiredAssignment(
          role: r,
          sites: roleScopeKind(r) == RoleScopeKind.site ? sites : const [],
        ),
    ],
    current: currentTuplesFor(user),
  );
  try {
    return await submitAll(
      client,
      editUserSubmissions(
        userId: user.email,
        newName: data.name != user.name ? data.name : null,
        newEmail: data.email != user.email ? data.email : null,
        plan: plan,
      ),
    );
  } catch (e) {
    return 'Failed: $e';
  }
}

/// Deactivate confirmation -> ACT-USR-003. Resolves true on success.
// Implements: DIARY-GUI-user-account-deactivate/B
Future<bool?> showDeactivateUserFlow(
  BuildContext context, {
  required PortalUserView user,
  VoidCallback? onBack,
}) => DeactivateUserDialog.show(
  context,
  userName: user.name,
  onBack: onBack,
  onSubmit: (reason) => _submitOne(context, deactivateUserAction, {
    'userId': user.email,
    'reason': reason,
  }),
);

/// Reactivate confirmation -> ACT-USR-004. Resolves true on success.
// Implements: DIARY-GUI-user-account-reactivate/B
Future<bool?> showReactivateUserFlow(
  BuildContext context, {
  required PortalUserView user,
  VoidCallback? onBack,
}) => ReactivateUserDialog.show(
  context,
  userName: user.name,
  onBack: onBack,
  onSubmit: (reason) => _submitOne(context, reactivateUserAction, {
    'userId': user.email,
    'reason': reason,
    'activationExpiresAt': activationExpiresAtFromNow(),
  }),
);

/// Reason prompt -> ACT-USR-005 unlock. Resolves true on success.
Future<bool> showUnlockUserFlow(
  BuildContext context, {
  required PortalUserView user,
}) async {
  final reason = await AppDialog.reason(
    context: context,
    title: 'Unlock User Account',
    message:
        'Unlock the account for "${user.name}" so the user can sign in '
        'again.',
    reasonLabel: 'Reason for unlocking',
    hintText: 'Enter reason for unlocking this user',
    submitLabel: 'Confirm',
  );
  if (reason == null || !context.mounted) return false;
  final error = await _submitOne(context, unlockUserAction, {
    'userId': user.email,
    'reason': reason,
  });
  if (error != null && context.mounted) {
    await AppDialog.acknowledgment(
      context: context,
      title: 'Unlock failed',
      message: error,
    );
    return false;
  }
  return error == null;
}

/// Dispatches ACT-USR-006 (resend activation email) directly — the
/// Figma flow has no confirmation step. Resolves true on success; shows
/// an acknowledgment dialog on failure.
Future<bool> resendInviteFlow(
  BuildContext context, {
  required PortalUserView user,
}) async {
  final error = await _submitOne(context, resendActivationAction, {
    'userId': user.email,
    'activationExpiresAt': activationExpiresAtFromNow(),
  });
  if (error != null && context.mounted) {
    await AppDialog.acknowledgment(
      context: context,
      title: 'Resend invite failed',
      message: error,
    );
  }
  return error == null;
}

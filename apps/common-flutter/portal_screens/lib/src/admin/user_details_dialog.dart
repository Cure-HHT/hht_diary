import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/portal_user_view.dart';
import '../models/site_option_view.dart';
import '../models/user_status_view.dart';
import '../widgets/role_pill.dart';
import 'panel_tint.dart';
import 'user_row_actions.dart';

/// User Details dialog (Figma: User Details / User Information).
///
/// Read-only summary of one user — status, name, email, role pills,
/// assigned sites — plus the action list mirroring the row kebab, all
/// grouped inside one tinted identity card. Pops with the chosen
/// [UserRowAction] (the wiring layer then opens the matching flow
/// dialog) or `null` on Close.
///
/// Pure presentation: the caller resolves site labels and pre-computes
/// the legal [actions] before opening.
// Implements: DIARY-GUI-user-information-modal/A+B+I+J+L
class UserDetailsDialog extends StatelessWidget {
  const UserDetailsDialog({
    super.key,
    required this.user,
    required this.sites,
    required this.actions,
    this.inviteSent = false,
  });

  /// The row being inspected.
  final PortalUserView user;

  /// Resolved site options for the user's bound sites, in display order.
  /// Ignored when the user holds a wildcard scope ("All sites").
  final List<SiteOptionView> sites;

  /// Action list to offer, already filtered to status-legal + permitted
  /// items (use [UserRowActionsConfig.itemsFor]). [UserRowAction.viewDetails]
  /// entries are skipped — we're already here.
  final List<UserRowAction> actions;

  /// Renders the Resend Invite row as a disabled "Invite Sent" entry.
  final bool inviteSent;

  /// Opens the dialog. Resolves to the action the user picked, or null.
  static Future<UserRowAction?> show(
    BuildContext context, {
    required PortalUserView user,
    required List<SiteOptionView> sites,
    required List<UserRowAction> actions,
    bool inviteSent = false,
  }) => showDialog<UserRowAction>(
    context: context,
    builder: (_) => UserDetailsDialog(
      user: user,
      sites: sites,
      actions: actions,
      inviteSent: inviteSent,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleActions = [
      for (final a in actions)
        if (a != UserRowAction.viewDetails) a,
    ];

    return AppDialog(
      size: AppDialogSize.small,
      title: 'User Details',
      subtitle: 'View and manage user details, roles, and assigned sites.',
      semanticId: 'user-details-dialog',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: kAdminPanelTint,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(
                  kind: _badgeKindFor(user.status),
                  semanticId: 'user-details-status',
                ),
                const SizedBox(height: 8),
                Text(
                  user.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final role in user.distinctRoles)
                      RolePill(
                        systemRole: role,
                        variant: AppBadgeVariant.outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _AssignedSites(user: user, sites: sites),
                if (visibleActions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  const AppSectionHeader(title: 'Actions'),
                  const SizedBox(height: 8),
                  for (final action in visibleActions) ...[
                    _ActionRow(
                      action: action,
                      inviteSent: inviteSent,
                      onTap: () => Navigator.of(context).pop(action),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
      ),
      actions: [
        AppButton(
          label: 'Close',
          semanticId: 'user-details-close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _AssignedSites extends StatelessWidget {
  const _AssignedSites({required this.user, required this.sites});

  final PortalUserView user;
  final List<SiteOptionView> sites;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final Widget content;
    if (user.hasWildcardScope) {
      content = Text(
        'All sites',
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      );
    } else if (sites.isEmpty) {
      content = Text(
        'No sites assigned',
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sites.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Text(
              sites[i].label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            // Figma shows a location subtitle ("New York, NY") under each
            // site; sites_index carries no location data yet, so the line
            // is omitted until EDC ingest provides one.
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Assigned Sites',
          count: user.hasWildcardScope ? null : sites.length,
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.inviteSent,
    required this.onTap,
  });

  final UserRowAction action;
  final bool inviteSent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = action == UserRowAction.resendInvite && inviteSent;
    final destructive = action == UserRowAction.deactivate;

    // Figma: actionable rows carry their accent color on BOTH icon and
    // label (teal for edit/resend, red for deactivate); the spent
    // "Invite Sent" row is muted with a leading check.
    final color = disabled
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : destructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    final icon = disabled
        ? Icons.check
        : switch (action) {
            UserRowAction.edit => Icons.edit_outlined,
            UserRowAction.resendInvite => Icons.send_outlined,
            UserRowAction.deactivate => Icons.block_outlined,
            UserRowAction.reactivate => Icons.refresh,
            UserRowAction.unlock => Icons.lock_open_outlined,
            UserRowAction.viewDetails => Icons.visibility_outlined,
          };

    final label = disabled ? 'Invite Sent' : userRowActionLabel(action);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

StatusBadgeKind _badgeKindFor(UserStatusView s) => switch (s) {
  UserStatusView.active => StatusBadgeKind.active,
  UserStatusView.pending => StatusBadgeKind.pending,
  UserStatusView.revoked => StatusBadgeKind.inactive,
  UserStatusView.locked => StatusBadgeKind.atRisk,
  UserStatusView.unknown => StatusBadgeKind.inactive,
};

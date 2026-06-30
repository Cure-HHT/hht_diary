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
      // Figma title is "User Information" (the dialog summarizes one user).
      // Implements: DIARY-GUI-user-information-modal/N
      title: 'User Information',
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
              _actionIcon(action, disabled: disabled, color: color),
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

/// Leading glyph for an action row. The Figma-designed Resend Invite and
/// Deactivate glyphs render from bundled PNGs (exported from the Sponsor Portal
/// Figma) — raster assets are immune to the MaterialIcons web font subsetting
/// that blanked the Deactivate ban icon (CUR-1525); the remaining actions use
/// MaterialIcons. Each PNG is a transparent alpha-mask glyph, recolored to the
/// row's accent via [BlendMode.srcIn] so the icon matches its label.
// Implements: DIARY-GUI-user-information-modal/O
Widget _actionIcon(
  UserRowAction action, {
  required bool disabled,
  required Color color,
}) {
  if (disabled) return Icon(Icons.check, size: 16, color: color);
  // The PNG is a transparent alpha-mask glyph; `color` + srcIn paints it the
  // row's accent. Widget tests don't initialise the package asset bundle and a
  // production cache miss should degrade to a Material glyph, not a stack trace
  // — so each asset falls back to its closest MaterialIcon via errorBuilder.
  Widget png(String name, IconData fallback) => Image.asset(
    'assets/icons/$name.png',
    package: 'portal_screens',
    width: 16,
    height: 16,
    color: color,
    colorBlendMode: BlendMode.srcIn,
    errorBuilder: (context, _, _) => Icon(fallback, size: 16, color: color),
  );
  return switch (action) {
    UserRowAction.resendInvite => png('resend_invite', Icons.send),
    UserRowAction.deactivate => png('deactivate', Icons.block),
    UserRowAction.edit => Icon(Icons.edit_outlined, size: 16, color: color),
    UserRowAction.reactivate => Icon(Icons.refresh, size: 16, color: color),
    UserRowAction.unlock => Icon(
      Icons.lock_open_outlined,
      size: 16,
      color: color,
    ),
    UserRowAction.viewDetails => Icon(
      Icons.visibility_outlined,
      size: 16,
      color: color,
    ),
  };
}

StatusBadgeKind _badgeKindFor(UserStatusView s) => switch (s) {
  UserStatusView.active => StatusBadgeKind.active,
  UserStatusView.pending => StatusBadgeKind.pending,
  UserStatusView.revoked => StatusBadgeKind.inactive,
  UserStatusView.locked => StatusBadgeKind.atRisk,
  UserStatusView.unknown => StatusBadgeKind.inactive,
};

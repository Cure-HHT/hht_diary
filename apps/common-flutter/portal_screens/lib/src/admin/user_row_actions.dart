import 'package:flutter/material.dart';

import '../models/portal_user_view.dart';
import '../models/user_status_view.dart';

/// One entry in the Users-table row kebab menu (and the mirrored action
/// list inside the User Details dialog).
enum UserRowAction {
  viewDetails,
  edit,
  resendInvite,
  deactivate,
  reactivate,
  unlock,
}

/// Wiring-layer contract for the Users-table row actions.
///
/// **Snapshot in, callbacks out** — the wiring layer computes the
/// capability flags from the active role's permission snapshot and owns
/// what each action does (which dialog opens, which Action is
/// dispatched). The presentation layer combines these flags with each
/// row's lifecycle status to decide which menu items render.
@immutable
class UserRowActionsConfig {
  const UserRowActionsConfig({
    required this.onAction,
    this.canEdit = false,
    this.canDeactivate = false,
    this.canReactivate = false,
    this.canResendInvite = false,
    this.canUnlock = false,
    this.inviteSentEmails = const <String>{},
  });

  /// Fired when a menu item is tapped.
  final void Function(PortalUserView user, UserRowAction action) onAction;

  /// Permission-derived capability flags. `viewDetails` has no flag —
  /// anyone who can see the table may inspect a row.
  final bool canEdit;
  final bool canDeactivate;
  final bool canReactivate;
  final bool canResendInvite;
  final bool canUnlock;

  /// Emails whose activation invite was re-sent in this session. Their
  /// "Resend Invite" item renders as a disabled "Invite Sent" entry
  /// (Figma: User Managment / Actions / Invite Sent).
  final Set<String> inviteSentEmails;

  /// The menu items legal for [user] — status-legal actions intersected
  /// with the held capabilities, in Figma order. [UserRowAction.viewDetails]
  /// is always present so the kebab never renders an empty menu.
  List<UserRowAction> itemsFor(PortalUserView user) => <UserRowAction>[
    UserRowAction.viewDetails,
    if (canEdit && _isEditable(user.status)) UserRowAction.edit,
    if (canResendInvite && user.status == UserStatusView.pending)
      UserRowAction.resendInvite,
    if (canDeactivate && _isEditable(user.status)) UserRowAction.deactivate,
    if (canReactivate && user.status == UserStatusView.revoked)
      UserRowAction.reactivate,
    if (canUnlock && user.status == UserStatusView.locked) UserRowAction.unlock,
  ];

  bool inviteSentFor(PortalUserView user) =>
      inviteSentEmails.contains(user.email);

  static bool _isEditable(UserStatusView s) =>
      s == UserStatusView.pending || s == UserStatusView.active;
}

/// The kebab button + popover menu on each Users-table row.
///
/// Renders a [MenuAnchor] styled per the Figma actions popover: white
/// surface, 8px radius, soft shadow, 13px items, destructive entries in
/// the error color. The "Invite Sent" state renders as a disabled item
/// with a leading check.
class UserRowMenu extends StatelessWidget {
  const UserRowMenu({super.key, required this.user, required this.config});

  final PortalUserView user;
  final UserRowActionsConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = config.itemsFor(user);
    final inviteSent = config.inviteSentFor(user);

    return MenuAnchor(
      // Align the popover's right edge under the kebab, like the Figma.
      alignmentOffset: const Offset(-120, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        shadowColor: WidgetStatePropertyAll(
          theme.colorScheme.shadow.withValues(alpha: 0.25),
        ),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
      ),
      menuChildren: [
        for (final action in items)
          _MenuItem(
            action: action,
            inviteSent: inviteSent,
            onSelected: () => config.onAction(user, action),
          ),
      ],
      builder: (context, controller, _) => IconButton(
        icon: const Icon(Icons.more_horiz, size: 18),
        tooltip: 'Row actions',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          minimumSize: const Size(32, 32),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.action,
    required this.inviteSent,
    required this.onSelected,
  });

  final UserRowAction action;
  final bool inviteSent;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = action == UserRowAction.resendInvite && inviteSent;
    final destructive = action == UserRowAction.deactivate;

    final color = disabled
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return MenuItemButton(
      onPressed: disabled ? null : onSelected,
      leadingIcon: disabled ? Icon(Icons.check, size: 16, color: color) : null,
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(168, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(
        disabled ? 'Invite Sent' : userRowActionLabel(action),
        style: TextStyle(
          fontSize: 13,
          height: 20 / 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

/// Canonical menu labels (Figma: User Managment / Actions).
String userRowActionLabel(UserRowAction action) => switch (action) {
  UserRowAction.viewDetails => 'View Details',
  UserRowAction.edit => 'Edit User',
  UserRowAction.resendInvite => 'Resend Invite',
  UserRowAction.deactivate => 'Deactivate User',
  UserRowAction.reactivate => 'Reactivate User',
  UserRowAction.unlock => 'Unlock User',
};

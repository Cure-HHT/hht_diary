import 'package:flutter/material.dart';

import '../models/portal_role.dart';
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
    this.canManageOperatorTier = false,
    this.currentUserEmail,
    this.inviteSentEmails = const <String>{},
  });

  /// Fired when a menu item is tapped.
  final void Function(PortalUserView user, UserRowAction action) onAction;

  /// The authenticated user's own id/email. Edit and Deactivate are
  /// suppressed on this row — self-edit and self-deactivation are
  /// prohibited at the PRD level, and the GUI makes the unavailable
  /// state visible instead of surfacing a server rejection.
  final String? currentUserEmail;

  /// Permission-derived capability flags. `viewDetails` has no flag —
  /// anyone who can see the table may inspect a row.
  final bool canEdit;
  final bool canDeactivate;
  final bool canReactivate;
  final bool canResendInvite;
  final bool canUnlock;

  /// True when the active role may manage operator-tier accounts (i.e.
  /// the viewer is a System Operator). When false, rows whose user holds
  /// the SystemOperator role offer View Details only — the server denies
  /// every user-scoped action against them (user-contained-in-tier,
  /// fail-closed), so showing the actions would just surface denials.
  final bool canManageOperatorTier;

  /// Emails whose activation invite was re-sent in this session. Their
  /// "Resend Invite" item renders as a disabled "Invite Sent" entry
  /// (Figma: User Managment / Actions / Invite Sent).
  final Set<String> inviteSentEmails;

  /// The menu items legal for [user] — status-legal actions intersected
  /// with the held capabilities, in Figma order. [UserRowAction.viewDetails]
  /// is always present so the kebab never renders an empty menu. The
  /// authenticated user's own row never offers Edit or Deactivate.
  // Implements: DIARY-GUI-user-account-deactivate/A
  // Implements: DIARY-GUI-user-account-reactivate/A
  // Implements: DIARY-GUI-user-information-modal/K
  List<UserRowAction> itemsFor(PortalUserView user) {
    final isSelf = user.email == currentUserEmail;
    // Operator-tier targets are untouchable for non-operator viewers —
    // hide (not dim) the actions the server would deny.
    final operatorTarget = user.distinctRoles.contains(
      PortalRole.systemOperator.systemName,
    );
    if (operatorTarget && !canManageOperatorTier) {
      return const <UserRowAction>[UserRowAction.viewDetails];
    }
    return <UserRowAction>[
      UserRowAction.viewDetails,
      if (canEdit && !isSelf && _isEditable(user.status)) UserRowAction.edit,
      if (canResendInvite && user.status == UserStatusView.pending)
        UserRowAction.resendInvite,
      if (canDeactivate && !isSelf && _isEditable(user.status))
        UserRowAction.deactivate,
      if (canReactivate && user.status == UserStatusView.revoked)
        UserRowAction.reactivate,
      if (canUnlock && user.status == UserStatusView.locked)
        UserRowAction.unlock,
    ];
  }

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
///
/// Each row owns its own [MenuController], but the popovers are
/// mutually exclusive: opening one closes any other. The row surfaces its
/// controller via [onMenuOpened]/[onMenuClosed] so a single coordinator
/// (the Users screen) can enforce "only one menu open at a time" — two
/// independent [MenuAnchor]s do not otherwise dismiss each other, which
/// would let their popovers stack.
class UserRowMenu extends StatefulWidget {
  const UserRowMenu({
    super.key,
    required this.user,
    required this.config,
    this.onMenuOpened,
    this.onMenuClosed,
  });

  final PortalUserView user;
  final UserRowActionsConfig config;

  /// Fired when this row's popover opens, handing the coordinator this
  /// row's [MenuController] so it can close any previously-open menu.
  final void Function(MenuController controller)? onMenuOpened;

  /// Fired when this row's popover closes (item tap, outside tap, or a
  /// coordinator-driven close), so the coordinator can clear its
  /// "currently open" reference when it points at this row.
  final void Function(MenuController controller)? onMenuClosed;

  @override
  State<UserRowMenu> createState() => _UserRowMenuState();
}

class _UserRowMenuState extends State<UserRowMenu> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.config.itemsFor(widget.user);
    final inviteSent = widget.config.inviteSentFor(widget.user);

    return MenuAnchor(
      controller: _controller,
      onOpen: () => widget.onMenuOpened?.call(_controller),
      onClose: () => widget.onMenuClosed?.call(_controller),
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
            onSelected: () => widget.config.onAction(widget.user, action),
          ),
      ],
      builder: (context, controller, _) => Semantics(
        // Domain-keyed Playwright handle: rows reorder under filters and
        // sorts, so the email (the table's row key) addresses the kebab,
        // never the position. container + explicitChildNodes keep the
        // identifier from merging into the IconButton's node on web.
        identifier: 'user-actions-${widget.user.email}',
        container: true,
        explicitChildNodes: true,
        child: IconButton(
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

    // Only one row menu is ever open, so the action name alone is a
    // stable handle (`user-action-edit`, ...). The MenuItemButton is the
    // role-bearing child — the identifier needs its own container node.
    return Semantics(
      identifier: 'user-action-${action.name}',
      container: true,
      explicitChildNodes: true,
      child: MenuItemButton(
        onPressed: disabled ? null : onSelected,
        leadingIcon: disabled
            ? Icon(Icons.check, size: 16, color: color)
            : null,
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

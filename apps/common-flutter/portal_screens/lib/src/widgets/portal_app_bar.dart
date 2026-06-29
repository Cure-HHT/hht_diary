import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/portal_role.dart';
import 'role_pill.dart';

/// Reusable portal-wide top header.
///
/// Single widget used across all dashboard tabs (User Accounts, Audit
/// Logs, Sites, Participants, RAVE Sync). The Admin variant (Figma image
/// 1, CUR-1450) is the canonical shape; non-Admin variants are the same
/// widget with different [subtitle] / [activeRole] / [availableRoles] /
/// [onHelp] inputs.
///
/// **Single- vs multi-role** is detected from `availableRoles.length`:
///
/// - **> 1**: renders the `Role:` prefix label + a tappable [RolePill]
///   with a dropdown caret. Tapping opens a popup menu of
///   [availableRoles]; selecting one fires [onRoleSelected].
///   [onRoleSelected] is required in this mode (asserted in debug).
/// - **<= 1**: renders the [RolePill] as a passive label — no `Role:`
///   prefix, no caret, no tap.
///
/// **Help icon** is conditional on [onHelp] being non-null. Null → not
/// rendered, single source of truth for visibility.
///
/// All inputs are plain strings + callbacks; this widget owns nothing
/// reactive and never reads sponsor / principal types directly. The
/// wiring layer (`portal_ui_evs`) reads the principal and feeds these
/// props.
class PortalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PortalAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.userName,
    required this.activeRole,
    required this.availableRoles,
    required this.onLogout,
    this.activeRoleDisplayName,
    this.onRoleSelected,
    this.onSettings,
    this.onHelp,
    this.logo,
    this.horizontalPadding = 48,
  }) : assert(
         availableRoles.length <= 1 || onRoleSelected != null,
         'PortalAppBar in multi-role mode requires onRoleSelected. Pass '
         'a single-element availableRoles list to render the pill as a '
         'passive label instead.',
       );

  /// Brand title (e.g. "Sponsor Portal"). Sponsor-driven —
  /// callers pass whatever the branding service yields.
  final String title;

  /// Per-tab subtitle. Plan §3 Q10b: reflects the active role
  /// (`"${role} Dashboard"`). Callers compute the string; this widget
  /// just renders it.
  final String subtitle;

  /// User display name shown to the right of the role pill.
  final String userName;

  /// Backend-canonical system role string for the user's current active
  /// role. Drives the [RolePill]'s tone and label.
  final String activeRole;

  /// Sponsor-mapped display name for [activeRole], when the wiring
  /// layer has a mapping. Forwarded to [RolePill.displayName]; null
  /// falls back to the canonical label.
  final String? activeRoleDisplayName;

  /// All system role strings the user can switch to. Length 1 → passive
  /// pill; length > 1 → switcher pill with dropdown menu.
  final List<String> availableRoles;

  /// Logout button callback. Always rendered.
  final VoidCallback onLogout;

  /// Fired when the user picks a new role from the switcher menu.
  /// Required in multi-role mode (the assert at the constructor catches
  /// missing wiring in debug).
  final ValueChanged<String>? onRoleSelected;

  /// Settings link callback (the blue underlined "Settings" between the
  /// role pill and the help icon in the Figma). When null, the link
  /// doesn't render. A Settings surface doesn't exist yet — wiring a
  /// no-op keeps the chrome faithful to the design until it lands.
  final VoidCallback? onSettings;

  /// Help icon callback. When null, the icon doesn't render at all.
  /// Plan §3 Q8: render the icon for v1 but `onHelp: () {}` is fine to
  /// keep the click as a no-op until docs land.
  final VoidCallback? onHelp;

  /// Optional sponsor logo rendered left of the title block. The wiring
  /// layer passes its branding widget (e.g. portal_ui_evs's
  /// SponsorBrandMark); null keeps the brand text flush left.
  final Widget? logo;

  /// Horizontal padding inside the bar. The default lines the title up
  /// with the body card's left edge in the canonical layout; consumers
  /// whose page chrome uses different gutters can override.
  final double horizontalPadding;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      // White surface to match the Figma's brand-coloured background
      // sitting flush against the page body underneath.
      color: theme.colorScheme.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (logo != null) ...[logo!, const SizedBox(width: 16)],
                      _Brand(title: title, subtitle: subtitle),
                    ],
                  ),
                ),
                // Right cluster, Figma order: user name · hairline ·
                // role pill · Settings · help · Logout.
                Text(
                  userName,
                  // Inter Regular 14 / line-height 20 / letter-spacing -0.15 /
                  // Black.
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                // Thin vertical separator between identity and the role /
                // action cluster.
                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 24,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(width: 16),
                _RoleCluster(
                  systemRole: activeRole,
                  displayName: activeRoleDisplayName,
                  availableRoles: availableRoles,
                  onRoleSelected: onRoleSelected,
                ),
                if (onSettings != null) ...[
                  const SizedBox(width: 20),
                  _SettingsLink(onPressed: onSettings!),
                ],
                if (onHelp != null) ...[
                  const SizedBox(width: 16),
                  _HelpIconButton(onPressed: onHelp!),
                ],
                const SizedBox(width: 16),
                AppButton(
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.medium,
                  label: 'Logout',
                  leadingIcon: Icons.logout,
                  onPressed: onLogout,
                  semanticId: 'appbar-logout',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Settings" link — primary-blue label with a 2px underline bar
/// sitting a few px below the text (Figma: reads as an active-tab style
/// indicator, not a text decoration).
class _SettingsLink extends StatelessWidget {
  const _SettingsLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'appbar-settings',
      button: true,
      container: true,
      explicitChildNodes: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Container(
            padding: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            child: Text(
              'Settings',
              // Inter Medium 14 / 20, primary — matches the role-cluster
              // text rhythm with the link tone from the Figma.
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.15,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Help affordance — Figma-exported PNG (the brand-blue circle with a
/// white `?` glyph) bundled with `portal_screens`.
///
/// Renders the asset inside a `Material + InkWell` directly rather than
/// `IconButton` — `IconButton` propagates an `IconThemeData` to its
/// child which Material 3 uses to dim the icon to its disabled
/// foreground in the idle state, ghosting the PNG until the button gets
/// pointer focus. Plain `Material + InkWell` gives us a tooltip + ripple
/// without that color path running.
class _HelpIconButton extends StatelessWidget {
  const _HelpIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      // Raw InkWell (not AppButton), so the Playwright handle is wrapped
      // here. container + explicitChildNodes keep the identifier on its
      // own node (web flattener gotcha — event_sourcing prd-reaction).
      identifier: 'appbar-help',
      button: true,
      container: true,
      explicitChildNodes: true,
      child: Tooltip(
        message: 'Help',
        // Material itself paints the brand-blue circle. The PNG asset is
        // just the white `?` glyph, sitting on top with transparent
        // background so the circle shows through.
        child: Material(
          color: theme.colorScheme.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Image.asset(
                  'assets/icons/help.png',
                  package: 'portal_screens',
                  width: 28,
                  height: 28,
                  // Widget tests don't initialise the package's asset
                  // bundle, so Image.asset would throw mid-test. The
                  // errorBuilder also makes a production asset-cache
                  // miss degrade to a Material default instead of a
                  // stack trace. Material already paints the circle, so
                  // the fallback is just the glyph.
                  errorBuilder: (context, _, _) => Icon(
                    Icons.question_mark,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          // Inter Bold 16 / line-height 24 / letter-spacing -0.31 / Black.
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            height: 24 / 16,
            letterSpacing: -0.31,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          // Inter Regular 14 / line-height 20 / letter-spacing -0.15 / Dark Grey.
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RoleCluster extends StatelessWidget {
  const _RoleCluster({
    required this.systemRole,
    required this.displayName,
    required this.availableRoles,
    required this.onRoleSelected,
  });

  final String systemRole;
  final String? displayName;
  final List<String> availableRoles;
  final ValueChanged<String>? onRoleSelected;

  bool get _isMultiRole => availableRoles.length > 1;

  /// Human label for a role row in the menu. The active role prefers the
  /// sponsor-mapped [displayName] (when the wiring layer supplied one);
  /// every other role resolves through the [PortalRole] catalog, falling
  /// back to the raw system string so an unknown role is still legible.
  String _labelFor(String role) {
    if (role == systemRole && displayName != null) return displayName!;
    return PortalRole.fromSystemName(role)?.canonicalDisplayName ?? role;
  }

  /// One role row, styled to the Figma dropdown (node 833:2046): the role
  /// name left-aligned, and on the active row a trailing "Primary" tag +
  /// blue check pinned to the right edge.
  PopupMenuItem<String> _roleItem(BuildContext context, String role) {
    final theme = Theme.of(context);
    final isActive = role == systemRole;
    return PopupMenuItem<String>(
      value: role,
      // Figma row is ~36px tall (19.5 line-height + 8px top/bottom pad) —
      // tighter than Material's default 48px interactive minimum.
      height: 36,
      padding: EdgeInsets.zero,
      // Domain-keyed handle per option — the menu item's own node carries
      // the button role, so the identifier needs its own (container) node
      // or the web flattener merges it away.
      child: Semantics(
        identifier: 'role-option-$role',
        container: true,
        explicitChildNodes: true,
        selected: isActive,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _labelFor(role),
                  overflow: TextOverflow.ellipsis,
                  // Inter Medium 13 / 19.5. Active = Black (#04161E),
                  // others = Dark Grey (#54636A).
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 19.5 / 13,
                    letterSpacing: -0.0762,
                    color: isActive
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (isActive)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Primary',
                        // Inter Regular 11 / 16.5, Grey (#A4B9C2 — outline).
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                          height: 16.5 / 11,
                          letterSpacing: 0.0645,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final theme = Theme.of(context);
    // Anchor the menu under the pill, sized to the available roles.
    // Material's showMenu uses RelativeRect from the global overlay, so
    // we translate the pill's global rect into that space.
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final pillBox = context.findRenderObject() as RenderBox?;
    if (pillBox == null) return;
    final topLeft = pillBox.localToGlobal(
      Offset(0, pillBox.size.height + 4),
      ancestor: overlay,
    );
    final bottomRight = pillBox.localToGlobal(
      pillBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final picked = await showMenu<String>(
      context: context,
      // Figma card: white surface, 1px Light Gray (#ECEEF0) hairline,
      // 8px radius, soft drop shadow. surfaceTint off so M3 doesn't tint
      // the white toward primary at this elevation.
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy,
        overlay.size.width - bottomRight.dx,
        overlay.size.height - bottomRight.dy,
      ),
      items: [for (final role in availableRoles) _roleItem(context, role)],
    );
    if (picked != null && picked != systemRole) {
      onRoleSelected!.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Single-role: passive pill, no tap, no caret, no "Role:" prefix.
    if (!_isMultiRole) {
      return RolePill(systemRole: systemRole, displayName: displayName);
    }

    // Multi-role: "Role:" + pill + chevron all sit inside ONE InkWell.
    // The Figma puts the chevron outside the pill, separated by a small
    // gap — keeps the chip looking like a chip and the caret looking
    // like a generic dropdown affordance.
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: -0.15,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      identifier: 'appbar-role-switcher',
      container: true,
      explicitChildNodes: true,
      button: true,
      label: 'Switch role',
      child: InkWell(
        onTap: () => _openMenu(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Role:', style: labelStyle),
              const SizedBox(width: 8),
              // Passive pill — the surrounding InkWell drives the menu;
              // making the pill itself tappable would produce a nested
              // hit-target that double-fires on tap.
              RolePill(systemRole: systemRole, displayName: displayName),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

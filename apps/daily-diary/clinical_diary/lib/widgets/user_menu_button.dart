import 'package:flutter/material.dart';

/// Hamburger user menu shown in the top-right of the brand header across
/// the home, profile, and enrollment screens. Matches the Figma "Menu /
/// Touch target" (node 419:4178):
///
///   * White card, 6px rounded, soft drop shadow.
///   * 18px outer padding on all sides (1.111 bottom per Figma).
///   * "Menu" header followed by a full-width 1.111px `#ECEEF0` separator.
///   * Three rows — **User Profile**, **Join the Study**, **Help Center** —
///     each with an 18×18 Figma-exported glyph and an Inter Regular label
///     (14.875 / 21.25 / -0.2233 / #04161E).
///
/// Each row is gated by its callback: pass `null` to hide the row. The
/// whole menu lives inside a single non-tappable [PopupMenuItem] so we can
/// reach the Figma's outer padding, divider colour, and row gaps exactly
/// (the stock per-item layout can't).
class UserMenuButton extends StatelessWidget {
  const UserMenuButton({
    this.onShowProfile,
    this.onJoinStudy,
    this.onShowHelpCenter,
    super.key,
  });

  /// Null hides the **User Profile** row.
  final VoidCallback? onShowProfile;

  /// Null hides the **Join the Study** row (e.g. already enrolled or
  /// already on the enrollment screen).
  final VoidCallback? onJoinStudy;

  /// Null hides the **Help Center** row.
  final VoidCallback? onShowHelpCenter;

  static const _menuTextColor = Color(0xFF04161E);
  static const _dividerColor = Color(0xFFECEEF0);

  // Figma type ramp (Inter 14.875 / 21.25 / -0.2233).
  static const _titleStyle = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14.875,
    height: 21.25 / 14.875,
    letterSpacing: -0.2233,
    color: _menuTextColor,
  );
  static const _labelStyle = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 14.875,
    height: 21.25 / 14.875,
    letterSpacing: -0.2233,
    color: _menuTextColor,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'user-menu-button',
      button: true,
      container: true,
      explicitChildNodes: true,
      child: PopupMenuButton<void>(
        icon: const Icon(Icons.menu),
        tooltip: 'Menu',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 8),
        color: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        // Figma card width is 317px (top-level frame). Allow a small
        // tolerance so longer locale strings don't clip.
        constraints: const BoxConstraints(minWidth: 250, maxWidth: 250),
        // Trigger button padding — kept Material default for the icon.
        itemBuilder: (context) => [
          PopupMenuItem<void>(
            enabled: false,
            padding: EdgeInsets.zero,
            mouseCursor: SystemMouseCursors.basic,
            child: _MenuCard(
              onShowProfile: onShowProfile,
              onJoinStudy: onJoinStudy,
              onShowHelpCenter: onShowHelpCenter,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.onShowProfile,
    required this.onJoinStudy,
    required this.onShowHelpCenter,
  });

  final VoidCallback? onShowProfile;
  final VoidCallback? onJoinStudy;
  final VoidCallback? onShowHelpCenter;

  @override
  Widget build(BuildContext context) {
    final rows = <_MenuRowSpec>[
      if (onShowProfile != null)
        _MenuRowSpec(
          icon: _MenuIcons.userProfile,
          label: 'User Profile',
          semanticId: 'menu-profile',
          onTap: onShowProfile!,
        ),
      if (onJoinStudy != null)
        _MenuRowSpec(
          icon: _MenuIcons.joinStudy,
          label: 'Join the Study',
          semanticId: 'menu-enroll',
          onTap: onJoinStudy!,
        ),
      if (onShowHelpCenter != null)
        _MenuRowSpec(
          icon: _MenuIcons.helpCenter,
          label: 'Help Center',
          semanticId: 'menu-help',
          onTap: onShowHelpCenter!,
        ),
    ];

    return Padding(
      // Figma outer padding (top 18 / sides 18 / bottom 1.111).
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 1.111),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "Menu" header — 30px tall row, 8.5px horizontal padding.
          const SizedBox(
            height: 30,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.5, 4.5, 8.5, 0),
              child: Text('Menu', style: UserMenuButton._titleStyle),
            ),
          ),
          // Figma gap between header and divider.
          const SizedBox(height: 8.231),
          // Full-width 1.111px separator under the header (Figma's
          // border-top on the rows container, rendered explicitly).
          Container(height: 1.111, color: UserMenuButton._dividerColor),
          // Figma top-padding inside the rows container.
          const SizedBox(height: 9.835),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 4.465),
            _MenuRow(spec: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _MenuRowSpec {
  const _MenuRowSpec({
    required this.icon,
    required this.label,
    required this.semanticId,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String semanticId;
  final VoidCallback onTap;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.spec});
  final _MenuRowSpec spec;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          // Close the popup first, then run the caller's callback so any
          // navigation the callback performs starts from the host route.
          Navigator.of(context).pop();
          spec.onTap();
        },
        child: Semantics(
          identifier: spec.semanticId,
          button: true,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                children: [
                  Image.asset(spec.icon, width: 18, height: 18),
                  const SizedBox(width: 8),
                  Text(spec.label, style: UserMenuButton._labelStyle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract class _MenuIcons {
  static const _base = 'assets/icons/figma/menu';
  static const userProfile = '$_base/user_profile.png';
  static const joinStudy = '$_base/join_study.png';
  static const helpCenter = '$_base/help_center.png';
}

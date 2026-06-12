import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:portal_screens/portal_screens.dart';

import 'auth_scaffold.dart';
import 'role_selector.dart';

/// Post-login, pre-dashboard step shown only when the authenticated user holds
/// more than one role (see [roleSelectorVisible]). Lets the user pick the role
/// to start the session in; the choice is forwarded to [onRoleSelected], which
/// encodes the `credential|role` claim and reconnects the WS.
///
/// Consumer-owned styled UI composed from `diary_design_system` — the same
/// rendered-sugar-in-the-app principle the reaction widget contract mandates.
// Implements: DIARY-GUI-role-switching/A+B+C+D
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({
    super.key,
    required this.userName,
    required this.roles,
    required this.activeRole,
    required this.onRoleSelected,
    required this.onBackToLogin,
  });

  final String userName;
  final Set<String> roles;
  final String activeRole;

  /// Called with the chosen role; the parent updates the credential claim and
  /// reconnects. May take a moment (a WS reconnect), so the tapped card shows a
  /// spinner until it completes.
  final Future<void> Function(String role) onRoleSelected;

  /// Logs the user out and returns to the login screen.
  final VoidCallback onBackToLogin;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selecting;

  Future<void> _choose(String role) async {
    if (_selecting != null) return;
    setState(() => _selecting = role);
    try {
      await widget.onRoleSelected(role);
    } finally {
      if (mounted) setState(() => _selecting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = roleMenuItems(
      roles: widget.roles,
      activeRole: widget.activeRole,
    );
    return AuthScaffold(
      semanticId: 'role-selection-screen',
      title: 'Welcome, ${widget.userName}',
      subtitle: 'Select a role to continue',
      banner: AppBanner(
        severity: AppBannerSeverity.info,
        message:
            'You can switch roles at any time using the role dropdown in the '
            'top bar.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items) ...[
            _RoleCard(
              role: item.role,
              loading: _selecting == item.role,
              enabled: _selecting == null,
              onTap: () => _choose(item.role),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          AuthLinkButton(
            label: 'Back to Login',
            onPressed: _selecting == null ? widget.onBackToLogin : null,
            semanticId: 'back-to-login',
          ),
        ],
      ),
    );
  }
}

/// Product copy + icon per role, keyed by the backend system name. Display
/// name + tone come from the [PortalRole] catalog (single source); the
/// description and glyph are role-selection-specific presentation.
({String description, IconData icon}) _roleMeta(String systemName) {
  return switch (systemName) {
    'Administrator' => (
      description: 'User management and portal administration',
      icon: Icons.shield_outlined,
    ),
    'CRA' => (
      description: 'Audit trails and compliance review',
      icon: Icons.fact_check_outlined,
    ),
    'StudyCoordinator' => (
      description: 'Participant management and questionnaire workflows',
      icon: Icons.groups_outlined,
    ),
    'SystemOperator' => (
      description: 'System-level lifecycle and operations',
      icon: Icons.settings_outlined,
    ),
    _ => (description: 'Portal access', icon: Icons.badge_outlined),
  };
}

/// Resolves a role's [AppBadgeTone] to an (icon-accent, tile-background) pair,
/// mirroring [AppBadge]'s tinted-variant color logic so the role tiles match
/// the role pills elsewhere in the portal.
(Color accent, Color background) _toneColors(
  BuildContext context,
  AppBadgeTone tone,
) {
  final theme = Theme.of(context);
  final semantic = theme.extension<AppSemanticColors>()!;
  return switch (tone) {
    AppBadgeTone.neutral => (
      theme.colorScheme.onSurfaceVariant,
      theme.colorScheme.surfaceContainerHighest,
    ),
    AppBadgeTone.primary => (
      theme.colorScheme.primary,
      theme.colorScheme.primaryContainer,
    ),
    AppBadgeTone.danger => (
      theme.colorScheme.error,
      theme.colorScheme.errorContainer,
    ),
    AppBadgeTone.warning => (semantic.warning, semantic.warningContainer),
    AppBadgeTone.success => (semantic.success, semantic.successContainer),
  };
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final String role;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = PortalRole.fromSystemName(role);
    final displayName = catalog?.canonicalDisplayName ?? role;
    final tone = catalog?.tone ?? AppBadgeTone.neutral;
    final meta = _roleMeta(role);
    final (accent, tileBg) = _toneColors(context, tone);

    return Semantics(
      identifier: 'role-${role.toLowerCase()}',
      button: true,
      label: displayName,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(meta.icon, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

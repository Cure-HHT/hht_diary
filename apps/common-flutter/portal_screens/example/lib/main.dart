// Live preview for portal_screens widgets.
//
// Run with:
//
//   cd apps/common-flutter/portal_screens/example
//   flutter pub get
//   flutter run -d chrome
//
// Renders every visual variant of PortalAppBar (and, as later phases land,
// UsersScreen / AuditLogsScreen) stacked vertically on one route. Every
// callback is wired to a SnackBar so you can confirm taps fire without
// spinning up portal_ui_evs's reactive layer.

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:portal_screens/portal_screens.dart';

void main() => runApp(const PortalScreensPreviewApp());

class PortalScreensPreviewApp extends StatelessWidget {
  const PortalScreensPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'portal_screens preview',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(
      font: AppFontFamily.inter,
      brightness: Brightness.light,
    ),
    home: const _PreviewHome(),
  );
}

class _PreviewHome extends StatelessWidget {
  const _PreviewHome();

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intro = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      body: SingleChildScrollView(
        // Vertical-only padding here so the AppBars themselves can stretch
        // edge-to-edge like they will in the real app. Per-section captions
        // get their own horizontal padding below.
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Caption('PortalAppBar — variants', isHeading: true),
            const SizedBox(height: 16),

            // 1. Admin multi-role — canonical Figma variant.
            const _Caption(
              '1. Admin multi-role (canonical, Figma image 1). '
              'Role: prefix + dropdown caret. Help icon shown.',
            ),
            const SizedBox(height: 8),
            PortalAppBar(
              title: 'Clinical Trial Portal',
              subtitle: 'Administrator Dashboard',
              horizontalPadding: 96,
              userName: 'Dr. Emily Parker',
              activeRole: 'Administrator',
              availableRoles: const [
                'Administrator',
                'StudyCoordinator',
                'CRA',
              ],
              onRoleSelected: (role) =>
                  _snack(context, 'Role switched to: $role'),
              onLogout: () => _snack(context, 'Logout fired (Admin)'),
              onHelp: () => _snack(context, 'Help tapped'),
            ),
            const SizedBox(height: 40),

            // 2. Single-role Study Coordinator with a sponsor-mapped label.
            const _Caption(
              '2. Single-role Study Coordinator (Figma image 2). '
              'Sponsor maps StudyCoordinator → "Site Study Coordinator". '
              'No "Role:" prefix, no caret. No help icon.',
            ),
            const SizedBox(height: 8),
            PortalAppBar(
              title: 'Clinical Trial Portal',
              subtitle: 'Site Study Coordinator Dashboard',
              userName: 'Dr. Sarah Johnson',
              activeRole: 'StudyCoordinator',
              activeRoleDisplayName: 'Site Study Coordinator',

              availableRoles: const ['StudyCoordinator'],
              onLogout: () => _snack(context, 'Logout fired (Coordinator)'),
            ),
            const SizedBox(height: 40),

            // 3. Multi-role CRA — Figma image 3 shape (caret + canonical label).
            const _Caption(
              '3. Multi-role CRA (Figma image 3). Same shape as the '
              'Admin variant but neutral tone, no sponsor-mapped name.',
            ),
            const SizedBox(height: 8),
            PortalAppBar(
              title: 'Clinical Trial Portal',
              subtitle: 'CRA Dashboard',
              userName: 'Jennifer Martinez',
              activeRole: 'CRA',
              availableRoles: const ['CRA', 'StudyCoordinator'],
              onRoleSelected: (role) =>
                  _snack(context, 'Role switched to: $role'),
              onLogout: () => _snack(context, 'Logout fired (CRA)'),
            ),
            const SizedBox(height: 40),

            // 4. Unknown role — exercises the catalog fallback. Renders the
            //    raw backend string with neutral tone instead of blanking,
            //    so a projection drift between server and client is visible.
            const _Caption(
              '4. Unknown role (catalog fallback). Backend sends '
              '"NewBetaRole"; widget renders it as a neutral pill '
              "rather than blanking — projection drift is surfaced.",
            ),
            const SizedBox(height: 8),
            PortalAppBar(
              title: 'Clinical Trial Portal',
              subtitle: 'NewBetaRole Dashboard',
              userName: 'Beta Tester',
              activeRole: 'NewBetaRole',
              availableRoles: const ['NewBetaRole'],
              onLogout: () => _snack(context, 'Logout fired (beta)'),
            ),

            const SizedBox(height: 40),
            const _Caption('Notes', isHeading: true),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Hot-reload edits to portal_screens (lib/src/widgets/*.dart) '
                'reflect immediately. Use the role-switcher dropdowns + '
                'Logout buttons to drive the callbacks — each shows a '
                'SnackBar.',
                style: intro,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caption / heading text rendered with consistent horizontal page
/// padding. Kept separate from the AppBar rows so the bars can stretch
/// edge-to-edge while the explanatory copy stays at a readable indent.
class _Caption extends StatelessWidget {
  const _Caption(this.text, {this.isHeading = false});

  final String text;
  final bool isHeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        text,
        style: isHeading
            ? const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                height: 24 / 18,
              )
            : theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

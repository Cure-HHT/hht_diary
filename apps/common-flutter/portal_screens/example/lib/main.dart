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
              title: 'Sponsor Portal',
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
              title: 'Sponsor Portal',
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
              title: 'Sponsor Portal',
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
              title: 'Sponsor Portal',
              subtitle: 'NewBetaRole Dashboard',
              userName: 'Beta Tester',
              activeRole: 'NewBetaRole',
              availableRoles: const ['NewBetaRole'],
              onLogout: () => _snack(context, 'Logout fired (beta)'),
            ),

            const SizedBox(height: 64),
            const _Caption('PortalDashboard — top-tab shell', isHeading: true),
            const SizedBox(height: 16),
            const _Caption(
              '5-tab dashboard with PortalAppBar on top and a pill tab '
              'strip beneath. Each destination renders a placeholder '
              'body for now — Users + Audit Logs become real screens in '
              'Phases 5 + 6. The 3 unredesigned tabs (Sites, Participants, '
              'RAVE Sync) stay as their current widgets once integrated '
              'in Phase 9.',
            ),
            const SizedBox(height: 8),
            // Inline preview: nest a sized Scaffold-bearing widget inside
            // the outer scroll. Nesting is a Flutter anti-pattern in real
            // routes but is fine for a static preview block. Phase 9 will
            // mount this dashboard as a real route in portal_ui_evs.
            SizedBox(
              // Tall enough for the default 8-row UsersScreen to render
              // without internal scrolling — matches the canonical
              // desktop layout where the dashboard is full-window.
              height: 960,
              child: PortalDashboard(
                appBar: PortalAppBar(
                  title: 'Sponsor Portal',
                  subtitle: 'Administrator Dashboard',
                  userName: 'Dr. Emily Parker',
                  activeRole: 'Administrator',
                  availableRoles: const [
                    'Administrator',
                    'StudyCoordinator',
                    'CRA',
                  ],
                  onRoleSelected: (role) =>
                      _snack(context, 'Role switched to: $role'),
                  onLogout: () => _snack(context, 'Logout fired'),
                  onHelp: () => _snack(context, 'Help tapped'),
                ),
                destinations: [
                  DashboardDestination(
                    key: 'users',
                    label: 'Users',
                    body: (ctx) => UsersScreen(
                      users: MockData.users,
                      isLoading: false,
                      canCreate: true,
                      onCreate: () => _snack(ctx, 'Create User tapped'),
                    ),
                  ),
                  DashboardDestination(
                    key: 'audit',
                    label: 'Audit Logs',
                    body: (ctx) =>
                        _AuditLogsPreview(onSnack: (m) => _snack(ctx, m)),
                  ),
                  DashboardDestination(
                    key: 'sites',
                    label: 'Sites',
                    body: (_) => const _Placeholder(
                      label:
                          'SitesScreen (untouched, '
                          'wired in Phase 9)',
                    ),
                  ),
                  DashboardDestination(
                    key: 'participants',
                    label: 'Participants',
                    body: (_) => const _Placeholder(
                      label:
                          'ParticipantsScreen (untouched, '
                          'wired in Phase 9)',
                    ),
                  ),
                  DashboardDestination(
                    key: 'rave',
                    label: 'RAVE Sync',
                    body: (_) => const _Placeholder(
                      label:
                          'RaveSyncScreen (untouched, '
                          'wired in Phase 9)',
                    ),
                  ),
                ],
              ),
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
                'SnackBar. Tab pills swap the dashboard body inline.',
                style: intro,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder body for the dashboard destinations — flat-coloured
/// panel with a centred caption. Real screens land in Phases 5 + 6;
/// the un-redesigned destinations (Sites / Participants / RAVE Sync)
/// pass through their existing portal_ui_evs widgets in Phase 9.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(48, 16, 48, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
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

/// Mimics the server-paged contract portal_ui_evs's binding fulfils in
/// production: slices the mock entries per page/search locally and feeds
/// [AuditLogsScreen] the current page plus the true total, so the preview
/// exercises the pagination + search callbacks end-to-end.
class _AuditLogsPreview extends StatefulWidget {
  const _AuditLogsPreview({required this.onSnack});

  final ValueChanged<String> onSnack;

  @override
  State<_AuditLogsPreview> createState() => _AuditLogsPreviewState();
}

class _AuditLogsPreviewState extends State<_AuditLogsPreview> {
  int _page = 1;
  int _pageSize = 8;
  String _query = '';

  List<AuditEntryView> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return MockData.auditEntries;
    return MockData.auditEntries
        .where(
          (e) =>
              e.actorName.toLowerCase().contains(q) ||
              e.activityLabel.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final start = (_page - 1) * _pageSize;
    final pageRows = start >= matches.length
        ? const <AuditEntryView>[]
        : matches.sublist(start, (start + _pageSize).clamp(0, matches.length));
    return AuditLogsScreen(
      entries: pageRows,
      isLoading: false,
      onRefresh: () => widget.onSnack('Refresh fired'),
      page: _page,
      pageSize: _pageSize,
      totalCount: matches.length,
      searchQuery: _query,
      onPageChanged: (p) => setState(() => _page = p),
      onPageSizeChanged: (s) => setState(() {
        _pageSize = s;
        _page = 1;
      }),
      onSearchChanged: (q) => setState(() {
        _query = q;
        _page = 1;
      }),
    );
  }
}

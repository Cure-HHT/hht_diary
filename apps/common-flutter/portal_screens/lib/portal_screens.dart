/// Composed portal admin/operator screens.
///
/// Pure presentation layer over [diary_design_system]. The wiring layer
/// (`portal_ui_evs`) subscribes to event-sourced projections and dispatches
/// actions; widgets here render snapshots + emit callbacks. See
/// `docs/superpowers/specs/portal-ui-evs-redesign-plan.md` for the rollout.
library;

// Phase 2: value types.
export 'src/models/audit_entry_view.dart';
export 'src/models/portal_role.dart';
export 'src/models/portal_user_view.dart';
export 'src/models/role_assignment_view.dart';
export 'src/models/user_status_view.dart';

// Phase 3: portal-wide reusable widgets.
export 'src/widgets/portal_app_bar.dart';
export 'src/widgets/role_pill.dart';

// Phase 4: top-tab dashboard shell.
export 'src/widgets/dashboard_tabs.dart';
export 'src/widgets/portal_dashboard.dart';

/// Composed portal admin/operator screens.
///
/// Pure presentation layer over [diary_design_system]. The wiring layer
/// (`portal_ui_evs`) subscribes to event-sourced projections and dispatches
/// actions; widgets here render snapshots + emit callbacks. See
/// `docs/superpowers/specs/portal-ui-evs-redesign-plan.md` for the rollout.
library;

// Phase 2: value types.
export 'src/models/audit_entry_view.dart';
export 'src/models/participant_row_view.dart';
export 'src/models/portal_role.dart';
export 'src/models/rave_sync_view.dart';
export 'src/models/portal_user_view.dart';
export 'src/models/role_assignment_view.dart';
export 'src/models/site_option_view.dart';
export 'src/models/user_status_view.dart';

// Phase 3: portal-wide reusable widgets.
export 'src/widgets/portal_app_bar.dart';
export 'src/widgets/role_pill.dart';

// Phase 4: top-tab dashboard shell.
export 'src/widgets/dashboard_tabs.dart';
export 'src/widgets/portal_dashboard.dart';

// Phase 5: admin screens.
export 'src/admin/users_screen.dart';
// Phase 7: row actions + user lifecycle dialogs.
export 'src/admin/user_details_dialog.dart';
export 'src/admin/user_form_dialog.dart';
export 'src/admin/user_lifecycle_dialogs.dart';
export 'src/admin/user_row_actions.dart';
// Phase 6: audit logs screen.
export 'src/admin/audit_logs_screen.dart';
export 'src/admin/sc_audit_log_screen.dart';
export 'src/admin/participants_screen.dart';
export 'src/admin/rave_sync_screen.dart';
export 'src/admin/sites_screen.dart';
export 'src/admin/study_settings_screen.dart';
// Fixture data — used by the example preview app and the test suite.
// Public so consumers can import the canonical sample users / audit
// entries without forking the fixture file.
export 'src/fixtures/mock_data.dart';

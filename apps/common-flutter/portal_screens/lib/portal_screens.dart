/// Composed portal admin/operator screens.
///
/// Pure presentation layer over [diary_design_system]. The wiring layer
/// (`portal_ui_evs`) subscribes to event-sourced projections and dispatches
/// actions; widgets here render snapshots + emit callbacks. See
/// `docs/superpowers/specs/portal-ui-evs-redesign-plan.md` for the rollout.
///
/// Exports land here as each phase completes — see the plan for ordering.
library;

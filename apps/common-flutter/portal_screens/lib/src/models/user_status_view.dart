/// Lifecycle state of a portal user, as surfaced to the UI.
///
/// Mirrors the `portal_users.status` set in the backend, but kept as a plain
/// Dart enum so the presentation layer has no dependency on the event-sourcing
/// projection types. The wiring layer (`portal_ui_evs`) maps from the raw
/// `users_index` row string into this enum.
///
/// Filter chips in the Users screen group these as follows (see the redesign
/// plan §5 Phase 5):
///
/// | Tab        | Members                              |
/// | ---------- | ------------------------------------ |
/// | All users  | all                                  |
/// | Active     | [active]                             |
/// | Pending    | [pending]                            |
/// | Inactive   | [revoked]                            |
/// | (omitted)  | [locked], [unknown]                  |
///
/// `locked` and `unknown` count toward "All users" but don't surface under any
/// per-status chip. This mirrors the legacy portal-ui behaviour. If product
/// later wants explicit visibility, fold them into Inactive (see Risks).
enum UserStatusView {
  /// User exists in the directory but hasn't activated their account yet.
  pending,

  /// User has activated and is fully usable.
  active,

  /// User has been deactivated. Recoverable via "Reactivate".
  revoked,

  /// Account has been locked (e.g. too many failed auth attempts).
  locked,

  /// Status string from the row couldn't be mapped to any known value.
  /// Surfaced so an unrecognised projection state can't crash the UI.
  unknown,
}

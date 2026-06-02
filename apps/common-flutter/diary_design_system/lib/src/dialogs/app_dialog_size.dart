/// Fixed-width tiers for [AppDialog].
///
/// Pulled from the Figma "Dialog Patterns" frame: 440 / 600 / 720 px.
/// At narrow viewports the dialog gracefully shrinks below these widths via
/// `ConstrainedBox(maxWidth: …)` — the value is a maximum, not a fixed size.
enum AppDialogSize {
  /// 440 px — acknowledgment, simple confirmation.
  small(440),

  /// 600 px — reason dialog, predefined list, short forms.
  medium(600),

  /// 720 px — complex forms (Side User, Finalize Questionnaire).
  large(720);

  const AppDialogSize(this.width);
  final double width;
}

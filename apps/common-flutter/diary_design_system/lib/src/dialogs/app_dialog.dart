import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buttons/app_button.dart';
import '../feedback/app_banner.dart';
import '../inputs/app_dropdown.dart';
import '../inputs/app_text_field.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'app_dialog_size.dart';

/// The design system dialog skeleton.
///
/// One widget renders all dialog patterns from the Figma UI Kit. The fixed-
/// width tiers come from [AppDialogSize]. Opinionated variants are exposed as
/// static factory methods ([confirmation], [acknowledgment], [destructive])
/// that wrap `showDialog<T>` and return the typed result.
///
/// Layout: optional icon + title + optional subtitle in the header, a body
/// area for whatever the caller wants, and a trailing-aligned actions row.
///
/// **Async dialogs.** The design system intentionally does not ship a
/// confirm/loading/result state machine — callers compose [AppDialog]
/// with whatever async primitive their app already uses. In the reactive
/// portal (`portal_ui_evs/`) that's `ActionBuilder` from
/// `package:reaction_widgets`, which mints a UUID-v4 idempotency key
/// once per dialog and reuses it across retries:
///
/// ```dart
/// showDialog<DisconnectResult>(
///   context: context,
///   builder: (ctx) => ActionBuilder(
///     submissionFactory: () => ActionSubmission(
///       actionName: 'disconnect_participant',
///       rawInput: {'patientId': patientId},
///     ),
///     builder: (ctx, state, submit) => AppDialog(
///       title: 'Disconnect participant',
///       body: ...,
///       actions: [
///         AppButton(
///           variant: AppButtonVariant.secondary,
///           label: 'Cancel',
///           onPressed: state is Submitting ? null : () => Navigator.pop(ctx),
///         ),
///         AppButton(
///           variant: AppButtonVariant.destructive,
///           label: 'Disconnect',
///           loading: state is Submitting,
///           onPressed: state is Submitting ? null : submit,
///         ),
///       ],
///     ),
///   ),
/// );
/// ```
///
/// `AppButton(loading: state is Submitting, onPressed: submit)` maps onto
/// `ActionBuilder`'s `(state, submit)` 1:1.

class AppDialog extends StatelessWidget {
  final AppDialogSize size;
  final Widget? icon;
  final String title;
  final String? subtitle;

  /// Optional slot rendered above the title inside the header (Figma:
  /// the "\u2190 User Details" back-link on the user flow dialogs).
  final Widget? breadcrumb;
  final Widget body;
  final List<Widget> actions;

  /// Optional override for the whole dialog surface (Figma: the Manage
  /// Questionnaires modal is a soft grey panel that its white question cards
  /// sit on). Null (default) keeps `colorScheme.surface` so every existing
  /// dialog is unchanged.
  final Color? backgroundColor;

  /// Retained for API compatibility. Per the Figma UI Kit every dialog
  /// pattern now renders the top-right close (X) button unconditionally, so
  /// this flag no longer hides it. Barrier-dismiss behavior is still
  /// controlled by the caller's `showDialog(barrierDismissible:)`.
  final bool dismissible;

  /// Test-harness locator. When set, wraps the dialog in a
  /// `Semantics(identifier: ..., namesRoute: true, container: true, explicitChildNodes: true)`
  /// node so Playwright can scope queries inside the dialog subtree.
  final String? semanticId;

  const AppDialog({
    super.key,
    this.size = AppDialogSize.medium,
    this.icon,
    required this.title,
    this.subtitle,
    this.breadcrumb,
    required this.body,
    this.actions = const [],
    this.dismissible = true,
    this.semanticId,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(
      RadiusTokens.md,
    ); // Figma: dialog corner radius 8

    final dialog = Dialog(
      // Transparent so Material doesn't paint its own surface-tint /
      // elevation shadow on top of the explicit BoxShadow below.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.xxl,
        vertical: SpacingTokens.xxxl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size.width),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.colorScheme.surface,
            borderRadius: borderRadius,
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
            ), // Figma: 1px hairline border
            // Figma drop shadow: x=5, y=10, blur=20, spread=-3, color
            // #364153 at 10% alpha. Single-layer (no ambient stack).
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A364153),
                offset: Offset(5, 10),
                blurRadius: 20,
                spreadRadius: -3,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  breadcrumb: breadcrumb,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    // Bottom inset gives the Figma gap between body and the
                    // footer divider; horizontal inset matches header/footer.
                    padding: EdgeInsets.fromLTRB(
                      SpacingTokens.xxl,
                      0,
                      SpacingTokens.xxl,
                      SpacingTokens.xxl,
                    ),
                    child: body,
                  ),
                ),
                if (actions.isNotEmpty) _Footer(actions: actions),
              ],
            ),
          ),
        ),
      ),
    );

    if (semanticId == null) return dialog;

    return Semantics(
      identifier: semanticId,
      namesRoute: true,
      container: true,
      explicitChildNodes: true,
      child: dialog,
    );
  }

  // ---------------------------------------------------------------------------
  // Named static factory methods — opinionated dialog patterns.
  // ---------------------------------------------------------------------------

  /// A yes/no confirmation. Returns `true` if confirmed, `false` otherwise
  /// (including barrier dismiss).
  ///
  /// Default size is small. Barrier dismiss is disabled — the caller must
  /// explicitly cancel or confirm.
  static Future<bool> confirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    AppDialogSize size = AppDialogSize.small,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppDialog(
        size: size,
        dismissible: false,
        title: title,
        body: Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          AppButton(
            variant: AppButtonVariant.secondary,
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            variant: AppButtonVariant.primary,
            label: confirmLabel,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// An "OK" acknowledgment dialog. Returns when dismissed.
  ///
  /// Barrier dismiss is enabled because there's nothing to choose — the user
  /// is just being informed.
  static Future<void> acknowledgment({
    required BuildContext context,
    required String title,
    required String message,
    String okLabel = 'OK',
    AppDialogSize size = AppDialogSize.small,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AppDialog(
        size: size,
        title: title,
        body: Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          AppButton(
            variant: AppButtonVariant.primary,
            label: okLabel,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  /// Prompts for a reason. Returns the entered/selected string, or `null` if
  /// the user cancelled.
  ///
  /// Pass [reasons] for the predefined-list (dropdown) variant; omit it for
  /// the free-text variant. The submit button stays disabled until the user
  /// has selected an option or entered non-empty text.
  static Future<String?> reason({
    required BuildContext context,
    required String title,
    String? message,
    List<AppDropdownItem<String>>? reasons,
    String submitLabel = 'Submit',
    String cancelLabel = 'Cancel',
    String reasonLabel = 'Reason',
    String hintText = 'Enter reason',
    bool requiredField = true,
    AppDialogSize size = AppDialogSize.medium,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReasonDialog(
        title: title,
        message: message,
        reasons: reasons,
        submitLabel: submitLabel,
        cancelLabel: cancelLabel,
        reasonLabel: reasonLabel,
        hintText: hintText,
        requiredField: requiredField,
        size: size,
      ),
    );
  }

  /// A destructive confirmation — same shape as [confirmation] but uses an
  /// [AppButtonVariant.destructive] confirm button and shows an
  /// [AppBannerSeverity.warning] banner explaining the consequences.
  ///
  /// Returns `true` if the user confirmed, `false` otherwise.
  static Future<bool> destructive({
    required BuildContext context,
    required String title,
    required String message,
    required String warningMessage,
    String? warningTitle,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    AppDialogSize size = AppDialogSize.small,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AppDialog(
          size: size,
          dismissible: false,
          title: title,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: theme.textTheme.bodyMedium),
              SizedBox(height: SpacingTokens.lg),
              AppBanner(
                severity: AppBannerSeverity.warning,
                title: warningTitle,
                message: warningMessage,
              ),
            ],
          ),
          actions: [
            AppButton(
              variant: AppButtonVariant.secondary,
              label: cancelLabel,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            AppButton(
              variant: AppButtonVariant.destructive,
              label: confirmLabel,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String? message;
  final List<AppDropdownItem<String>>? reasons;
  final String submitLabel;
  final String cancelLabel;
  final String reasonLabel;
  final String hintText;
  final bool requiredField;
  final AppDialogSize size;

  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.reasons,
    required this.submitLabel,
    required this.cancelLabel,
    required this.reasonLabel,
    required this.hintText,
    required this.requiredField,
    required this.size,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  String? _selected;
  String _text = '';

  bool get _isDropdown => widget.reasons != null;
  bool get _canSubmit =>
      _isDropdown ? _selected != null : _text.trim().isNotEmpty;

  void _submit() {
    final value = _isDropdown ? _selected! : _text.trim();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppDialog(
      size: widget.size,
      dismissible: false,
      title: widget.title,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!, style: theme.textTheme.bodyMedium),
            SizedBox(height: SpacingTokens.lg),
          ],
          if (_isDropdown)
            AppDropdown<String>(
              label: widget.reasonLabel,
              required: widget.requiredField,
              hintText: widget.hintText,
              value: _selected,
              items: widget.reasons!,
              onChanged: (v) => setState(() => _selected = v),
            )
          else
            // Implements: DIARY-PRD-reason-field-constraints/A+B —
            // submit stays disabled for whitespace-only input and the
            // free-text reason is capped at 100 characters platform-wide.
            AppTextField(
              label: widget.reasonLabel,
              required: widget.requiredField,
              hintText: widget.hintText,
              maxLines: 3,
              minLines: 1,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              onChanged: (v) => setState(() => _text = v),
            ),
        ],
      ),
      actions: [
        AppButton(
          variant: AppButtonVariant.secondary,
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: widget.submitLabel,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String? subtitle;
  final Widget? breadcrumb;

  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.xxl,
        SpacingTokens.xxl,
        SpacingTokens.lg,
        SpacingTokens.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(color: theme.colorScheme.primary, size: 24),
              child: icon!,
            ),
            SizedBox(width: SpacingTokens.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (breadcrumb != null) ...[
                  breadcrumb!,
                  SizedBox(height: SpacingTokens.xs),
                ],
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null) ...[
                  SizedBox(height: SpacingTokens.xxs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Figma: every dialog pattern carries a light close (X) affordance
          // in the top-right that pops the route with null.
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 20,
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final List<Widget> actions;
  const _Footer({required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Figma: hairline divider separating the body from the actions row,
        // inset to the dialog's horizontal content padding.
        Divider(
          height: 1,
          thickness: 1,
          indent: SpacingTokens.xxl,
          endIndent: SpacingTokens.xxl,
          color: theme.colorScheme.outlineVariant,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.xxl,
            SpacingTokens.lg,
            SpacingTokens.xxl,
            SpacingTokens.xxl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(width: SpacingTokens.md),
                actions[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

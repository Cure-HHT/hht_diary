import 'package:flutter/material.dart';

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
  final Widget body;
  final List<Widget> actions;

  /// When true, the dialog renders a close (X) button in the top-right
  /// corner that pops the route with `null`. The barrier-dismiss behavior is
  /// controlled separately by the caller's `showDialog(barrierDismissible:)`.
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
    required this.body,
    this.actions = const [],
    this.dismissible = true,
    this.semanticId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(RadiusTokens.lg);

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
            color: theme.colorScheme.surface,
            borderRadius: borderRadius,
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
                  dismissible: dismissible,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: SpacingTokens.xxl,
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
            AppTextField(
              label: widget.reasonLabel,
              required: widget.requiredField,
              hintText: widget.hintText,
              maxLines: 3,
              minLines: 1,
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
  final bool dismissible;

  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.dismissible,
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
          if (dismissible)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
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
    return Padding(
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
    );
  }
}

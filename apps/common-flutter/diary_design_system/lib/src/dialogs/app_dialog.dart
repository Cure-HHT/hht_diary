import 'package:flutter/material.dart';

import '../buttons/app_button.dart';
import '../feedback/app_banner.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'app_dialog_size.dart';
import 'async_action_dialog.dart';

/// The design system dialog skeleton.
///
/// One widget renders all dialog patterns from the Figma UI Kit. The fixed-
/// width tiers come from [AppDialogSize]. Opinionated variants are exposed as
/// static factory methods ([confirmation], [acknowledgment], [destructive])
/// that wrap `showDialog<T>` and return the typed result.
///
/// Layout: optional icon + title + optional subtitle in the header, a body
/// area for whatever the caller wants, and a trailing-aligned actions row.
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

  const AppDialog({
    super.key,
    this.size = AppDialogSize.medium,
    this.icon,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions = const [],
    this.dismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(RadiusTokens.lg);

    return Dialog(
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

  /// An async workflow dialog — wraps [AsyncActionDialog] in `showDialog` so a
  /// single call site gets the modal + state machine + typed result.
  ///
  /// Returns the value the success builder pops with (typically the
  /// [onSubmit] result), or `null` if the dialog is dismissed without
  /// completing the success phase. Barrier dismiss defaults to disabled so an
  /// accidental backdrop tap doesn't kill an in-flight request.
  ///
  /// See [AsyncActionDialog] for the per-builder responsibilities.
  static Future<T?> async<T>({
    required BuildContext context,
    required Future<T> Function() onSubmit,
    required Widget Function(BuildContext context, VoidCallback submit)
    confirmBuilder,
    required Widget Function(BuildContext context, T result) successBuilder,
    required Widget Function(
      BuildContext context,
      Object error,
      VoidCallback retry,
    )
    errorBuilder,
    Widget Function(BuildContext context)? loadingBuilder,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AsyncActionDialog<T>(
        onSubmit: onSubmit,
        confirmBuilder: confirmBuilder,
        successBuilder: successBuilder,
        errorBuilder: errorBuilder,
        loadingBuilder: loadingBuilder,
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

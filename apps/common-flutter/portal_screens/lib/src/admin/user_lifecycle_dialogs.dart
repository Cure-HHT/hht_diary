import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

/// "← User Information" back-link rendered above a flow dialog's title when
/// the dialog was launched from the User Information modal. Pops the dialog
/// and invokes [onBack] (the wiring layer reopens the details modal).
class UserFlowBackLink extends StatelessWidget {
  const UserFlowBackLink({
    super.key,
    required this.onBack,
    this.enabled = true,
  });

  final VoidCallback onBack;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: enabled
            ? () {
                Navigator.of(context).pop();
                onBack();
              }
            : null,
        child: Text(
          '← User Information',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

/// Deactivate User Account dialog (Figma: User Details / Deactivate
/// User Account).
///
/// Red "Effects of this action" panel, a required reason field (100-char
/// counter), and Confirm. [onSubmit] receives the trimmed reason and
/// resolves to `null` on success or a user-facing error message.
// Implements: DIARY-GUI-user-account-deactivate/B+C+D
// Implements: DIARY-PRD-user-account-deactivate/F
class DeactivateUserDialog extends StatelessWidget {
  const DeactivateUserDialog({
    super.key,
    required this.userName,
    required this.onSubmit,
    this.onBack,
  });

  final String userName;
  final Future<String?> Function(String reason) onSubmit;

  /// Invoked after the dialog pops itself via the "← User Details"
  /// back-link; null hides the link (e.g. when launched from the kebab).
  final VoidCallback? onBack;

  static Future<bool?> show(
    BuildContext context, {
    required String userName,
    required Future<String?> Function(String reason) onSubmit,
    VoidCallback? onBack,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DeactivateUserDialog(
      userName: userName,
      onSubmit: onSubmit,
      onBack: onBack,
    ),
  );

  @override
  Widget build(BuildContext context) => _LifecycleConfirmDialog(
    title: 'Deactivate User Account',
    semanticId: 'deactivate-user-dialog',
    message:
        'You are about to deactivate the account for "$userName". '
        'This action can be reversed by reactivating the user.',
    effectsSeverity: AppBannerSeverity.error,
    effectsIcon: Icons.block_outlined,
    effects: const [
      'Terminate all active sessions immediately',
      'Prevent the user from logging in',
      'Move the user to the Inactive tab',
    ],
    reasonLabel: 'Reason for deactivation',
    reasonHint: 'Enter reason for deactivating this User',
    onBack: onBack,
    onSubmit: onSubmit,
  );
}

/// Reactivate User Account dialog (Figma: User Details / Reactivate
/// User Account).
// Implements: DIARY-GUI-user-account-reactivate/B+C+D
// Implements: DIARY-PRD-user-account-reactivate/D
class ReactivateUserDialog extends StatelessWidget {
  const ReactivateUserDialog({
    super.key,
    required this.userName,
    required this.onSubmit,
    this.onBack,
  });

  final String userName;
  final Future<String?> Function(String reason) onSubmit;
  final VoidCallback? onBack;

  static Future<bool?> show(
    BuildContext context, {
    required String userName,
    required Future<String?> Function(String reason) onSubmit,
    VoidCallback? onBack,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReactivateUserDialog(
      userName: userName,
      onSubmit: onSubmit,
      onBack: onBack,
    ),
  );

  @override
  Widget build(BuildContext context) => _LifecycleConfirmDialog(
    title: 'Reactivate User Account',
    semanticId: 'reactivate-user-dialog',
    message:
        'You are about to reactivate the account for "$userName". '
        'The user will not be able to log in until they complete the '
        'activation workflow.',
    effectsSeverity: AppBannerSeverity.info,
    effectsIcon: Icons.info_outline,
    effects: const [
      'Restore previously assigned roles and site assignments',
      'Set account status to Pending Activation',
      'Send a new activation email to the user',
      'Require the user to set a new password and complete 2FA setup',
    ],
    reasonLabel: 'Reason for reactivation',
    reasonHint: 'Enter reason for reactivating this User',
    onBack: onBack,
    onSubmit: onSubmit,
  );
}

/// Shared shape for the deactivate / reactivate confirmations: message +
/// effects panel + required reason + Cancel/Confirm. Owns the in-flight
/// state; pops with `true` after a successful submit.
class _LifecycleConfirmDialog extends StatefulWidget {
  const _LifecycleConfirmDialog({
    required this.title,
    required this.semanticId,
    required this.message,
    required this.effectsSeverity,
    required this.effectsIcon,
    required this.effects,
    required this.reasonLabel,
    required this.reasonHint,
    required this.onBack,
    required this.onSubmit,
  });

  final String title;
  final String semanticId;
  final String message;
  final AppBannerSeverity effectsSeverity;
  final IconData effectsIcon;
  final List<String> effects;
  final String reasonLabel;
  final String reasonHint;
  final VoidCallback? onBack;
  final Future<String?> Function(String reason) onSubmit;

  @override
  State<_LifecycleConfirmDialog> createState() =>
      _LifecycleConfirmDialogState();
}

class _LifecycleConfirmDialogState extends State<_LifecycleConfirmDialog> {
  String _reason = '';
  bool _submitting = false;
  String? _error;

  bool get _canSubmit => !_submitting && _reason.trim().isNotEmpty;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onSubmit(_reason.trim());
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final bulletColor = switch (widget.effectsSeverity) {
      AppBannerSeverity.error => theme.colorScheme.error,
      AppBannerSeverity.info => semantic.info,
      AppBannerSeverity.warning => semantic.warning,
      AppBannerSeverity.success => semantic.success,
    };

    return AppDialog(
      size: AppDialogSize.small,
      title: widget.title,
      breadcrumb: widget.onBack == null
          ? null
          : UserFlowBackLink(onBack: widget.onBack!, enabled: !_submitting),
      dismissible: !_submitting,
      semanticId: widget.semanticId,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          AppBanner(
            severity: widget.effectsSeverity,
            icon: widget.effectsIcon,
            title: 'Effects of this action:',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final effect in widget.effects)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•  ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: bulletColor,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            effect,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: bulletColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Implements: DIARY-PRD-reason-field-constraints/A+B — submit
          // is gated on a non-whitespace reason; maxLength caps input at
          // 100 characters and renders the live "n/100" counter.
          AppTextField(
            label: widget.reasonLabel,
            required: true,
            hintText: widget.reasonHint,
            enabled: !_submitting,
            minLines: 2,
            maxLines: 4,
            maxLength: 100,
            semanticId: '${widget.semanticId}-reason',
            onChanged: (v) => setState(() => _reason = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppBanner(
              severity: AppBannerSeverity.error,
              message: _error!,
              semanticId: '${widget.semanticId}-error',
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
      ),
      actions: [
        AppButton(
          variant: AppButtonVariant.secondary,
          label: 'Cancel',
          semanticId: '${widget.semanticId}-cancel',
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Confirm',
          loading: _submitting,
          semanticId: '${widget.semanticId}-confirm',
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

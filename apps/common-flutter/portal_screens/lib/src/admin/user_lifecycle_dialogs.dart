import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

/// Deactivate User Account dialog (Figma: User Details / Deactivate
/// User Account).
///
/// Red "Effects of this action" panel, a required reason field, and a
/// destructive Confirm. [onSubmit] receives the trimmed reason and
/// resolves to `null` on success or a user-facing error message.
class DeactivateUserDialog extends StatelessWidget {
  const DeactivateUserDialog({
    super.key,
    required this.userName,
    required this.onSubmit,
  });

  final String userName;
  final Future<String?> Function(String reason) onSubmit;

  static Future<bool?> show(
    BuildContext context, {
    required String userName,
    required Future<String?> Function(String reason) onSubmit,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        DeactivateUserDialog(userName: userName, onSubmit: onSubmit),
  );

  @override
  Widget build(BuildContext context) => _LifecycleConfirmDialog(
    title: 'Deactivate User Account',
    semanticId: 'deactivate-user-dialog',
    message:
        'You are about to deactivate the account for "$userName". '
        'The action can be reversed by reactivating the account later.',
    effectsSeverity: AppBannerSeverity.error,
    effectsTitle: 'Effects of this action:',
    effects: const [
      'Terminates the user’s active sessions immediately',
      'Prevents the user from logging in',
      'The user’s data and audit history are preserved',
    ],
    reasonLabel: 'Reason for deactivation',
    reasonHint: 'Enter reason for deactivating this user',
    confirmLabel: 'Confirm',
    confirmVariant: AppButtonVariant.destructive,
    onSubmit: onSubmit,
  );
}

/// Reactivate User Account dialog (Figma: User Details / Reactivate
/// User Account).
class ReactivateUserDialog extends StatelessWidget {
  const ReactivateUserDialog({
    super.key,
    required this.userName,
    required this.onSubmit,
  });

  final String userName;
  final Future<String?> Function(String reason) onSubmit;

  static Future<bool?> show(
    BuildContext context, {
    required String userName,
    required Future<String?> Function(String reason) onSubmit,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        ReactivateUserDialog(userName: userName, onSubmit: onSubmit),
  );

  @override
  Widget build(BuildContext context) => _LifecycleConfirmDialog(
    title: 'Reactivate User Account',
    semanticId: 'reactivate-user-dialog',
    message:
        'You are about to reactivate the account for "$userName". '
        'The user must re-activate their account before logging in.',
    effectsSeverity: AppBannerSeverity.info,
    effectsTitle: 'Effects of this action:',
    effects: const [
      'Restores the account to Pending until the user re-activates',
      'Sends a new activation email to the user',
      'Roles and site assignments resume as previously configured',
    ],
    reasonLabel: 'Reason for reactivation',
    reasonHint: 'Enter reason for reactivating this user',
    confirmLabel: 'Confirm',
    confirmVariant: AppButtonVariant.primary,
    onSubmit: onSubmit,
  );
}

/// Shared shape for the deactivate / reactivate confirmations: message +
/// effects banner + required reason + Cancel/Confirm. Owns the in-flight
/// state; pops with `true` after a successful submit.
class _LifecycleConfirmDialog extends StatefulWidget {
  const _LifecycleConfirmDialog({
    required this.title,
    required this.semanticId,
    required this.message,
    required this.effectsSeverity,
    required this.effectsTitle,
    required this.effects,
    required this.reasonLabel,
    required this.reasonHint,
    required this.confirmLabel,
    required this.confirmVariant,
    required this.onSubmit,
  });

  final String title;
  final String semanticId;
  final String message;
  final AppBannerSeverity effectsSeverity;
  final String effectsTitle;
  final List<String> effects;
  final String reasonLabel;
  final String reasonHint;
  final String confirmLabel;
  final AppButtonVariant confirmVariant;
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
    return AppDialog(
      size: AppDialogSize.small,
      title: widget.title,
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
            title: widget.effectsTitle,
            // AppBanner renders a single message string; the bullet list
            // from the Figma panel is composed with newlines.
            message: widget.effects.map((e) => '•  $e').join('\n'),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: widget.reasonLabel,
            required: true,
            hintText: widget.reasonHint,
            enabled: !_submitting,
            minLines: 2,
            maxLines: 4,
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
          const SizedBox(height: 4),
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
          variant: widget.confirmVariant,
          label: widget.confirmLabel,
          loading: _submitting,
          semanticId: '${widget.semanticId}-confirm',
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

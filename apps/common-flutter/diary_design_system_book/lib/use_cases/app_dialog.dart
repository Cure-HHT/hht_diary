import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

WidgetbookComponent appDialogComponent() {
  return WidgetbookComponent(
    name: 'AppDialog',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — sizes, variants, and async phases',
        builder: (_) => const _AppDialogGallery(),
      ),
    ],
  );
}

class _AppDialogGallery extends StatelessWidget {
  const _AppDialogGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppDialog — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Dialogs render inline here for visual review. In real use they '
          'mount via `showDialog(...)`; the "Open as overlay" buttons in '
          'each section demo that flow.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),

        // ---- Skeleton sizes
        _Section(
          title: 'Skeleton sizes',
          children: [
            for (final size in AppDialogSize.values)
              _DialogPreview(
                label: '${size.name} (${size.width.toInt()} px)',
                dialog: AppDialog(
                  size: size,
                  title: 'Dialog title',
                  subtitle: 'Optional subtitle / supporting copy',
                  body: const Text(
                    'Body content goes here. Body scrolls if it exceeds the '
                    'available vertical space.',
                  ),
                  actions: [
                    AppButton(
                      variant: AppButtonVariant.secondary,
                      label: 'Cancel',
                      onPressed: _noop,
                    ),
                    AppButton(label: 'Confirm', onPressed: _noop),
                  ],
                ),
              ),
          ],
        ),

        // ---- Confirmation
        _Section(
          title: '.confirmation',
          children: [
            _DialogPreview(
              label: 'Inline render',
              dialog: AppDialog(
                size: AppDialogSize.small,
                dismissible: false,
                title: 'End the cycle?',
                body: const Text(
                  'This will close the active cycle and lock its entries from '
                  'further edits.',
                ),
                actions: [
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    label: 'Cancel',
                    onPressed: _noop,
                  ),
                  AppButton(label: 'End cycle', onPressed: _noop),
                ],
              ),
            ),
            _OverlayLauncher(
              label: 'Open as overlay',
              onPressed: (ctx) => AppDialog.confirmation(
                context: ctx,
                title: 'End the cycle?',
                message:
                    'This will close the active cycle and lock its entries.',
                confirmLabel: 'End cycle',
              ),
            ),
          ],
        ),

        // ---- Acknowledgment
        _Section(
          title: '.acknowledgment',
          children: [
            _DialogPreview(
              label: 'Inline render',
              dialog: AppDialog(
                size: AppDialogSize.small,
                title: 'Mobile linking code',
                body: const Text(
                  'Share the code below with the participant. It expires in '
                  '15 minutes.',
                ),
                actions: [AppButton(label: 'OK', onPressed: _noop)],
              ),
            ),
            _OverlayLauncher(
              label: 'Open as overlay',
              onPressed: (ctx) => AppDialog.acknowledgment(
                context: ctx,
                title: 'Mobile linking code',
                message:
                    'Share the code below with the participant. It expires in 15 minutes.',
              ),
            ),
          ],
        ),

        // ---- Destructive
        _Section(
          title: '.destructive',
          children: [
            _DialogPreview(
              label: 'Inline render',
              dialog: AppDialog(
                size: AppDialogSize.small,
                dismissible: false,
                title: 'Disconnect participant',
                body: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Disconnect this participant from the mobile app:',
                    ),
                    const SizedBox(height: 16),
                    const AppBanner(
                      severity: AppBannerSeverity.warning,
                      message:
                          'This will revoke all active linking codes and the participant will see a disconnection notice in their app.',
                    ),
                  ],
                ),
                actions: [
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    label: 'Cancel',
                    onPressed: _noop,
                  ),
                  AppButton(
                    variant: AppButtonVariant.destructive,
                    label: 'Disconnect',
                    onPressed: _noop,
                  ),
                ],
              ),
            ),
            _OverlayLauncher(
              label: 'Open as overlay',
              onPressed: (ctx) => AppDialog.destructive(
                context: ctx,
                title: 'Disconnect participant',
                message: 'Disconnect this participant from the mobile app:',
                warningMessage:
                    'This will revoke all active linking codes and the participant will see a disconnection notice in their app.',
                confirmLabel: 'Disconnect',
              ),
            ),
          ],
        ),

        // ---- .reason — overlay launchers
        _Section(
          title: '.reason — overlay launchers',
          children: [
            _OverlayLauncher(
              label: 'Open reason dialog (free text)',
              onPressed: (ctx) => AppDialog.reason(
                context: ctx,
                title: 'Why are you disconnecting?',
                message:
                    'Enter a brief reason. This is stored with the audit log.',
                hintText: 'Reason for disconnection',
              ),
            ),
            _OverlayLauncher(
              label: 'Open reason dialog (predefined list)',
              onPressed: (ctx) => AppDialog.reason(
                context: ctx,
                title: 'Why are you disconnecting?',
                message: 'Pick the closest matching reason.',
                reasons: const [
                  AppDropdownItem(value: 'device', label: 'Device Issues'),
                  AppDropdownItem(value: 'tech', label: 'Technical Issues'),
                  AppDropdownItem(value: 'other', label: 'Other'),
                ],
              ),
            ),
          ],
        ),

        // ---- ActionBuilder + AppDialog — live composition.
        //
        // The canonical reactive-portal pattern: ActionBuilder owns the
        // submission lifecycle + idempotency key; AppDialog renders the
        // chrome; AppButton(loading: state is Submitting, onPressed: submit)
        // wires them together. Backed by `FakeReaction` from
        // `reaction_widgets_testing` (a shipped public deliverable) so the
        // demo runs without a real action backend.
        _Section(
          title:
              'ActionBuilder + AppDialog — live composition (reactive portal pattern)',
          children: [_ActionBuilderDemo()],
        ),

        // ---- Async dialog phases (visual reference).
        //
        // Static AppDialog previews showing what each phase looks like when
        // a caller composes AppDialog inside their app's async primitive
        // (e.g. ActionBuilder from reaction_widgets). The design system
        // intentionally ships no async-dialog state machine of its own.
        _Section(
          title: 'Async dialog phases — visual reference',
          children: [
            _DialogPreview(
              label: 'Confirm',
              dialog: AppDialog(
                size: AppDialogSize.small,
                title: 'Disconnect participant',
                body: const Text(
                  'Choose a reason and confirm to start the disconnect.',
                ),
                actions: [
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    label: 'Cancel',
                    onPressed: _noop,
                  ),
                  AppButton(
                    variant: AppButtonVariant.destructive,
                    label: 'Disconnect',
                    onPressed: _noop,
                  ),
                ],
              ),
            ),
            _DialogPreview(
              label: 'Loading',
              dialog: AppDialog(
                size: AppDialogSize.small,
                dismissible: false,
                title: 'Disconnecting…',
                body: const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            _DialogPreview(
              label: 'Success',
              dialog: AppDialog(
                size: AppDialogSize.small,
                title: 'Participant disconnected',
                body: const Text(
                  'Linking codes revoked: 3. The participant will see a '
                  'disconnection notice the next time they open the app.',
                ),
                actions: [AppButton(label: 'Done', onPressed: _noop)],
              ),
            ),
            _DialogPreview(
              label: 'Error',
              dialog: AppDialog(
                size: AppDialogSize.small,
                title: 'Disconnect failed',
                body: const Text(
                  'We couldn\'t reach the server. Try again or contact '
                  'support if the problem persists.',
                ),
                actions: [
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    label: 'Cancel',
                    onPressed: _noop,
                  ),
                  AppButton(label: 'Try again', onPressed: _noop),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DialogPreview extends StatelessWidget {
  final String label;
  final Widget dialog;
  const _DialogPreview({required this.label, required this.dialog});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          dialog,
        ],
      ),
    );
  }
}

class _OverlayLauncher extends StatelessWidget {
  final String label;
  final Future<void> Function(BuildContext) onPressed;
  const _OverlayLauncher({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppButton(
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        label: label,
        onPressed: () => onPressed(context),
      ),
    );
  }
}

/// Live demo of the canonical `ActionBuilder` + `AppDialog` composition.
///
/// Each launcher mints a fresh [FakeReaction], pre-queues one delayed
/// [DispatchResult], and opens a dialog whose actions are driven by the
/// `ActionBuilder`'s `(state, submit)` tuple. The user can step through
/// the full lifecycle (confirm → Submitting → Success/Denied/Failed) and
/// see how `AppButton(loading: state is Submitting, onPressed: submit)`
/// maps onto the state machine.
class _ActionBuilderDemo extends StatelessWidget {
  const _ActionBuilderDemo();

  Future<DispatchResult<Object?>> _delayedSuccess() {
    return Future.delayed(
      const Duration(milliseconds: 800),
      () => const DispatchSuccess<Object?>(null, <String>['evt-1']),
    );
  }

  Future<DispatchResult<Object?>> _delayedDenied() {
    return Future.delayed(
      const Duration(milliseconds: 800),
      () => const DispatchValidationDenied<Object?>('patient id is required'),
    );
  }

  Future<DispatchResult<Object?>> _delayedThrow() {
    return Future<DispatchResult<Object?>>.delayed(
      const Duration(milliseconds: 800),
    ).then((_) => throw StateError('network unreachable'));
  }

  Future<void> _open(
    BuildContext context, {
    required Future<DispatchResult<Object?>> result,
  }) async {
    // Fresh FakeReaction per dialog so queues don't bleed between launches.
    final fake = FakeReaction();
    fake.queueDispatchResultFuture(result);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReActionScope(
          scope: fake,
          child: ActionBuilder(
            submissionFactory: () => const ActionSubmission(
              actionName: 'disconnect_participant',
              rawInput: <String, Object?>{'patientId': 'P-42'},
            ),
            builder: (ctx, state, submit) => _DisconnectDialog(
              state: state,
              onSubmit: submit,
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      );
    } finally {
      await fake.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Live demo backed by FakeReaction from reaction_widgets_testing. '
            'Pick an outcome — the dialog cycles confirm → Submitting → '
            'Success/Denied/Failed using the same ActionBuilder pattern '
            'documented on AppDialog.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              label: 'Open: succeeds',
              onPressed: () => _open(context, result: _delayedSuccess()),
            ),
            AppButton(
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              label: 'Open: denied',
              onPressed: () => _open(context, result: _delayedDenied()),
            ),
            AppButton(
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              label: 'Open: errors',
              onPressed: () => _open(context, result: _delayedThrow()),
            ),
          ],
        ),
      ],
    );
  }
}

/// AppDialog rendered from an [ActionState]. Kept separate from
/// [_ActionBuilderDemo] so the composition pattern (state → chrome) is
/// readable on its own.
class _DisconnectDialog extends StatelessWidget {
  const _DisconnectDialog({
    required this.state,
    required this.onSubmit,
    required this.onClose,
  });

  final ActionState state;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isTerminal = state is Success || state is Denied || state is Failed;
    final isSubmitting = state is Submitting;

    return AppDialog(
      size: AppDialogSize.small,
      dismissible: false,
      title: switch (state) {
        Submitting() => 'Disconnecting…',
        Success() => 'Participant disconnected',
        Denied() => 'Disconnect denied',
        Failed() => 'Disconnect failed',
        _ => 'Disconnect participant',
      },
      body: switch (state) {
        Submitting() => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        Success() => const Text(
          'Linking codes revoked. The participant will see a '
          'disconnection notice the next time they open the app.',
        ),
        Denied(:final reason) => Text(reason),
        Failed(:final error) => Text('$error'),
        _ => const Text(
          'This will revoke active linking codes and the participant '
          'will see a disconnection notice in their app.',
        ),
      },
      actions: isTerminal
          ? [AppButton(label: 'Close', onPressed: onClose)]
          : [
              AppButton(
                variant: AppButtonVariant.secondary,
                label: 'Cancel',
                onPressed: isSubmitting ? null : onClose,
              ),
              AppButton(
                variant: AppButtonVariant.destructive,
                label: 'Disconnect',
                loading: isSubmitting,
                onPressed: isSubmitting ? null : onSubmit,
              ),
            ],
    );
  }
}

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
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

        // ---- Async via AppDialog.async factory
        _Section(
          title: '.async — overlay launcher',
          children: [
            _OverlayLauncher(
              label: 'Open async flow',
              onPressed: (ctx) => AppDialog.async<String>(
                context: ctx,
                onSubmit: () async {
                  await Future.delayed(const Duration(milliseconds: 800));
                  return 'codes-revoked-3';
                },
                confirmBuilder: (c, submit) => AppDialog(
                  size: AppDialogSize.small,
                  dismissible: false,
                  title: 'Disconnect participant',
                  body: const Text(
                    'This will revoke active linking codes and the participant '
                    'will see a disconnection notice in their app.',
                  ),
                  actions: [
                    AppButton(
                      variant: AppButtonVariant.secondary,
                      label: 'Cancel',
                      onPressed: () => Navigator.of(c).pop(),
                    ),
                    AppButton(
                      variant: AppButtonVariant.destructive,
                      label: 'Disconnect',
                      onPressed: submit,
                    ),
                  ],
                ),
                successBuilder: (c, value) => AppDialog(
                  size: AppDialogSize.small,
                  title: 'Participant disconnected',
                  body: Text('Result: $value'),
                  actions: [
                    AppButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(c).pop(value),
                    ),
                  ],
                ),
                errorBuilder: (c, error, retry) => AppDialog(
                  size: AppDialogSize.small,
                  title: 'Disconnect failed',
                  body: Text(error.toString()),
                  actions: [
                    AppButton(
                      variant: AppButtonVariant.secondary,
                      label: 'Cancel',
                      onPressed: () => Navigator.of(c).pop(),
                    ),
                    AppButton(label: 'Try again', onPressed: retry),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ---- AsyncActionDialog phases
        _Section(
          title: 'AsyncActionDialog — phases',
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

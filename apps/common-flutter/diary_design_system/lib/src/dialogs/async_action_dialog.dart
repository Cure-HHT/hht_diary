import 'package:flutter/material.dart';

/// The four phases of an async workflow dialog.
enum AsyncDialogPhase { confirm, loading, success, error }

/// Generic state machine for confirm → loading → success → error dialogs.
///
/// The caller owns the rendering of each phase via builders that return an
/// [AppDialog] (or any widget tree). This widget just dispatches.
///
/// Usage:
/// ```dart
/// await showDialog(
///   context: context,
///   builder: (_) => AsyncActionDialog<DisconnectResult>(
///     onSubmit: () => apiClient.disconnect(patientId),
///     confirmBuilder: (ctx, submit) => AppDialog(
///       title: 'Disconnect participant',
///       body: ...,
///       actions: [
///         AppButton.tertiary(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
///         AppButton.destructive(label: 'Disconnect', onPressed: submit),
///       ],
///     ),
///     successBuilder: (ctx, result) => AppDialog(
///       title: 'Participant disconnected',
///       body: Text('Codes revoked: ${result.codesRevoked}'),
///       actions: [
///         AppButton(label: 'Done', onPressed: () => Navigator.pop(ctx, result)),
///       ],
///     ),
///     errorBuilder: (ctx, error, retry) => AppDialog(
///       title: 'Disconnect failed',
///       body: Text(error.toString()),
///       actions: [
///         AppButton.tertiary(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
///         AppButton(label: 'Try again', onPressed: retry),
///       ],
///     ),
///   ),
/// );
/// ```
class AsyncActionDialog<T> extends StatefulWidget {
  /// The async work to run when the user confirms.
  final Future<T> Function() onSubmit;

  /// Builds the confirm-phase widget. Receives a `submit` callback the caller
  /// should wire to the confirm button.
  final Widget Function(BuildContext context, VoidCallback submit)
  confirmBuilder;

  /// Builds the loading-phase widget. If null, a default
  /// `Dialog(child: CircularProgressIndicator)` is shown.
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Builds the success-phase widget. Receives the result from [onSubmit].
  final Widget Function(BuildContext context, T result) successBuilder;

  /// Builds the error-phase widget. Receives the caught error and a `retry`
  /// callback that restarts the async work.
  final Widget Function(BuildContext context, Object error, VoidCallback retry)
  errorBuilder;

  const AsyncActionDialog({
    super.key,
    required this.onSubmit,
    required this.confirmBuilder,
    required this.successBuilder,
    required this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  State<AsyncActionDialog<T>> createState() => _AsyncActionDialogState<T>();
}

class _AsyncActionDialogState<T> extends State<AsyncActionDialog<T>> {
  AsyncDialogPhase _phase = AsyncDialogPhase.confirm;
  T? _result;
  Object? _error;

  Future<void> _runSubmit() async {
    setState(() => _phase = AsyncDialogPhase.loading);
    try {
      final result = await widget.onSubmit();
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = AsyncDialogPhase.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _phase = AsyncDialogPhase.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case AsyncDialogPhase.confirm:
        return widget.confirmBuilder(context, _runSubmit);
      case AsyncDialogPhase.loading:
        return widget.loadingBuilder?.call(context) ??
            const _DefaultLoadingDialog();
      case AsyncDialogPhase.success:
        return widget.successBuilder(context, _result as T);
      case AsyncDialogPhase.error:
        return widget.errorBuilder(context, _error!, _runSubmit);
    }
  }
}

class _DefaultLoadingDialog extends StatelessWidget {
  const _DefaultLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'session_timeout_controller.dart';
import 'session_timeout_warning_dialog.dart';

/// Route name for the warning dialog, so dismissal targets exactly this route
/// and never pops whatever else might be on top of the navigator.
const String _kWarningDialogRoute = 'session-timeout-warning';

/// Wraps the authenticated shell: forwards mouse/pointer/keyboard activity to
/// the [SessionTimeoutController] and shows/dismisses the warning dialog as the
/// controller's warning state flips. Ported from the legacy portal-ui
/// `UserActivityListener`.
// Implements: DIARY-GUI-portal-session-expiry/A+B
class SessionActivityListener extends StatefulWidget {
  const SessionActivityListener({
    super.key,
    required this.controller,
    required this.onSignOut,
    required this.child,
  });

  final SessionTimeoutController controller;
  final VoidCallback onSignOut;
  final Widget child;

  @override
  State<SessionActivityListener> createState() =>
      _SessionActivityListenerState();
}

class _SessionActivityListenerState extends State<SessionActivityListener> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncDialog);
  }

  @override
  void didUpdateWidget(SessionActivityListener old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_syncDialog);
      widget.controller.addListener(_syncDialog);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncDialog);
    super.dispose();
  }

  void _syncDialog() {
    final warning = widget.controller.isWarning;
    if (warning && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.controller.isWarning) {
          _dialogShown = false;
          return;
        }
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          routeSettings: const RouteSettings(name: _kWarningDialogRoute),
          builder: (_) => SessionTimeoutWarningDialog(
            controller: widget.controller,
            onSignOut: widget.onSignOut,
          ),
        ).then((_) => _dialogShown = false);
      });
    } else if (!warning && _dialogShown) {
      _dialogShown = false;
      if (mounted) {
        // Pop only our own dialog: popUntil removes consecutive top routes
        // named [_kWarningDialogRoute] and stops at the first route that is not
        // ours, so it never dismisses some other route that happens to be on top.
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.settings.name != _kWarningDialogRoute);
      }
    }
  }

  void _onActivity() => widget.controller.notifyActivity();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _onActivity(),
      child: Listener(
        onPointerDown: (_) => _onActivity(),
        onPointerMove: (_) => _onActivity(),
        onPointerSignal: (_) => _onActivity(),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, __) {
            _onActivity();
            return KeyEventResult.ignored;
          },
          child: widget.child,
        ),
      ),
    );
  }
}

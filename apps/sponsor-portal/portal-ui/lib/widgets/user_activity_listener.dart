import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'session_timeout_warning_dialog.dart';

class UserActivityListener extends StatefulWidget {
  final Widget child;

  const UserActivityListener({super.key, required this.child});

  @override
  State<UserActivityListener> createState() => _UserActivityListenerState();
}

class _UserActivityListenerState extends State<UserActivityListener> {
  DateTime? _lastReset;
  final Duration _throttleDuration = const Duration(seconds: 30);
  bool _dialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for isWarning changes and show/dismiss the dialog accordingly.
    final auth = context.watch<AuthService>();
    _syncWarningDialog(auth);
  }

  void _syncWarningDialog(AuthService auth) {
    if (auth.isWarning && !_dialogShown) {
      _dialogShown = true;
      // Show the warning dialog on the next frame so the widget tree is stable.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Re-check; the warning may have been cleared by activity before the
        // frame fires.
        final currentAuth = context.read<AuthService>();
        if (!currentAuth.isWarning) {
          _dialogShown = false;
          return;
        }
        // REQ-d00080-D, REQ-p01044-G: show warning dialog
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ChangeNotifierProvider<AuthService>.value(
            value: currentAuth,
            child: const SessionTimeoutWarningDialog(),
          ),
        ).then((_) {
          _dialogShown = false;
        });
      });
    } else if (!auth.isWarning && _dialogShown) {
      // Timer was reset externally (e.g. other activity); close dialog.
      _dialogShown = false;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) {
          return route.settings.name != null || route is! DialogRoute;
        });
      }
    }
  }

  void _onUserActivity(BuildContext context) {
    final auth = context.read<AuthService>();
    // REQ-p01044-I: while warning dialog is shown, passive activity (mouse/keyboard)
    // must not reset the timer — only the explicit "Stay Logged In" button does.
    if (auth.isWarning) return;

    final now = DateTime.now();
    if (_lastReset != null && now.difference(_lastReset!) < _throttleDuration) {
      return;
    }

    if (auth.isAuthenticated) {
      _lastReset = now;
      auth.resetInactivityTimer(); // REQ-d00080-C: reset inactivity timer when tracked interaction occurs
    }
  }

  @override
  Widget build(BuildContext context) {
    // REQ-d00080-B: track mouse movement, touch events, clicks, and keyboard input to detect activity
    return MouseRegion(
      onHover: (_) {
        _onUserActivity(context);
      },
      child: Listener(
        // Pointer = mouse moves, taps, clicks, scroll wheel, etc.
        onPointerDown: (_) => _onUserActivity(context),
        onPointerMove: (_) {
          _onUserActivity(context);
        },
        onPointerSignal: (_) => _onUserActivity(context),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, __) {
            _onUserActivity(context);
            return KeyEventResult.ignored;
          },
          child: widget.child,
        ),
      ),
    );
  }
}

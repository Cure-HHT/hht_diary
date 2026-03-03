import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class UserActivityListener extends StatefulWidget {
  final Widget child;

  const UserActivityListener({super.key, required this.child});

  @override
  State<UserActivityListener> createState() => _UserActivityListenerState();
}

class _UserActivityListenerState extends State<UserActivityListener> {
  DateTime? _lastReset;
  final Duration _throttleDuration = const Duration(seconds: 30);

  void _onUserActivity(BuildContext context) {
    final now = DateTime.now();
    if (_lastReset != null && now.difference(_lastReset!) < _throttleDuration) {
      return;
    }

    final auth = context.read<AuthService>();
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

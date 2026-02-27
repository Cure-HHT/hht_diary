import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class UserActivityListener extends StatelessWidget {
  final Widget child;

  const UserActivityListener({super.key, required this.child});

  void _onUserActivity(BuildContext context) {
    final auth = context.read<AuthService>();
    if (auth.isAuthenticated) {
      auth.resetInactivityTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: child,
        ),
      ),
    );
  }
}

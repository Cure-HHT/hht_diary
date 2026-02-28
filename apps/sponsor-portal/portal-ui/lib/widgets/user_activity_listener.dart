// IMPLEMENTS REQUIREMENTS:
//   REQ-d00080: Web Session Management Implementation
//   REQ-p01044: Web Diary Session Management

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

/// Wraps a widget tree to detect user activity and reset the inactivity timer.
///
/// Tracks mouse movement, pointer events (taps, clicks, scroll), and keyboard
/// input so that any interaction resets the session timeout.
class UserActivityListener extends StatelessWidget {
  final Widget child;

  const UserActivityListener({super.key, required this.child});

  /// Reset the inactivity timer on any user interaction.
  /// Implements REQ-d00080-C, REQ-p01044-F.
  void _onUserActivity(BuildContext context) {
    final auth = context.read<AuthService>();
    if (auth.isAuthenticated) {
      auth.resetInactivityTimer();
    }
  }

  /// Listens for mouse, pointer, and keyboard events.
  /// Implements REQ-d00080-B (track mouse movement, keyboard input, touch, clicks).
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

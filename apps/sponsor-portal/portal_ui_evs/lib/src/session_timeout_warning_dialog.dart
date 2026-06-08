import 'package:flutter/material.dart';

import 'session_timeout_controller.dart';

/// Pre-timeout warning dialog. Shows a live countdown (driven by
/// [SessionTimeoutController.secondsLeft]) and two actions: "Stay signed in"
/// extends the session, "Sign out" ends it. Neither button pops the dialog
/// itself — dismissal is reactive: the activity listener removes the dialog
/// when the controller's warning state clears (via staySignedIn, cancel, or
/// expiry), keeping a single dismissal path. Passive activity does not dismiss
/// it (the controller enforces that). Ported from the legacy portal-ui
/// `SessionTimeoutWarningDialog`.
// Implements: DIARY-GUI-portal-session-expiry/A+B
class SessionTimeoutWarningDialog extends StatelessWidget {
  const SessionTimeoutWarningDialog({
    super.key,
    required this.controller,
    required this.onSignOut,
  });

  final SessionTimeoutController controller;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.secondsLeft;
        return AlertDialog(
          title: const Text('Session Expiring Soon'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Your session is about to expire due to inactivity.'),
              const SizedBox(height: 16),
              Text(
                'Time remaining: $s second${s == 1 ? '' : 's'}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('sign-out-button'),
              onPressed: onSignOut,
              child: const Text('Sign out'),
            ),
            ElevatedButton(
              key: const Key('stay-signed-in-button'),
              onPressed: () => controller.staySignedIn(),
              child: const Text('Stay signed in'),
            ),
          ],
        );
      },
    );
  }
}

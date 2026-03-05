import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

/// Dialog displayed 30 seconds before the inactivity session timeout.
///
/// Shows a live countdown and a "Stay Logged In" button that resets the
/// inactivity timer. If the user ignores the dialog the main timeout fires
/// and signs them out automatically.
class SessionTimeoutWarningDialog extends StatefulWidget {
  /// Seconds to count down from (matches [AuthService._warningLeadTime]).
  final int countdownSeconds;

  const SessionTimeoutWarningDialog({super.key, this.countdownSeconds = 30});

  @override
  State<SessionTimeoutWarningDialog> createState() =>
      _SessionTimeoutWarningDialogState();
}

class _SessionTimeoutWarningDialogState
    extends State<SessionTimeoutWarningDialog> {
  late int _secondsLeft;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.countdownSeconds;
    // REQ-p01044-H: dialog shows countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
          if (_secondsLeft == 0) timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session Expiring Soon'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Your session is about to expire due to inactivity.'),
          const SizedBox(height: 16),
          // REQ-p01044-H: countdown display
          Text(
            'Time remaining: $_secondsLeft second${_secondsLeft == 1 ? '' : 's'}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        // REQ-d00080-E, REQ-p01044-I: Stay Logged In resets the timer
        ElevatedButton(
          key: const Key('stay-logged-in-button'),
          onPressed: () {
            context.read<AuthService>().resetInactivityTimer();
            Navigator.of(context).pop();
          },
          child: const Text('Stay Logged In'),
        ),
      ],
    );
  }
}

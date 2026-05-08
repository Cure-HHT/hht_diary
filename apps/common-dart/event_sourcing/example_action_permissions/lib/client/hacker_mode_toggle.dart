// lib/client/hacker_mode_toggle.dart
//
// Hacker mode: a per-pane bool that, when on, ungates all action buttons
// regardless of the client-side snapshot. Demonstrates that the
// dispatcher's authorize stage is the real perimeter — the client-side
// gating is just a UI courtesy.

import 'package:flutter/material.dart';

class HackerMode extends ChangeNotifier {
  bool _enabled = false;

  bool get enabled => _enabled;

  void set(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  void toggle() => set(!_enabled);
}

class HackerModeToggle extends StatelessWidget {
  const HackerModeToggle({super.key, required this.mode});

  final HackerMode mode;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mode,
      builder: (context, _) {
        return Row(
          children: <Widget>[
            const Text('Hacker mode'),
            const SizedBox(width: 8),
            Switch(value: mode.enabled, onChanged: mode.set),
            const SizedBox(width: 8),
            if (mode.enabled)
              const Text(
                '(client gating bypassed)',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        );
      },
    );
  }
}

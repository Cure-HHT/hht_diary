// lib/client/userid_selector.dart
//
// Dropdown for switching the client's claimed userId. Re-rendered as the
// snapshot cache changes (so the current selection stays in sync).

import 'package:flutter/material.dart';

class UserIdSelector extends StatelessWidget {
  const UserIdSelector({
    super.key,
    required this.currentUserId,
    required this.knownUserIds,
    required this.onChanged,
  });

  final String? currentUserId;
  final List<String> knownUserIds;
  final void Function(String? userId) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: currentUserId,
      isExpanded: true,
      hint: const Text('(select a user, or stay anonymous)'),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('(Anon — no userId)'),
        ),
        for (final id in knownUserIds)
          DropdownMenuItem<String?>(value: id, child: Text(id)),
      ],
      onChanged: onChanged,
    );
  }
}

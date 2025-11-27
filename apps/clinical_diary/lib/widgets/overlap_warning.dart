// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/material.dart';

/// Warning widget for overlapping events
class OverlapWarning extends StatelessWidget {
  const OverlapWarning({required this.overlappingCount, super.key});

  final int overlappingCount;

  @override
  Widget build(BuildContext context) {
    if (overlappingCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overlapping Events Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'This event overlaps with $overlappingCount existing event${overlappingCount > 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

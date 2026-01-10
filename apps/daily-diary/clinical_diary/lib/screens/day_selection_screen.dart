// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Screen shown when selecting a calendar date without existing records.
/// Presents three options: Add nosebleed, No nosebleeds, or Unknown.
class DaySelectionScreen extends StatelessWidget {
  const DaySelectionScreen({
    required this.date,
    required this.onAddNosebleed,
    required this.onNoNosebleeds,
    required this.onUnknown,
    super.key,
  });

  final DateTime date;
  final VoidCallback onAddNosebleed;
  final VoidCallback onNoNosebleeds;
  final VoidCallback onUnknown;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d, y').format(date);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Date display
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Question
                    Text(
                      'What happened on this day?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Add nosebleed button (red/primary)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAddNosebleed,
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Add nosebleed event',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // No nosebleed events button (green)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onNoNosebleeds,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade700),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'No nosebleed events',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // I don't recall / unknown button (outline)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onUnknown,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "I don't recall / unknown",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

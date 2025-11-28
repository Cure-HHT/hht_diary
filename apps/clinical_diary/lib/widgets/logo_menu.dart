// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:flutter/material.dart';

/// Logo menu widget with data management and clinical trial options
class LogoMenu extends StatelessWidget {
  const LogoMenu({
    required this.onAddExampleData,
    required this.onResetAllData,
    required this.onEndClinicalTrial,
    required this.onInstructionsAndFeedback,
    super.key,
  });

  final VoidCallback onAddExampleData;
  final VoidCallback onResetAllData;
  final VoidCallback? onEndClinicalTrial;
  final VoidCallback onInstructionsAndFeedback;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.medical_services_outlined, size: 28),
      tooltip: 'App menu',
      onSelected: (value) {
        switch (value) {
          case 'add_example_data':
            onAddExampleData();
          case 'reset_all_data':
            onResetAllData();
          case 'end_clinical_trial':
            onEndClinicalTrial?.call();
          case 'instructions_feedback':
            onInstructionsAndFeedback();
        }
      },
      itemBuilder: (context) => [
        // Data Management section header
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'Data Management',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_example_data',
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Flexible(child: Text('Add Example Data')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'reset_all_data',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Reset All Data',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),

        // Clinical Trial section (only if enrolled)
        if (onEndClinicalTrial != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              'Clinical Trial',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'end_clinical_trial',
            child: Row(
              children: [
                Icon(
                  Icons.exit_to_app,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Flexible(child: Text('End Clinical Trial')),
              ],
            ),
          ),
        ],

        // External links section
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'instructions_feedback',
          child: Row(
            children: [
              Icon(
                Icons.open_in_new,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Flexible(child: Text('Instructions & Feedback')),
            ],
          ),
        ),
      ],
    );
  }
}

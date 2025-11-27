// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/material.dart';

/// Dialog for confirming deletion of a record with required reason
class DeleteConfirmationDialog extends StatefulWidget {
  const DeleteConfirmationDialog({required this.onConfirmDelete, super.key});

  final ValueChanged<String> onConfirmDelete;

  @override
  State<DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<DeleteConfirmationDialog> {
  final _reasonController = TextEditingController();
  String? _selectedReason;

  final List<String> _reasons = [
    'Entered by mistake',
    'Duplicate entry',
    'Incorrect information',
    'Other',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Record'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Please select a reason for deleting this record:'),
          const SizedBox(height: 16),
          ...(_reasons.map(
            (reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
              contentPadding: EdgeInsets.zero,
            ),
          )),
          if (_selectedReason == 'Other') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Please specify',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _selectedReason == null ||
                  (_selectedReason == 'Other' &&
                      _reasonController.text.trim().isEmpty)
              ? null
              : () {
                  final reason = _selectedReason == 'Other'
                      ? _reasonController.text.trim()
                      : _selectedReason!;
                  widget.onConfirmDelete(reason);
                  Navigator.pop(context);
                },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  /// Show the delete confirmation dialog
  static Future<void> show({
    required BuildContext context,
    required ValueChanged<String> onConfirmDelete,
  }) async {
    await showDialog(
      context: context,
      builder: (context) =>
          DeleteConfirmationDialog(onConfirmDelete: onConfirmDelete),
    );
  }
}

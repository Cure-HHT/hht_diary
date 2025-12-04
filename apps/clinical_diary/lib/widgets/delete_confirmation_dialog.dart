// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Dialog for confirming deletion of a record with required reason
class DeleteConfirmationDialog extends StatefulWidget {
  const DeleteConfirmationDialog({required this.onConfirmDelete, super.key});

  final ValueChanged<String> onConfirmDelete;

  /// Show the delete confirmation dialog
  static Future<void> show({
    required BuildContext context,
    required ValueChanged<String> onConfirmDelete,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          DeleteConfirmationDialog(onConfirmDelete: onConfirmDelete),
    );
  }

  @override
  State<DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<DeleteConfirmationDialog> {
  final _reasonController = TextEditingController();
  String? _selectedReasonKey;

  // Reason keys for internal logic
  static const _reasonKeys = [
    'enteredByMistake',
    'duplicateEntry',
    'incorrectInformation',
    'other',
  ];

  // Get localized display string for a reason key
  String _getReasonDisplay(String key, AppLocalizations l10n) {
    switch (key) {
      case 'enteredByMistake':
        return l10n.enteredByMistake;
      case 'duplicateEntry':
        return l10n.duplicateEntry;
      case 'incorrectInformation':
        return l10n.incorrectInformation;
      case 'other':
        return l10n.other;
      default:
        return key;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.deleteRecord),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.selectDeleteReason),
          const SizedBox(height: 16),
          // Using RadioGroup ancestor to manage radio selection
          RadioGroup<String>(
            groupValue: _selectedReasonKey,
            onChanged: (value) => setState(() => _selectedReasonKey = value),
            child: Column(
              children: _reasonKeys
                  .map(
                    (key) => InkWell(
                      onTap: () => setState(() => _selectedReasonKey = key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Radio<String>(value: key),
                            Expanded(child: Text(_getReasonDisplay(key, l10n))),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_selectedReasonKey == 'other') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: l10n.pleaseSpecify,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed:
              _selectedReasonKey == null ||
                  (_selectedReasonKey == 'other' &&
                      _reasonController.text.trim().isEmpty)
              ? null
              : () {
                  final reason = _selectedReasonKey == 'other'
                      ? _reasonController.text.trim()
                      : _getReasonDisplay(_selectedReasonKey!, l10n);
                  widget.onConfirmDelete(reason);
                  Navigator.pop(context);
                },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}

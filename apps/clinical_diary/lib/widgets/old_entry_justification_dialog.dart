// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00001: Old Entry Modification Justification

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Justification reasons for modifying old entries (more than one calendar day old).
/// Using predefined options to prevent inadvertent entry of PHI.
enum OldEntryJustification {
  enteredFromPaperRecords,
  rememberedSpecificEvent,
  estimatedEvent,
  other,
}

/// Dialog for requiring justification when editing events older than one calendar day.
/// REQ-CAL-p00001: The system SHALL require the user to select a justification reason
/// before saving modifications to old entries.
class OldEntryJustificationDialog extends StatefulWidget {
  const OldEntryJustificationDialog({required this.onConfirm, super.key});

  /// Callback when user confirms with a justification.
  /// Returns the selected justification reason.
  final void Function(OldEntryJustification justification) onConfirm;

  /// Show the old entry justification dialog.
  /// Returns the selected justification, or null if cancelled.
  static Future<OldEntryJustification?> show({
    required BuildContext context,
  }) async {
    return showDialog<OldEntryJustification>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OldEntryJustificationDialog(
        onConfirm: (justification) {
          Navigator.pop(context, justification);
        },
      ),
    );
  }

  @override
  State<OldEntryJustificationDialog> createState() =>
      _OldEntryJustificationDialogState();
}

class _OldEntryJustificationDialogState
    extends State<OldEntryJustificationDialog> {
  OldEntryJustification? _selectedJustification;

  String _getJustificationDisplay(
    OldEntryJustification justification,
    AppLocalizations l10n,
  ) {
    switch (justification) {
      case OldEntryJustification.enteredFromPaperRecords:
        return l10n.translate('justificationPaperRecords');
      case OldEntryJustification.rememberedSpecificEvent:
        return l10n.translate('justificationRemembered');
      case OldEntryJustification.estimatedEvent:
        return l10n.translate('justificationEstimated');
      case OldEntryJustification.other:
        return l10n.other;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.translate('oldEntryJustificationTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('oldEntryJustificationPrompt')),
          const SizedBox(height: 16),
          RadioGroup<OldEntryJustification>(
            groupValue: _selectedJustification,
            onChanged: (value) =>
                setState(() => _selectedJustification = value),
            child: Column(
              children: OldEntryJustification.values
                  .map(
                    (justification) => InkWell(
                      onTap: () => setState(
                        () => _selectedJustification = justification,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Radio<OldEntryJustification>(value: justification),
                            Expanded(
                              child: Text(
                                _getJustificationDisplay(justification, l10n),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _selectedJustification == null
              ? null
              : () => widget.onConfirm(_selectedJustification!),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

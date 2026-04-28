// Implements: REQ-p00006-A+B (offline-first patient data entry);
//   REQ-d00004-E+F+G (local-first writes via EntryService);
//   REQ-p01067-A+B+C (nosebleed UI). Three variants gated on
//   widgetConfig['variant']: absent = full form, 'no_epistaxis' /
//   'unknown_day' = marker-only.

import 'package:clinical_diary/entry_widgets/entry_widget_context.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Bespoke nosebleed entry form with three layout variants controlled by
/// [EntryWidgetContext.widgetConfig]['variant']:
///
///   * absent / null — full form: start time, end time, intensity, notes.
///   * `'no_epistaxis'` — marker-only: date display + confirm button.
///   * `'unknown_day'` — marker-only: same shape, different copy.
///
/// All writes go through [EntryWidgetContext.recorder]; no HTTP calls and no
/// references to the legacy nosebleed service are made here.
// Implements: REQ-p01067-A — render nosebleed UI variant driven by config.
// Implements: REQ-p01067-B — full form captures start, end, intensity, notes.
// Implements: REQ-p01067-C — marker variants capture date-only confirmation.
class EpistaxisFormWidget extends StatefulWidget {
  const EpistaxisFormWidget(this.ctx, {super.key});

  final EntryWidgetContext ctx;

  @override
  State<EpistaxisFormWidget> createState() => _EpistaxisFormWidgetState();
}

class _EpistaxisFormWidgetState extends State<EpistaxisFormWidget> {
  // -------------------------------------------------------------------------
  // State for the full-form variant
  // -------------------------------------------------------------------------
  late DateTime _startTime;
  DateTime? _endTime;
  NosebleedIntensity? _intensity;
  final TextEditingController _notesController = TextEditingController();

  bool _isSaving = false;

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String? get _variant => widget.ctx.widgetConfig['variant'] as String?;

  bool get _isMarkerOnly =>
      _variant == 'no_epistaxis' || _variant == 'unknown_day';

  bool get _isEditing => widget.ctx.initialAnswers != null;

  DateTime get _markerDate {
    final raw = widget.ctx.widgetConfig['date'];
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    if (raw is DateTime) return raw;
    // Fall back to initialAnswers['date'] if present, then today.
    final ia = widget.ctx.initialAnswers?['date'];
    if (ia is String) return DateTime.tryParse(ia) ?? DateTime.now();
    return DateTime.now();
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    final ia = widget.ctx.initialAnswers;
    if (ia != null) {
      // Pre-fill from existing answers.
      final rawStart = ia['startTime'];
      _startTime = rawStart is String
          ? (DateTime.tryParse(rawStart) ?? DateTime.now())
          : DateTime.now();

      final rawEnd = ia['endTime'];
      _endTime = rawEnd is String ? DateTime.tryParse(rawEnd) : null;

      final rawIntensity = ia['intensity'];
      if (rawIntensity is String) {
        _intensity = NosebleedIntensity.values
            .cast<NosebleedIntensity?>()
            .firstWhere((e) => e?.name == rawIntensity, orElse: () => null);
      }

      _notesController.text = (ia['notes'] as String?) ?? '';
    } else {
      _startTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Save / Delete
  // -------------------------------------------------------------------------

  Future<void> _save({required String? changeReason}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.ctx.recorder(
        entryType: widget.ctx.entryType,
        aggregateId: widget.ctx.aggregateId,
        eventType: 'finalized',
        answers: {
          'startTime': _startTime.toIso8601String(),
          if (_endTime != null) 'endTime': _endTime!.toIso8601String(),
          if (_intensity != null) 'intensity': _intensity!.name,
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
        },
        changeReason: changeReason,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmMarker() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.ctx.recorder(
        entryType: widget.ctx.entryType,
        aggregateId: widget.ctx.aggregateId,
        eventType: 'finalized',
        answers: {'date': _markerDate.toIso8601String()},
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete({required String changeReason}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.ctx.recorder(
        entryType: widget.ctx.entryType,
        aggregateId: widget.ctx.aggregateId,
        eventType: 'tombstone',
        answers: {},
        changeReason: changeReason,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // -------------------------------------------------------------------------
  // Delete dialog
  // -------------------------------------------------------------------------

  Future<void> _showDeleteDialog() async {
    final reason = await _DeleteReasonDialog.show(context);
    if (reason != null && mounted) {
      await _delete(changeReason: reason);
    }
  }

  // -------------------------------------------------------------------------
  // Change-reason dialog (for edits)
  // -------------------------------------------------------------------------

  Future<String?> _showChangeReasonDialog() {
    return _ChangeReasonDialog.show(context);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isMarkerOnly) {
      return _buildMarkerVariant(context);
    }
    return _buildFullForm(context);
  }

  // =========================================================================
  // Marker-only variant
  // =========================================================================

  Widget _buildMarkerVariant(BuildContext context) {
    final isNoEpistaxis = _variant == 'no_epistaxis';
    final title = isNoEpistaxis
        ? 'No nosebleeds today'
        : "Don't remember about today";
    final dateStr = DateFormat.yMMMMd().format(_markerDate);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            key: const Key('marker_title'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            dateStr,
            key: const Key('marker_date'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 40),
          FilledButton(
            key: const Key('confirm_button'),
            onPressed: _isSaving ? null : _confirmMarker,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Full-form variant
  // =========================================================================

  Widget _buildFullForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Start time ---------------------------------------------------
          Text(
            'Start time',
            key: const Key('start_time_label'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _TimePickerField(
            key: const Key('start_time_field'),
            label: 'Start time',
            value: _startTime,
            onChanged: (dt) => setState(() => _startTime = dt),
          ),
          const SizedBox(height: 20),

          // --- Intensity ----------------------------------------------------
          Text(
            'Intensity',
            key: const Key('intensity_label'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _IntensitySelector(
            key: const Key('intensity_selector'),
            selected: _intensity,
            onChanged: (v) => setState(() => _intensity = v),
          ),
          const SizedBox(height: 20),

          // --- End time (optional) -----------------------------------------
          Text(
            'End time (optional)',
            key: const Key('end_time_label'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _TimePickerField(
            key: const Key('end_time_field'),
            label: 'End time',
            value: _endTime,
            onChanged: (dt) => setState(() => _endTime = dt),
            optional: true,
          ),
          const SizedBox(height: 20),

          // --- Notes --------------------------------------------------------
          Text(
            'Notes (optional)',
            key: const Key('notes_label'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('notes_field'),
            controller: _notesController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Add any additional notes…',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),

          // --- Action buttons -----------------------------------------------
          FilledButton(
            key: const Key('save_button'),
            onPressed: _isSaving ? null : _onSaveTapped,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isEditing ? 'Save changes' : 'Save',
                    style: const TextStyle(fontSize: 18),
                  ),
          ),

          if (_isEditing) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('delete_button'),
              onPressed: _isSaving ? null : _showDeleteDialog,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              child: const Text('Delete', style: TextStyle(fontSize: 18)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onSaveTapped() async {
    String? changeReason;
    if (_isEditing) {
      changeReason = await _showChangeReasonDialog();
      if (changeReason == null) return; // user cancelled
      if (!mounted) return; // widget removed from tree while dialog was open
    }
    await _save(changeReason: changeReason);
  }
}

// ===========================================================================
// Private sub-widgets
// ===========================================================================

/// Simple inline time picker backed by [showTimePicker].
class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.onChanged,
    this.value,
    this.optional = false,
    super.key,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final displayText = value != null
        ? DateFormat.jm().format(value!)
        : (optional ? 'Not set' : 'Tap to set');

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final initial = value != null
            ? TimeOfDay.fromDateTime(value!)
            : TimeOfDay.fromDateTime(now);
        final picked = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (picked != null) {
          final base = value ?? now;
          onChanged(
            DateTime(
              base.year,
              base.month,
              base.day,
              picked.hour,
              picked.minute,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 20),
            const SizedBox(width: 8),
            Text(displayText, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// Horizontal intensity selector displaying all six [NosebleedIntensity] values.
class _IntensitySelector extends StatelessWidget {
  const _IntensitySelector({required this.onChanged, this.selected, super.key});

  final NosebleedIntensity? selected;
  final ValueChanged<NosebleedIntensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: NosebleedIntensity.values.map((intensity) {
        final isSelected = intensity == selected;
        return ChoiceChip(
          key: Key('intensity_${intensity.name}'),
          label: Text(intensity.displayName),
          selected: isSelected,
          onSelected: (_) => onChanged(intensity),
        );
      }).toList(),
    );
  }
}

// ===========================================================================
// Simple dialogs (no localization dependency for now — keys used in tests)
// ===========================================================================

class _DeleteReasonDialog extends StatefulWidget {
  const _DeleteReasonDialog();

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const _DeleteReasonDialog(),
    );
  }

  @override
  State<_DeleteReasonDialog> createState() => _DeleteReasonDialogState();
}

class _DeleteReasonDialogState extends State<_DeleteReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete record'),
      content: TextField(
        key: const Key('delete_reason_field'),
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Reason for deletion',
          border: OutlineInputBorder(),
        ),
        maxLines: 2,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('delete_confirm_button'),
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _ChangeReasonDialog extends StatefulWidget {
  const _ChangeReasonDialog();

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const _ChangeReasonDialog(),
    );
  }

  @override
  State<_ChangeReasonDialog> createState() => _ChangeReasonDialogState();
}

class _ChangeReasonDialogState extends State<_ChangeReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reason for change'),
      content: TextField(
        key: const Key('change_reason_field'),
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Why are you changing this record?',
          border: OutlineInputBorder(),
        ),
        maxLines: 2,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('change_reason_confirm_button'),
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

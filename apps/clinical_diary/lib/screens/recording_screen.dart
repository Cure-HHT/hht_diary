// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/widgets/severity_picker.dart';
import 'package:clinical_diary/widgets/time_picker_dial.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Recording flow screen for creating new nosebleed records
class RecordingScreen extends StatefulWidget {

  const RecordingScreen({
    required this.nosebleedService, super.key,
    this.initialDate,
    this.existingRecord,
  });
  final NosebleedService nosebleedService;
  final DateTime? initialDate;
  final NosebleedRecord? existingRecord;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

enum RecordingStep { startTime, severity, endTime, complete }

class _RecordingScreenState extends State<RecordingScreen> {
  late DateTime _date;
  DateTime? _startTime;
  DateTime? _endTime;
  NosebleedSeverity? _severity;

  RecordingStep _currentStep = RecordingStep.startTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();

    if (widget.existingRecord != null) {
      _startTime = widget.existingRecord!.startTime;
      _endTime = widget.existingRecord!.endTime;
      _severity = widget.existingRecord!.severity;
      _currentStep = _getInitialStepForExisting();
    } else {
      // Default start time to now
      _startTime = DateTime.now();
    }
  }

  RecordingStep _getInitialStepForExisting() {
    final record = widget.existingRecord!;
    if (record.severity == null) return RecordingStep.severity;
    if (record.endTime == null) return RecordingStep.endTime;
    return RecordingStep.complete;
  }

  String get _formattedDate => DateFormat('EEEE, MMMM d').format(_date);

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    return DateFormat('h:mm a').format(time);
  }

  int? get _durationMinutes {
    if (_startTime == null || _endTime == null) return null;
    return _endTime!.difference(_startTime!).inMinutes;
  }

  Future<void> _saveRecord() async {
    if (_startTime == null || _endTime == null || _severity == null) return;

    setState(() => _isSaving = true);

    try {
      await widget.nosebleedService.addRecord(
        date: _date,
        startTime: _startTime,
        endTime: _endTime,
        severity: _severity,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _goToStep(RecordingStep step) {
    setState(() => _currentStep = step);
  }

  void _handleStartTimeConfirm(DateTime time) {
    setState(() {
      _startTime = time;
      _currentStep = RecordingStep.severity;
    });
  }

  void _handleSeveritySelect(NosebleedSeverity severity) {
    setState(() {
      _severity = severity;
      _currentStep = RecordingStep.endTime;
      // Initialize end time to now if not set
      _endTime ??= DateTime.now();
    });
  }

  void _handleEndTimeConfirm(DateTime time) {
    // Validate end time is after start time
    if (_startTime != null && time.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() {
      _endTime = time;
      _currentStep = RecordingStep.complete;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ],
              ),
            ),

            // Date header
            Text(
              _formattedDate,
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 8),

            // Summary bar
            _buildSummaryBar(),

            const SizedBox(height: 16),

            // Main content area
            Expanded(
              child: _buildCurrentStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Start time
          _buildSummaryItem(
            label: 'Start',
            value: _formatTime(_startTime),
            isActive: _currentStep == RecordingStep.startTime,
            onTap: () => _goToStep(RecordingStep.startTime),
          ),

          _buildDivider(),

          // Severity
          _buildSummaryItem(
            label: 'Severity',
            value: _severity?.displayName ?? 'Select...',
            isActive: _currentStep == RecordingStep.severity,
            onTap: _startTime != null
                ? () => _goToStep(RecordingStep.severity)
                : null,
          ),

          _buildDivider(),

          // End time
          _buildSummaryItem(
            label: 'End',
            value: _formatTime(_endTime),
            isActive: _currentStep == RecordingStep.endTime,
            onTap: _severity != null
                ? () => _goToStep(RecordingStep.endTime)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case RecordingStep.startTime:
        return TimePickerDial(
          title: 'Nosebleed Start',
          initialTime: _startTime ?? DateTime.now(),
          onConfirm: _handleStartTimeConfirm,
          confirmLabel: 'Set Start Time',
        );

      case RecordingStep.severity:
        return SeverityPicker(
          selectedSeverity: _severity,
          onSelect: _handleSeveritySelect,
        );

      case RecordingStep.endTime:
        return TimePickerDial(
          title: 'Nosebleed End Time',
          initialTime: _endTime ?? DateTime.now(),
          onConfirm: _handleEndTimeConfirm,
          confirmLabel: 'Nosebleed Ended',
        );

      case RecordingStep.complete:
        return _buildCompleteStep();
    }
  }

  Widget _buildCompleteStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(height: 24),

          Text(
            'Record Complete',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 8),

          Text(
            'Tap any field above to edit it',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),

          if (_durationMinutes != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Duration: $_durationMinutes minutes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveRecord,
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
                  : const Text(
                      'Finished',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

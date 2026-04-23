import 'package:append_only_datastore_demo/app_state.dart';
import 'package:append_only_datastore_demo/demo_destination.dart';
import 'package:append_only_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

// Validated by: JNY-07 (Add destination with past startDate triggers replay).
class AddDestinationDialog extends StatefulWidget {
  const AddDestinationDialog({required this.appState, super.key});

  final AppState appState;

  @override
  State<AddDestinationDialog> createState() => _AddDestinationDialogState();
}

class _AddDestinationDialogState extends State<AddDestinationDialog> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _startDate = TextEditingController();
  bool _allowHardDelete = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _startDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DemoColors.bg,
      title: const Text(
        'Add destination',
        style: TextStyle(color: DemoColors.fg),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _id,
            style: const TextStyle(color: DemoColors.fg),
            decoration: const InputDecoration(
              labelText: 'id (required)',
              labelStyle: TextStyle(color: DemoColors.pending),
            ),
          ),
          Row(
            children: <Widget>[
              Checkbox(
                value: _allowHardDelete,
                onChanged: (v) => setState(() => _allowHardDelete = v ?? false),
              ),
              const Text(
                'allowHardDelete',
                style: TextStyle(color: DemoColors.fg),
              ),
            ],
          ),
          TextField(
            controller: _startDate,
            style: const TextStyle(color: DemoColors.fg),
            decoration: const InputDecoration(
              labelText: 'initialStartDate ISO-8601 (optional)',
              labelStyle: TextStyle(color: DemoColors.pending),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: DemoColors.red),
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: DemoColors.fg)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Add', style: TextStyle(color: DemoColors.accent)),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final id = _id.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'id is required');
      return;
    }
    DateTime? parsedStart;
    if (_startDate.text.isNotEmpty) {
      parsedStart = DateTime.tryParse(_startDate.text);
      if (parsedStart == null) {
        setState(() => _error = 'invalid startDate');
        return;
      }
    }
    try {
      final dest = DemoDestination(id: id, allowHardDelete: _allowHardDelete);
      await widget.appState.addDestination(dest);
      if (parsedStart != null) {
        await widget.appState.registry.setStartDate(id, parsedStart.toUtc());
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'add failed: $e');
    }
  }
}

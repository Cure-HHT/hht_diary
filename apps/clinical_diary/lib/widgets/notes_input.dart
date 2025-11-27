// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/material.dart';

/// Notes input widget for recording additional information
class NotesInput extends StatefulWidget {
  const NotesInput({
    required this.notes,
    required this.onNotesChange,
    required this.onBack,
    required this.onNext,
    this.isRequired = true,
    super.key,
  });

  final String notes;
  final ValueChanged<String> onNotesChange;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool isRequired;

  @override
  State<NotesInput> createState() => _NotesInputState();
}

class _NotesInputState extends State<NotesInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.notes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (widget.isRequired)
            Text(
              'Required for clinical trial participants',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Add any additional details about this nosebleed...',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: widget.onNotesChange,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed:
                      (!widget.isRequired || _controller.text.trim().isNotEmpty)
                      ? widget.onNext
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Next', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/dictionary_service.dart';
import '../services/user_service.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dictionaryService = DictionaryService();
  final _userService = UserService();

  final _hilagaynonController = TextEditingController();
  final _englishController = TextEditingController();
  final _pronunciationController = TextEditingController();
  final _exampleHilController = TextEditingController();
  final _exampleEngController = TextEditingController();
  final _notesController = TextEditingController();

  String? _partOfSpeech;
  bool _submitting = false;

  static const _partsOfSpeech = [
    'noun',
    'verb',
    'adjective',
    'adverb',
    'pronoun',
    'preposition',
    'conjunction',
    'interjection',
    'particle',
    'phrase',
  ];

  @override
  void dispose() {
    _hilagaynonController.dispose();
    _englishController.dispose();
    _pronunciationController.dispose();
    _exampleHilController.dispose();
    _exampleEngController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final userId = await _userService.getUserId();
    await _dictionaryService.addWord(
      hilagaynon: _hilagaynonController.text,
      english: _englishController.text,
      partOfSpeech: _partOfSpeech,
      pronunciation: _pronunciationController.text.isNotEmpty
          ? _pronunciationController.text
          : null,
      exampleHilagaynon: _exampleHilController.text.isNotEmpty
          ? _exampleHilController.text
          : null,
      exampleEnglish: _exampleEngController.text.isNotEmpty
          ? _exampleEngController.text
          : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      contributorId: userId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Word added! Salamat sa imo kontribusyon!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a Word')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Contribute to the dictionary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Add a Hilagaynon word with its English translation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            // Required fields
            TextFormField(
              controller: _hilagaynonController,
              decoration: const InputDecoration(
                labelText: 'Hilagaynon word *',
                border: OutlineInputBorder(),
                hintText: 'e.g. maayo',
              ),
              textCapitalization: TextCapitalization.none,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _englishController,
              decoration: const InputDecoration(
                labelText: 'English translation *',
                border: OutlineInputBorder(),
                hintText: 'e.g. good',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Part of speech
            DropdownButtonFormField<String>(
              initialValue: _partOfSpeech,
              decoration: const InputDecoration(
                labelText: 'Part of speech',
                border: OutlineInputBorder(),
              ),
              items: _partsOfSpeech
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _partOfSpeech = v),
            ),
            const SizedBox(height: 16),

            // Optional fields
            TextFormField(
              controller: _pronunciationController,
              decoration: const InputDecoration(
                labelText: 'Pronunciation guide',
                border: OutlineInputBorder(),
                hintText: 'e.g. ma-A-yo',
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _exampleHilController,
              decoration: const InputDecoration(
                labelText: 'Example sentence (Hilagaynon)',
                border: OutlineInputBorder(),
                hintText: 'e.g. Maayo ang adlaw.',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _exampleEngController,
              decoration: const InputDecoration(
                labelText: 'Example sentence (English)',
                border: OutlineInputBorder(),
                hintText: 'e.g. The day is good.',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                hintText: 'Regional variations, usage notes, etc.',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_submitting ? 'Submitting...' : 'Add Word'),
            ),
          ],
        ),
      ),
    );
  }
}

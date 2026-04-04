import 'package:flutter/material.dart';

import '../models/word_entry.dart';
import '../services/dictionary_service.dart';
import '../services/flashcard_service.dart';
import '../services/user_service.dart';

class WordDetailScreen extends StatefulWidget {
  final String wordId;

  const WordDetailScreen({super.key, required this.wordId});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final _dictionaryService = DictionaryService();
  final _flashcardService = FlashcardService();
  final _userService = UserService();

  WordEntry? _word;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWord();
  }

  Future<void> _loadWord() async {
    final word = await _dictionaryService.getWord(widget.wordId);
    if (mounted) {
      setState(() {
        _word = word;
        _loading = false;
      });
    }
  }

  Future<void> _addToStudyDeck() async {
    final userId = await _userService.getUserId();
    await _flashcardService.addToDeck(wordId: widget.wordId, userId: userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to your study deck!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _vote(bool up) async {
    if (up) {
      await _dictionaryService.upvote(widget.wordId);
    } else {
      await _dictionaryService.downvote(widget.wordId);
    }
    _loadWord();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_word == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Word not found')),
      );
    }

    final word = _word!;

    return Scaffold(
      appBar: AppBar(
        title: Text(word.hilagaynon),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            tooltip: 'Add to study deck',
            onPressed: _addToStudyDeck,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Main word card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.hilagaynon,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (word.pronunciation != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '/${word.pronunciation}/',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (word.partOfSpeech != null) ...[
                    const SizedBox(height: 8),
                    Chip(label: Text(word.partOfSpeech!)),
                  ],
                  const Divider(height: 24),
                  Text(word.english, style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          ),

          // Example sentences
          if (word.exampleHilagaynon != null ||
              word.exampleEnglish != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Example',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (word.exampleHilagaynon != null)
                      Text(
                        word.exampleHilagaynon!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (word.exampleEnglish != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        word.exampleEnglish!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Notes
          if (word.notes != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(word.notes!),
                  ],
                ),
              ),
            ),
          ],

          // Voting
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Is this accurate?'),
              const SizedBox(width: 16),
              IconButton.outlined(
                icon: const Icon(Icons.thumb_up_outlined),
                onPressed: () => _vote(true),
              ),
              const SizedBox(width: 4),
              Text('${word.upvotes}'),
              const SizedBox(width: 16),
              IconButton.outlined(
                icon: const Icon(Icons.thumb_down_outlined),
                onPressed: () => _vote(false),
              ),
              const SizedBox(width: 4),
              Text('${word.downvotes}'),
            ],
          ),
        ],
      ),
    );
  }
}

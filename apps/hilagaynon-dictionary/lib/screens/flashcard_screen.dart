import 'package:flutter/material.dart';

import '../models/flashcard_progress.dart';
import '../models/word_entry.dart';
import '../services/flashcard_service.dart';
import '../services/user_service.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final _flashcardService = FlashcardService();
  final _userService = UserService();

  List<FlashcardProgress> _dueCards = [];
  Map<String, WordEntry> _wordCache = {};
  int _currentIndex = 0;
  bool _loading = true;
  bool _showAnswer = false;
  bool _sessionComplete = false;

  @override
  void initState() {
    super.initState();
    _loadDueCards();
  }

  Future<void> _loadDueCards() async {
    final userId = await _userService.getUserId();
    final cards = await _flashcardService.getDueCards(userId: userId);

    // Pre-fetch all word entries
    final cache = <String, WordEntry>{};
    for (final card in cards) {
      final word = await _flashcardService.getWordForCard(card);
      if (word != null) {
        cache[card.wordId] = word;
      }
    }

    if (mounted) {
      setState(() {
        _dueCards = cards;
        _wordCache = cache;
        _loading = false;
        _sessionComplete = cards.isEmpty;
      });
    }
  }

  Future<void> _answer(int quality) async {
    final card = _dueCards[_currentIndex];
    await _flashcardService.recordReview(card: card, quality: quality);

    setState(() {
      _showAnswer = false;
      if (_currentIndex < _dueCards.length - 1) {
        _currentIndex++;
      } else {
        _sessionComplete = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn Words'),
        actions: [
          if (_dueCards.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentIndex + 1} / ${_dueCards.length}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessionComplete
          ? _buildCompleteView(theme)
          : _buildCardView(theme),
    );
  }

  Widget _buildCompleteView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _dueCards.isEmpty ? Icons.inbox_outlined : Icons.celebration,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _dueCards.isEmpty ? 'No cards to review' : 'Session complete!',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _dueCards.isEmpty
                  ? 'Search for words and add them to your study deck.'
                  : 'Maayo! Come back later for more review.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardView(ThemeData theme) {
    final card = _dueCards[_currentIndex];
    final word = _wordCache[card.wordId];

    if (word == null) {
      return const Center(child: Text('Word not found'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _dueCards.length,
          ),
          const SizedBox(height: 24),

          // Card
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = true),
              child: Card(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          word.hilagaynon,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (word.pronunciation != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '/${word.pronunciation}/',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_showAnswer) ...[
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            word.english,
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          if (word.exampleHilagaynon != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              word.exampleHilagaynon!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (word.exampleEnglish != null)
                              Text(
                                word.exampleEnglish!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ] else ...[
                          const SizedBox(height: 16),
                          Text(
                            'Tap to reveal',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Answer buttons
          if (_showAnswer) ...[
            const SizedBox(height: 16),
            Text(
              'How well did you know this?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _RatingButton(
                    label: 'Again',
                    color: Colors.red,
                    onTap: () => _answer(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingButton(
                    label: 'Hard',
                    color: Colors.orange,
                    onTap: () => _answer(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingButton(
                    label: 'Good',
                    color: Colors.green,
                    onTap: () => _answer(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingButton(
                    label: 'Easy',
                    color: Colors.blue,
                    onTap: () => _answer(5),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RatingButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

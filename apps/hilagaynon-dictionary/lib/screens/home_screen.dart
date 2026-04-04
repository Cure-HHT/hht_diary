import 'package:flutter/material.dart';

import '../services/dictionary_service.dart';
import '../services/flashcard_service.dart';
import '../services/user_service.dart';
import 'add_word_screen.dart';
import 'flashcard_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dictionaryService = DictionaryService();
  final _flashcardService = FlashcardService();
  final _userService = UserService();

  int _wordCount = 0;
  int _dueCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final userId = await _userService.getUserId();
    final wordCount = await _dictionaryService.getWordCount();
    final dueCount = await _flashcardService.getDueCount(userId);
    if (mounted) {
      setState(() {
        _wordCount = wordCount;
        _dueCount = dueCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hilagaynon Dictionary'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Hero section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Diksyunaryo nga Hiligaynon',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A community-built dictionary for the Hilagaynon language',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$_wordCount words',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action cards
            _ActionCard(
              icon: Icons.search,
              title: 'Search Dictionary',
              subtitle: 'Look up words in Hilagaynon or English',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.add_circle_outline,
              title: 'Contribute a Word',
              subtitle: 'Help grow the dictionary',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AddWordScreen(),
                  ),
                );
                _loadStats();
              },
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.school,
              title: 'Learn Words',
              subtitle: _dueCount > 0
                  ? '$_dueCount cards due for review'
                  : 'Practice with flashcards',
              badge: _dueCount > 0 ? '$_dueCount' : null,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const FlashcardScreen(),
                  ),
                );
                _loadStats();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

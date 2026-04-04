import 'dart:async';

import 'package:flutter/material.dart';

import '../models/word_entry.dart';
import '../services/dictionary_service.dart';
import 'word_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _dictionaryService = DictionaryService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<WordEntry> _results = [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() => _loading = true);
    final results = await _dictionaryService.searchWords(query);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
        _hasSearched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Dictionary')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type in Hilagaynon or English...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_hasSearched && _results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No words found',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('Try a different spelling or add this word!'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final word = _results[index];
                  return _WordListTile(
                    word: word,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => WordDetailScreen(wordId: word.id),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _WordListTile extends StatelessWidget {
  final WordEntry word;
  final VoidCallback onTap;

  const _WordListTile({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        word.hilagaynon,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(word.english),
      trailing: word.partOfSpeech != null
          ? Chip(
              label: Text(
                word.partOfSpeech!,
                style: const TextStyle(fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
            )
          : null,
      onTap: onTap,
    );
  }
}

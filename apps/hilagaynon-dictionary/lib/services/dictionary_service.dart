import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/word_entry.dart';

/// Service for CRUD operations on the shared Hilagaynon dictionary.
class DictionaryService {
  final FirebaseFirestore _firestore;
  static const _collection = 'words';
  static const _uuid = Uuid();

  DictionaryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _words =>
      _firestore.collection(_collection);

  /// Add a new word to the dictionary.
  Future<WordEntry> addWord({
    required String hilagaynon,
    required String english,
    String? partOfSpeech,
    String? pronunciation,
    String? exampleHilagaynon,
    String? exampleEnglish,
    String? notes,
    required String contributorId,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final entry = WordEntry(
      id: id,
      hilagaynon: hilagaynon.trim(),
      english: english.trim(),
      partOfSpeech: partOfSpeech?.trim(),
      pronunciation: pronunciation?.trim(),
      exampleHilagaynon: exampleHilagaynon?.trim(),
      exampleEnglish: exampleEnglish?.trim(),
      notes: notes?.trim(),
      contributorId: contributorId,
      createdAt: now,
      updatedAt: now,
      tags: tags,
    );

    await _words.doc(id).set(entry.toFirestore());
    return entry;
  }

  /// Search words by prefix in either Hilagaynon or English.
  Future<List<WordEntry>> searchWords(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return [];

    final lower = query.trim().toLowerCase();
    final upperBound = '$lower\uf8ff';

    // Search Hilagaynon
    final hilQuery = await _words
        .where('hilagaynonLower', isGreaterThanOrEqualTo: lower)
        .where('hilagaynonLower', isLessThanOrEqualTo: upperBound)
        .limit(limit)
        .get();

    // Search English
    final engQuery = await _words
        .where('englishLower', isGreaterThanOrEqualTo: lower)
        .where('englishLower', isLessThanOrEqualTo: upperBound)
        .limit(limit)
        .get();

    final Map<String, WordEntry> results = {};
    for (final doc in hilQuery.docs) {
      results[doc.id] = WordEntry.fromFirestore(doc);
    }
    for (final doc in engQuery.docs) {
      results[doc.id] = WordEntry.fromFirestore(doc);
    }

    final sorted = results.values.toList()
      ..sort((a, b) => a.hilagaynon.compareTo(b.hilagaynon));
    return sorted;
  }

  /// Get a single word by ID.
  Future<WordEntry?> getWord(String id) async {
    final doc = await _words.doc(id).get();
    if (!doc.exists) return null;
    return WordEntry.fromFirestore(doc);
  }

  /// Get recent words, ordered by creation date.
  Future<List<WordEntry>> getRecentWords({int limit = 20}) async {
    final snapshot = await _words
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(WordEntry.fromFirestore).toList();
  }

  /// Browse all words alphabetically with pagination.
  Future<List<WordEntry>> browseWords({
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _words.orderBy('hilagaynonLower').limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return snapshot.docs.map(WordEntry.fromFirestore).toList();
  }

  /// Upvote a word entry.
  Future<void> upvote(String wordId) async {
    await _words.doc(wordId).update({'upvotes': FieldValue.increment(1)});
  }

  /// Downvote a word entry.
  Future<void> downvote(String wordId) async {
    await _words.doc(wordId).update({'downvotes': FieldValue.increment(1)});
  }

  /// Get total word count.
  Future<int> getWordCount() async {
    final snapshot = await _words.count().get();
    return snapshot.count ?? 0;
  }
}

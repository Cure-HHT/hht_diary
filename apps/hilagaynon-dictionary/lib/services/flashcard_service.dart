import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/flashcard_progress.dart';
import '../models/word_entry.dart';

/// Manages spaced repetition flashcards for language learning.
class FlashcardService {
  final FirebaseFirestore _firestore;
  static const _collection = 'flashcard_progress';
  static const _wordsCollection = 'words';
  static const _uuid = Uuid();

  FlashcardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _progress =>
      _firestore.collection(_collection);

  /// Add a word to the user's study deck.
  Future<FlashcardProgress> addToDeck({
    required String wordId,
    required String userId,
  }) async {
    // Check if already in deck
    final existing = await _progress
        .where('wordId', isEqualTo: wordId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return FlashcardProgress.fromFirestore(existing.docs.first);
    }

    final id = _uuid.v4();
    final card = FlashcardProgress.initial(
      id: id,
      wordId: wordId,
      userId: userId,
    );
    await _progress.doc(id).set(card.toFirestore());
    return card;
  }

  /// Get cards due for review.
  Future<List<FlashcardProgress>> getDueCards({
    required String userId,
    int limit = 20,
  }) async {
    final now = DateTime.now();
    final snapshot = await _progress
        .where('userId', isEqualTo: userId)
        .where('nextReview', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('nextReview')
        .limit(limit)
        .get();

    return snapshot.docs.map(FlashcardProgress.fromFirestore).toList();
  }

  /// Record a review result and update the card's schedule.
  Future<FlashcardProgress> recordReview({
    required FlashcardProgress card,
    required int quality,
  }) async {
    final updated = card.review(quality);
    await _progress.doc(updated.id).set(updated.toFirestore());
    return updated;
  }

  /// Get the word entry for a flashcard.
  Future<WordEntry?> getWordForCard(FlashcardProgress card) async {
    final doc = await _firestore
        .collection(_wordsCollection)
        .doc(card.wordId)
        .get();
    if (!doc.exists) return null;
    return WordEntry.fromFirestore(doc);
  }

  /// Get total cards in user's deck.
  Future<int> getDeckSize(String userId) async {
    final snapshot = await _progress
        .where('userId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Get count of cards due for review.
  Future<int> getDueCount(String userId) async {
    final now = DateTime.now();
    final snapshot = await _progress
        .where('userId', isEqualTo: userId)
        .where('nextReview', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Remove a word from the user's study deck.
  Future<void> removeFromDeck({
    required String wordId,
    required String userId,
  }) async {
    final snapshot = await _progress
        .where('wordId', isEqualTo: wordId)
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}

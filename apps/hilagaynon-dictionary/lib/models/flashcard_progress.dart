import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks a user's spaced repetition progress for a single word.
/// Uses a simplified SM-2 algorithm.
class FlashcardProgress {
  final String id;
  final String wordId;
  final String userId;
  final int repetitions;
  final double easeFactor;
  final int intervalDays;
  final DateTime nextReview;
  final DateTime lastReview;

  const FlashcardProgress({
    required this.id,
    required this.wordId,
    required this.userId,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.intervalDays = 1,
    required this.nextReview,
    required this.lastReview,
  });

  factory FlashcardProgress.initial({
    required String id,
    required String wordId,
    required String userId,
  }) {
    final now = DateTime.now();
    return FlashcardProgress(
      id: id,
      wordId: wordId,
      userId: userId,
      nextReview: now,
      lastReview: now,
    );
  }

  factory FlashcardProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return FlashcardProgress(
      id: doc.id,
      wordId: data['wordId'] as String,
      userId: data['userId'] as String,
      repetitions: data['repetitions'] as int? ?? 0,
      easeFactor: (data['easeFactor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: data['intervalDays'] as int? ?? 1,
      nextReview: (data['nextReview'] as Timestamp).toDate(),
      lastReview: (data['lastReview'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'wordId': wordId,
      'userId': userId,
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'intervalDays': intervalDays,
      'nextReview': Timestamp.fromDate(nextReview),
      'lastReview': Timestamp.fromDate(lastReview),
    };
  }

  /// Apply SM-2 algorithm based on user's quality rating (0-5).
  /// 0-2 = forgot, 3 = hard, 4 = good, 5 = easy
  FlashcardProgress review(int quality) {
    final q = quality.clamp(0, 5);
    final now = DateTime.now();

    if (q < 3) {
      // Failed: reset repetitions, review again soon
      return FlashcardProgress(
        id: id,
        wordId: wordId,
        userId: userId,
        repetitions: 0,
        easeFactor: easeFactor,
        intervalDays: 1,
        nextReview: now.add(const Duration(minutes: 10)),
        lastReview: now,
      );
    }

    final newEase = (easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
        .clamp(1.3, 3.0);

    int newInterval;
    final newReps = repetitions + 1;

    if (newReps == 1) {
      newInterval = 1;
    } else if (newReps == 2) {
      newInterval = 6;
    } else {
      newInterval = (intervalDays * newEase).round();
    }

    return FlashcardProgress(
      id: id,
      wordId: wordId,
      userId: userId,
      repetitions: newReps,
      easeFactor: newEase,
      intervalDays: newInterval,
      nextReview: now.add(Duration(days: newInterval)),
      lastReview: now,
    );
  }
}

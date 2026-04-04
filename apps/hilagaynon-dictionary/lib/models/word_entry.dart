import 'package:cloud_firestore/cloud_firestore.dart';

/// A dictionary entry for a Hilagaynon word.
class WordEntry {
  final String id;
  final String hilagaynon;
  final String english;
  final String? partOfSpeech;
  final String? pronunciation;
  final String? exampleHilagaynon;
  final String? exampleEnglish;
  final String? notes;
  final String contributorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int upvotes;
  final int downvotes;
  final List<String> tags;

  const WordEntry({
    required this.id,
    required this.hilagaynon,
    required this.english,
    this.partOfSpeech,
    this.pronunciation,
    this.exampleHilagaynon,
    this.exampleEnglish,
    this.notes,
    required this.contributorId,
    required this.createdAt,
    required this.updatedAt,
    this.upvotes = 0,
    this.downvotes = 0,
    this.tags = const [],
  });

  factory WordEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return WordEntry(
      id: doc.id,
      hilagaynon: data['hilagaynon'] as String,
      english: data['english'] as String,
      partOfSpeech: data['partOfSpeech'] as String?,
      pronunciation: data['pronunciation'] as String?,
      exampleHilagaynon: data['exampleHilagaynon'] as String?,
      exampleEnglish: data['exampleEnglish'] as String?,
      notes: data['notes'] as String?,
      contributorId: data['contributorId'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      upvotes: data['upvotes'] as int? ?? 0,
      downvotes: data['downvotes'] as int? ?? 0,
      tags: List<String>.from(data['tags'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hilagaynon': hilagaynon,
      'hilagaynonLower': hilagaynon.toLowerCase(),
      'english': english,
      'englishLower': english.toLowerCase(),
      'partOfSpeech': partOfSpeech,
      'pronunciation': pronunciation,
      'exampleHilagaynon': exampleHilagaynon,
      'exampleEnglish': exampleEnglish,
      'notes': notes,
      'contributorId': contributorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'upvotes': upvotes,
      'downvotes': downvotes,
      'tags': tags,
    };
  }

  WordEntry copyWith({
    String? hilagaynon,
    String? english,
    String? partOfSpeech,
    String? pronunciation,
    String? exampleHilagaynon,
    String? exampleEnglish,
    String? notes,
    int? upvotes,
    int? downvotes,
    List<String>? tags,
  }) {
    return WordEntry(
      id: id,
      hilagaynon: hilagaynon ?? this.hilagaynon,
      english: english ?? this.english,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      pronunciation: pronunciation ?? this.pronunciation,
      exampleHilagaynon: exampleHilagaynon ?? this.exampleHilagaynon,
      exampleEnglish: exampleEnglish ?? this.exampleEnglish,
      notes: notes ?? this.notes,
      contributorId: contributorId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      tags: tags ?? this.tags,
    );
  }
}

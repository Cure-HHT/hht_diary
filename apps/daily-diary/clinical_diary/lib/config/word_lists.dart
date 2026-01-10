// Three-word token word lists for enrollment
// These are simple, memorable words that users can easily remember

/// First word list - animals
const List<String> wordList1 = [
  'bear',
  'bird',
  'cat',
  'deer',
  'dog',
  'duck',
  'eagle',
  'fish',
  'fox',
  'frog',
  'goat',
  'hawk',
  'horse',
  'lion',
  'owl',
  'panda',
  'rabbit',
  'seal',
  'tiger',
  'wolf',
];

/// Second word list - colors/adjectives
const List<String> wordList2 = [
  'blue',
  'brave',
  'bright',
  'calm',
  'clear',
  'cool',
  'fast',
  'golden',
  'green',
  'happy',
  'kind',
  'proud',
  'quiet',
  'red',
  'silver',
  'soft',
  'swift',
  'warm',
  'white',
  'wise',
];

/// Third word list - nature/objects
const List<String> wordList3 = [
  'beach',
  'cloud',
  'field',
  'flame',
  'forest',
  'garden',
  'hill',
  'island',
  'lake',
  'meadow',
  'moon',
  'mountain',
  'ocean',
  'river',
  'sky',
  'star',
  'stone',
  'stream',
  'sun',
  'valley',
];

/// Get all word lists
List<List<String>> getAllWordLists() => [wordList1, wordList2, wordList3];

/// Format three words as a token string
String formatThreeWordToken(String word1, String word2, String word3) {
  return '$word1-$word2-$word3'.toLowerCase();
}

/// Parse a token string into three words
List<String>? parseThreeWordToken(String token) {
  final parts = token.toLowerCase().split('-');
  if (parts.length != 3) return null;
  return parts;
}

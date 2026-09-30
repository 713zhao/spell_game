import 'dart:math';
import 'game_models.dart';
import '../utils/chinese_pronunciation.dart';

/// A short story split into sentences for the read-aloud game.
class ReadingStory {
  final String title;
  final bool chinese;
  final List<String> sentences;
  // Spelling stories map each sentence back to the word it practices (by
  // index into [sentences]); null for pre-written stories.
  final Map<int, Word> wordForSentence;

  const ReadingStory({
    required this.title,
    required this.chinese,
    required this.sentences,
    this.wordForSentence = const {},
  });
}

const _presetEnglish = [
  ReadingStory(
    title: 'The Flying Dog',
    chinese: false,
    sentences: [
      'A little dog had a pair of big white wings.',
      'Every morning he flew high above the blue sea.',
      'The waves sparkled like silver in the bright sun.',
      'He waved hello to the seagulls and the fishing boats.',
      'When he read aloud, his wings grew strong and he flew higher.',
      'At sunset he landed on the sand and smiled happily.',
    ],
  ),
  ReadingStory(
    title: 'The Brave Little Boat',
    chinese: false,
    sentences: [
      'A small red boat sailed out on a windy day.',
      'The waves were big but the boat was brave.',
      'It sang a song to keep its courage up.',
      'Soon the storm passed and the sky turned golden.',
      'The little boat sailed safely home.',
    ],
  ),
];

const _presetChinese = [
  ReadingStory(
    title: '会飞的小狗',
    chinese: true,
    sentences: [
      '有一只小狗，背上长着一对白色的翅膀。',
      '每天早上，它都飞到蓝蓝的大海上面。',
      '海浪在阳光下闪闪发光。',
      '它向海鸥和小渔船挥手问好。',
      '大声朗读的时候，它的翅膀就更有力量。',
      '傍晚，它开心地飞回了沙滩。',
    ],
  ),
  ReadingStory(
    title: '勇敢的小船',
    chinese: true,
    sentences: [
      '一只红色的小船在大风天出海了。',
      '海浪很大，可是小船很勇敢。',
      '它唱着歌，给自己加油。',
      '风雨过去了，天空变成了金色。',
      '小船平平安安地回到了家。',
    ],
  ),
];

/// A random pre-written story in the requested language.
ReadingStory presetStory(bool chinese, {Random? random}) {
  final list = chinese ? _presetChinese : _presetEnglish;
  return list[(random ?? Random()).nextInt(list.length)];
}

const _englishTemplates = [
  'The flying dog saw a {w} by the sea.',
  'Can you spell the word {w} out loud?',
  'Over the waves, the dog whispered the word {w}.',
  'She said the word {w} and the dog flew higher.',
];

const _chineseTemplates = [
  '小狗飞过大海，看见了{w}。',
  '海风吹来，小狗轻轻地说：{w}。',
  '我们一起大声读：{w}。',
  '飞呀飞，小狗在海面上想起了{w}。',
];

/// Builds a story from the player's own practicing words: one sentence per
/// word (up to [maxWords]) so reading it aloud rehearses their spelling
/// list. Returns null if there are no usable words of that language.
ReadingStory? buildSpellingStory(
  List<Word> words, {
  required bool chinese,
  int maxWords = 6,
  Random? random,
}) {
  final rng = random ?? Random();
  final lang = chinese ? 'chinese' : 'english';
  final seen = <String>{};
  final usable = words
      .where((w) => w.language == lang && seen.add(w.text))
      .toList()
    ..shuffle(rng);
  if (usable.isEmpty) return null;
  final picked = usable.take(maxWords).toList();
  final templates = chinese ? _chineseTemplates : _englishTemplates;
  final sentences = <String>[];
  final map = <int, Word>{};
  for (var i = 0; i < picked.length; i++) {
    final t = templates[(i + rng.nextInt(templates.length)) % templates.length];
    sentences.add(t.replaceFirst('{w}', picked[i].text));
    map[i] = picked[i];
  }
  return ReadingStory(
    title: chinese ? '我的拼写故事' : 'My Spelling Story',
    chinese: chinese,
    sentences: sentences,
    wordForSentence: map,
  );
}

/// The units the reader must say: whole words for English, characters for
/// Chinese.
List<String> readingUnits(String sentence, {required bool chinese}) {
  if (chinese) {
    return sentence.split('').where(_isHan).toList();
  }
  return RegExp(r"[A-Za-z']+")
      .allMatches(sentence)
      .map((m) => m.group(0)!.toLowerCase())
      .toList();
}

bool _isHan(String ch) {
  final c = ch.codeUnitAt(0);
  return c >= 0x4E00 && c <= 0x9FFF;
}

/// For each unit, whether the [transcript] contains it. English compares
/// normalized words; Chinese accepts the exact character or a homophone
/// (speech recognition often writes a different character for the same
/// sound).
List<bool> unitsRead(
  List<String> units,
  String transcript, {
  required bool chinese,
}) {
  if (transcript.trim().isEmpty) return List.filled(units.length, false);
  if (chinese) {
    return [for (final u in units) rateChineseReading(u, transcript) >= 2];
  }
  final spoken = RegExp(r"[A-Za-z']+")
      .allMatches(transcript)
      .map((m) => m.group(0)!.toLowerCase())
      .toList();
  // Each spoken word can satisfy only one unit, so a repeated target word
  // must actually be said repeatedly.
  final pool = List<String>.from(spoken);
  return [
    for (final u in units)
      if (pool.remove(u)) true else false,
  ];
}

/// Fraction of [read] that is true (0 for an empty list).
double readCoverage(List<bool> read) =>
    read.isEmpty ? 0 : read.where((b) => b).length / read.length;

/// A sentence counts as read once this share of it was recognized.
const double readPassThreshold = 0.7;

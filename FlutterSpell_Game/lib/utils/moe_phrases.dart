import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Example 词语 (common words) for each MOE character, shown and read aloud
/// on the back of a word card. Static asset: assets/data/moe_phrases.json
/// ({"字": ["词一", "词二"]}); characters without an entry just get none.
class MoePhrases {
  MoePhrases._();

  static Map<String, List<String>>? _cache;
  static Future<void>? _loading;

  /// Loads the asset once; safe to call repeatedly.
  static Future<void> ensureLoaded() {
    if (_cache != null) return Future.value();
    return _loading ??= () async {
      try {
        final raw = await rootBundle.loadString('assets/data/moe_phrases.json');
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _cache = json.map(
          (k, v) => MapEntry(k, (v as List).cast<String>()),
        );
      } catch (_) {
        _cache = {};
      }
    }();
  }

  /// Up to two words for [character]; empty until [ensureLoaded] completes
  /// or when the character has none.
  static List<String> forCharacter(String character) =>
      _cache?[character] ?? const [];

  /// What to read aloud when the card turns to its back: the character,
  /// then its words, with commas so speech pauses between them.
  static String readAloudText(String character) =>
      [character, ...forCharacter(character)].join('，');
}

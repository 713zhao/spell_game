/// Words up to this many Chinese characters are handwritten in full; longer
/// text (a dictation sentence) only asks for its hardest characters.
const int maxHandwriteChars = 4;

/// How many of a sentence's characters the child handwrites.
const int maxKeyChars = 3;

bool isCjkChar(String ch) => RegExp(r'[一-鿿]').hasMatch(ch);

/// The Chinese characters of [text] in order, dropping punctuation, Latin
/// letters and spaces (none of which can be traced).
List<String> cjkChars(String text) => text.split('').where(isCjkChar).toList();

/// Picks which characters of [chars] the child should handwrite.
///
/// Short words come back whole. For a sentence, the [maxKeyChars] characters
/// with the most strokes (per [strokeCounts]) are chosen - more strokes is
/// the best cheap proxy for "hard to write" - and a character that repeats
/// (的 twice) is only asked once. Characters without a stroke count rank
/// last, so with no data at all the first few are used. The result keeps
/// sentence order, so it reads left-to-right.
List<String> pickKeyChars(List<String> chars, Map<String, int> strokeCounts) {
  if (chars.length <= maxHandwriteChars) return List.of(chars);

  final seen = <String>{};
  final candidates = <int>[
    for (var i = 0; i < chars.length; i++)
      if (seen.add(chars[i])) i,
  ];
  // List.sort isn't stable, so break stroke-count ties on position.
  candidates.sort((a, b) {
    final byStrokes = (strokeCounts[chars[b]] ?? 0).compareTo(
      strokeCounts[chars[a]] ?? 0,
    );
    return byStrokes != 0 ? byStrokes : a.compareTo(b);
  });
  final picked = candidates.take(maxKeyChars).toList()..sort();
  return [for (final i in picked) chars[i]];
}

/// True when [typed] contains the same Chinese characters as [target],
/// ignoring punctuation, spaces and Latin letters - a child typing a
/// sentence shouldn't be marked wrong for a missing "，".
bool typedMatchesTarget(String typed, String target) =>
    cjkChars(typed).join() == cjkChars(target).join();

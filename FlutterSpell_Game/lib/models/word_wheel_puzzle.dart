import 'dart:math';
import 'game_models.dart';

/// One target word's placement on the crossword grid.
class PlacedWord {
  final Word word;
  final String text; // uppercase, letters only
  final bool horizontal;
  final int row; // top-left cell
  final int col;
  // Positions already filled in as free clues (see [scaffoldReveals]) - a
  // longer word gets more of these, so the number of letters the player
  // actually has to trace stays roughly constant regardless of length.
  final Set<int> revealedIndices;

  PlacedWord({
    required this.word,
    required this.text,
    required this.horizontal,
    required this.row,
    required this.col,
    this.revealedIndices = const {},
  });

  /// The (row, col) of every letter, in order.
  List<Point<int>> get cells => [
    for (var i = 0; i < text.length; i++)
      horizontal ? Point(row, col + i) : Point(row + i, col),
  ];

  /// The (row, col) of only the not-pre-revealed letters, in order - what
  /// the player actually needs to trace.
  List<Point<int>> get blankCells => [
    for (var i = 0; i < text.length; i++)
      if (!revealedIndices.contains(i)) cells[i],
  ];

  /// The letters the player needs to trace, in position order, skipping
  /// any pre-revealed ones.
  String get blankLetters => [
    for (var i = 0; i < text.length; i++)
      if (!revealedIndices.contains(i)) text[i],
  ].join();
}

/// At most [maxBlanks] letters of [word] are left for the player to supply;
/// the rest are pre-revealed, spread evenly across the word (so a long word
/// reads as "a few gaps to fill in a clue" rather than "spell this whole
/// thing blind"). Short words (length <= maxBlanks) get no scaffolding at
/// all - the full word is still a fair, single-tier challenge.
Set<int> scaffoldReveals(String word, {int maxBlanks = 4}) {
  final length = word.length;
  final revealCount = length - min(length, maxBlanks);
  if (revealCount <= 0) return {};
  final revealed = <int>{};
  final step = length / (revealCount + 1);
  for (var k = 1; k <= revealCount; k++) {
    revealed.add((step * k).round().clamp(0, length - 1));
  }
  return revealed;
}

/// A Words-of-Wonders-style puzzle built from a handful of the player's own
/// currently-practicing words: a crossword grid of the words that overlap
/// enough to interlock, plus a letter wheel (a multiset of tiles covering
/// every still-blank letter any target word needs - see [scaffoldReveals])
/// to trace them out with.
///
/// Unlike the real game this isn't backed by a dictionary - "bonus" words
/// aren't offered, and only the selected target words themselves count as
/// valid finds, so no separate word-validity list is needed.
class WordWheelPuzzle {
  final List<String> wheelLetters; // shuffled tiles, may repeat a letter
  final List<PlacedWord> placedWords;
  final int rows;
  final int cols;

  WordWheelPuzzle({
    required this.wheelLetters,
    required this.placedWords,
    required this.rows,
    required this.cols,
  });

  /// The target word whose still-blank letters [traced] spells out
  /// (case-insensitive), if any and not already in [found]. Pre-revealed
  /// letters (see [scaffoldReveals]) aren't part of what's traced.
  PlacedWord? matchTarget(String traced, Set<String> found) {
    final upper = traced.toUpperCase();
    for (final p in placedWords) {
      if (p.blankLetters == upper && !found.contains(p.text)) return p;
    }
    return null;
  }

  static final RegExp _lettersOnly = RegExp(r'^[A-Za-z]+$');

  /// Builds a puzzle from [pool] (e.g. the player's deck), or null if there
  /// aren't enough usable words (English, letters-only, 3-8 long) to make
  /// an interesting one - the caller should then widen its word pool (see
  /// WordSnakeScreen's quiz-pool fallback) and retry.
  static WordWheelPuzzle? build(List<Word> pool, {Random? random}) {
    final rng = random ?? Random();

    final seen = <String>{};
    final candidates = <Word>[];
    for (final w in pool) {
      if (w.language != 'english') continue;
      final text = w.text.trim();
      if (text.length < 3 || text.length > 8) continue;
      if (!_lettersOnly.hasMatch(text)) continue;
      final upper = text.toUpperCase();
      if (!seen.add(upper)) continue;
      candidates.add(w);
    }
    if (candidates.length < 4) return null;

    candidates.shuffle(rng);
    candidates.sort((a, b) => b.text.length.compareTo(a.text.length));

    List<Word>? pickTargets(int maxUnionLetters, int maxWords) {
      final chosen = <Word>[];
      final union = <String>{};
      for (final w in candidates) {
        final letters = w.text.toUpperCase().split('').toSet();
        final grown = union.union(letters);
        if (grown.length <= maxUnionLetters) {
          chosen.add(w);
          union.addAll(letters);
          if (chosen.length >= maxWords) break;
        }
      }
      return chosen.length >= 4 ? chosen : null;
    }

    final targets =
        pickTargets(9, 7) ?? pickTargets(12, 8) ?? pickTargets(16, 9);
    if (targets == null) return null;

    // A longer word gets more of its letters pre-revealed as free clues,
    // so the number of letters actually left to trace stays small and
    // roughly constant no matter how long the word is.
    final revealsByWord = <Word, Set<int>>{
      for (final w in targets) w: scaffoldReveals(w.text.toUpperCase()),
    };

    // Wheel tiles: for each letter, enough copies to spell whichever
    // target word's still-blank letters use it the most - pre-revealed
    // letters don't need a tile, which is what keeps the wheel small even
    // for a long, mostly-scaffolded word.
    final tileCounts = <String, int>{};
    for (final w in targets) {
      final blanks = [
        for (var i = 0; i < w.text.length; i++)
          if (!revealsByWord[w]!.contains(i)) w.text[i].toUpperCase(),
      ];
      final counts = <String, int>{};
      for (final ch in blanks) {
        counts[ch] = (counts[ch] ?? 0) + 1;
      }
      counts.forEach((letter, count) {
        if (count > (tileCounts[letter] ?? 0)) tileCounts[letter] = count;
      });
    }
    final tiles = <String>[
      for (final entry in tileCounts.entries)
        for (var i = 0; i < entry.value; i++) entry.key,
    ]..shuffle(rng);

    // Crossword placement: longest word first, anchored at the origin;
    // every later word tries to cross an already-placed letter, falling
    // back to its own isolated row if no crossing fits.
    final byLength = [...targets]
      ..sort((a, b) => b.text.length.compareTo(a.text.length));

    final grid = <Point<int>, String>{};
    final lettersAt = <String, List<Point<int>>>{};
    final placed = <PlacedWord>[];
    var isolatedRow = 0;

    bool fits(List<Point<int>> cells, List<String> letters) {
      for (var i = 0; i < cells.length; i++) {
        final existing = grid[cells[i]];
        if (existing != null && existing != letters[i]) return false;
      }
      return true;
    }

    void place(Word word, bool horizontal, int row, int col) {
      final text = word.text.toUpperCase();
      final p = PlacedWord(
        word: word,
        text: text,
        horizontal: horizontal,
        row: row,
        col: col,
        revealedIndices: revealsByWord[word] ?? const {},
      );
      for (var i = 0; i < text.length; i++) {
        final cell = p.cells[i];
        grid[cell] = text[i];
        lettersAt.putIfAbsent(text[i], () => []).add(cell);
      }
      placed.add(p);
      isolatedRow = max(isolatedRow, row + (horizontal ? 1 : text.length) + 1);
    }

    for (final word in byLength) {
      final text = word.text.toUpperCase();
      if (placed.isEmpty) {
        place(word, true, 0, 0);
        continue;
      }
      var done = false;
      for (var i = 0; i < text.length && !done; i++) {
        final options = lettersAt[text[i]];
        if (options == null) continue;
        for (final anchor in options) {
          // Horizontal: text[i] lands on anchor.
          final hCells = [
            for (var j = 0; j < text.length; j++)
              Point(anchor.x, anchor.y - i + j),
          ];
          if (fits(hCells, text.split(''))) {
            place(word, true, anchor.x, anchor.y - i);
            done = true;
            break;
          }
          // Vertical.
          final vCells = [
            for (var j = 0; j < text.length; j++)
              Point(anchor.x - i + j, anchor.y),
          ];
          if (fits(vCells, text.split(''))) {
            place(word, false, anchor.x - i, anchor.y);
            done = true;
            break;
          }
        }
      }
      if (!done) {
        place(word, true, isolatedRow, 0);
      }
    }

    final minRow = placed.map((p) => p.cells.first.x).reduce(min);
    final minCol = placed
        .expand((p) => p.cells)
        .map((c) => c.y)
        .reduce(min);
    final normalized = [
      for (final p in placed)
        PlacedWord(
          word: p.word,
          text: p.text,
          horizontal: p.horizontal,
          row: p.row - minRow,
          col: p.col - minCol,
          revealedIndices: p.revealedIndices,
        ),
    ];
    final maxRow = normalized
        .expand((p) => p.cells)
        .map((c) => c.x)
        .reduce(max);
    final maxCol = normalized
        .expand((p) => p.cells)
        .map((c) => c.y)
        .reduce(max);

    return WordWheelPuzzle(
      wheelLetters: tiles,
      placedWords: normalized,
      rows: maxRow + 1,
      cols: maxCol + 1,
    );
  }
}

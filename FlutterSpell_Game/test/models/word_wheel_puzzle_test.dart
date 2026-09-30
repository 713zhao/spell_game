import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/models/word_wheel_puzzle.dart';

Word _w(int id, String text, {String language = 'english'}) =>
    Word(id: id, text: text, language: language);

// A snapshot of real P1-level spelling words (from the shared dev DB), used
// to fuzz-test the crossword generator against realistic, mostly
// letter-disjoint input rather than only hand-picked overlapping words.
final _realWords = [_w(29, 'compared'), _w(30, 'healthy'), _w(31, 'vibrant'), _w(32, 'absorb'), _w(34, 'digest'), _w(35, 'blink'), _w(36, 'trapped'), _w(37, 'vitamins'), _w(43, 'parasite'), _w(45, 'enormous'), _w(48, 'unusual'), _w(50, 'attracts'), _w(51, 'adapted'), _w(52, 'rotting'), _w(58, 'croaked'), _w(59, 'leaned'), _w(60, 'shrugged'), _w(61, 'flopped'), _w(62, 'squeaked'), _w(63, 'poked'), _w(64, 'snatched'), _w(65, 'shoved'), _w(66, 'wriggled'), _w(67, 'slid'), _w(73, 'edge'), _w(74, 'breath'), _w(75, 'exist'), _w(76, 'trapdoor'), _w(77, 'dessert'), _w(79, 'unlocked'), _w(80, 'hammer'), _w(81, 'biscuits'), _w(82, 'scrawny'), _w(89, 'because'), _w(103, 'believe'), _w(104, 'treasure'), _w(105, 'tickets'), _w(106, 'received'), _w(110, 'tomorrow'), _w(605, 'warily'), _w(606, 'bounced'), _w(607, 'hollow'), _w(608, 'squeezed'), _w(609, 'peered'), _w(610, 'desired'), _w(611, 'filthy'), _w(612, 'keenly'), _w(613, 'slimy'), _w(614, 'promised'), _w(621, 'opposite'), _w(622, 'weapons'), _w(626, 'disaster'), _w(629, 'managed'), _w(1283, 'examined'), _w(1284, 'grooves'), _w(1286, 'stressed'), _w(1287, 'mongrel'), _w(1292, 'assured'), _w(1298, 'menacing'), _w(1302, 'shrieked'), _w(1304, 'gestured'), _w(1312, 'strategy'), _w(1313, 'athletes'), _w(1318, 'immobile'), _w(1319, 'signify'), _w(1514, 'water'), _w(1665, 'means'), _w(1666, 'told'), _w(1667, 'visit'), _w(1668, 'home'), _w(1669, 'moved'), _w(1670, 'tried'), _w(1671, 'changed'), _w(1672, 'paid'), _w(1673, 'busy'), _w(1674, 'birthday')];

void main() {
  group('WordWheelPuzzle.build', () {
    test('returns null when there are too few usable words', () {
      final pool = [_w(1, 'cat'), _w(2, 'dog'), _w(3, 'a')];
      expect(WordWheelPuzzle.build(pool), isNull);
    });

    test('ignores non-english and non-alphabetic entries', () {
      final pool = [
        _w(1, 'cat'),
        _w(2, 'dog'),
        _w(3, 'car'),
        _w(4, 'card'),
        _w(5, '猫', language: 'chinese'),
        _w(6, "don't"),
      ];
      final puzzle = WordWheelPuzzle.build(pool, random: Random(1));
      expect(puzzle, isNotNull);
      final texts = puzzle!.placedWords.map((p) => p.text).toSet();
      expect(texts.contains('猫'), isFalse);
      expect(texts.contains("DON'T"), isFalse);
    });

    test('every placed word is fully connected with no letter conflicts', () {
      final pool = [
        _w(1, 'cat'),
        _w(2, 'car'),
        _w(3, 'cart'),
        _w(4, 'art'),
        _w(5, 'rat'),
        _w(6, 'tar'),
      ];
      final puzzle = WordWheelPuzzle.build(pool, random: Random(42));
      expect(puzzle, isNotNull);
      expect(puzzle!.placedWords.length, greaterThanOrEqualTo(4));

      final grid = <Point<int>, String>{};
      for (final p in puzzle.placedWords) {
        final cells = p.cells;
        expect(cells.length, p.text.length);
        for (var i = 0; i < cells.length; i++) {
          final existing = grid[cells[i]];
          if (existing != null) {
            expect(existing, p.text[i], reason: 'conflicting overlap');
          }
          grid[cells[i]] = p.text[i];
          expect(cells[i].x, inInclusiveRange(0, puzzle.rows - 1));
          expect(cells[i].y, inInclusiveRange(0, puzzle.cols - 1));
        }
      }
    });

    test('wheel tiles can spell every placed word', () {
      final pool = [
        _w(1, 'cat'),
        _w(2, 'car'),
        _w(3, 'cart'),
        _w(4, 'art'),
        _w(5, 'rat'),
        _w(6, 'tar'),
      ];
      final puzzle = WordWheelPuzzle.build(pool, random: Random(7));
      expect(puzzle, isNotNull);
      final tileCounts = <String, int>{};
      for (final t in puzzle!.wheelLetters) {
        tileCounts[t] = (tileCounts[t] ?? 0) + 1;
      }
      for (final p in puzzle.placedWords) {
        final needed = <String, int>{};
        for (final ch in p.text.split('')) {
          needed[ch] = (needed[ch] ?? 0) + 1;
        }
        needed.forEach((letter, count) {
          expect(
            tileCounts[letter] ?? 0,
            greaterThanOrEqualTo(count),
            reason: '$letter for ${p.text}',
          );
        });
      }
    });

    test(
      'builds a valid puzzle from a real, mostly letter-disjoint word set '
      'across many seeds without crashing',
      () {
        for (var seed = 0; seed < 30; seed++) {
          final puzzle = WordWheelPuzzle.build(
            _realWords,
            random: Random(seed),
          );
          if (puzzle == null) continue; // a valid outcome too
          expect(puzzle.placedWords.length, greaterThanOrEqualTo(4));
          final grid = <Point<int>, String>{};
          for (final p in puzzle.placedWords) {
            for (var i = 0; i < p.cells.length; i++) {
              final existing = grid[p.cells[i]];
              if (existing != null) expect(existing, p.text[i]);
              grid[p.cells[i]] = p.text[i];
            }
          }
        }
      },
    );

    test('matchTarget only matches an unfound placed word, case-insensitively', () {
      final pool = [
        _w(1, 'cat'),
        _w(2, 'car'),
        _w(3, 'cart'),
        _w(4, 'art'),
        _w(5, 'rat'),
      ];
      final puzzle = WordWheelPuzzle.build(pool, random: Random(3));
      expect(puzzle, isNotNull);
      final first = puzzle!.placedWords.first;
      expect(
        puzzle.matchTarget(first.blankLetters.toLowerCase(), {}),
        isNotNull,
      );
      expect(
        puzzle.matchTarget(first.blankLetters, {first.text}),
        isNull,
        reason: 'already found',
      );
      expect(puzzle.matchTarget('zzzzz', {}), isNull);
    });
  });

  group('scaffoldReveals', () {
    test('reveals nothing for a word at or under the blank cap', () {
      expect(scaffoldReveals('CAT'), isEmpty);
      expect(scaffoldReveals('WORD'), isEmpty); // exactly maxBlanks (4)
    });

    test('caps the number of letters left blank on longer words', () {
      // 8 letters, default maxBlanks 4 -> 4 revealed, 4 left blank.
      final revealed = scaffoldReveals('ELEPHANT');
      expect(revealed.length, 4);
      expect(revealed.every((i) => i >= 0 && i < 8), isTrue);
    });

    test('spreads revealed positions instead of clustering them', () {
      final revealed = scaffoldReveals('ELEPHANT').toList()..sort();
      // No two revealed positions should be identical (a poor spread could
      // round to the same index) and they should span more than one spot.
      expect(revealed.toSet().length, revealed.length);
      expect(revealed.first, lessThan(revealed.last));
    });
  });

  group('scaffolding integration', () {
    test('a long word keeps only maxBlanks letters traceable, the rest pre-revealed', () {
      final pool = [
        _w(1, 'elephant'), // 8 letters -> 4 blanks, 4 revealed
        _w(2, 'cat'),
        _w(3, 'dog'),
        _w(4, 'sun'),
      ];
      final puzzle = WordWheelPuzzle.build(pool, random: Random(5));
      expect(puzzle, isNotNull);
      final elephant = puzzle!.placedWords.firstWhere(
        (p) => p.text == 'ELEPHANT',
      );
      expect(elephant.revealedIndices.length, 4);
      expect(elephant.blankLetters.length, 4);
      expect(elephant.blankCells.length, 4);

      // The wheel only needs tiles for the blank letters, not the whole
      // word - so it must NOT necessarily contain enough tiles to spell
      // the full 8-letter word, but must always cover the blanks.
      final tileCounts = <String, int>{};
      for (final t in puzzle.wheelLetters) {
        tileCounts[t] = (tileCounts[t] ?? 0) + 1;
      }
      final blankCounts = <String, int>{};
      for (final ch in elephant.blankLetters.split('')) {
        blankCounts[ch] = (blankCounts[ch] ?? 0) + 1;
      }
      blankCounts.forEach((letter, count) {
        expect(tileCounts[letter] ?? 0, greaterThanOrEqualTo(count));
      });

      // Tracing just the blank letters (in order) must complete the word.
      expect(puzzle.matchTarget(elephant.blankLetters, {}), isNotNull);
    });
  });
}

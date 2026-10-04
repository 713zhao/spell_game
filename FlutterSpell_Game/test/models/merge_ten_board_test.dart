import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/merge_ten_board.dart';

void main() {
  test('matches on same number or sum of 10', () {
    expect(MergeTenBoard.matches(3, 3), isTrue);
    expect(MergeTenBoard.matches(4, 6), isTrue);
    expect(MergeTenBoard.matches(4, 5), isFalse);
    expect(MergeTenBoard.matches(0, 0), isFalse);
  });

  test('drop stacks, clears pair, gravity settles', () {
    final b = MergeTenBoard();
    b.drop(0, 7);
    b.drop(1, 3); // 7+3 side by side on the bottom row
    b.drop(1, 2); // sits on top of the 3
    expect(b.clearMatches(), 1);
    b.applyGravity();
    expect(b.cells[MergeTenBoard.rows - 1][0], 0);
    expect(b.cells[MergeTenBoard.rows - 1][1], 2);
  });

  seedTest();
  test('column fills up', () {
    final b = MergeTenBoard();
    for (var i = 0; i < MergeTenBoard.rows; i++) {
      expect(b.drop(2, i % 2 == 0 ? 1 : 2), greaterThanOrEqualTo(0));
    }
    expect(b.isColumnFull(2), isTrue);
    expect(b.drop(2, 1), -1);
  });
}

void seedTest() {
  test('seed fills bottom rows with nothing to clear', () {
    for (var i = 0; i < 50; i++) {
      final b = MergeTenBoard()..seed(Random(i));
      expect(b.cells[MergeTenBoard.rows - 1].every((v) => v != 0), isTrue);
      expect(b.cells[0].every((v) => v == 0), isTrue);
      expect(b.clearMatches(), 0);
    }
  });
}

import 'dart:math';

/// Board logic for Merge Ten, a merge-fruit-style drop game: number tiles
/// (1-9) fall down columns, and two touching tiles disappear when they show
/// the same number or add up to 10. Gravity then pulls everything down, which
/// can set off chain reactions.
class MergeTenBoard {
  static const int cols = 6;
  static const int rows = 8;

  /// cells[row][col], row 0 is the top. 0 means empty.
  final List<List<int>> cells =
      List.generate(rows, (_) => List<int>.filled(cols, 0));

  static bool matches(int a, int b) => a != 0 && b != 0 && (a == b || a + b == 10);

  bool isColumnFull(int col) => cells[0][col] != 0;
  bool get isFull => List.generate(cols, isColumnFull).every((full) => full);

  /// Fills the bottom [rowCount] rows with random tiles that don't touch a
  /// matching tile, so the board starts populated but with nothing to clear.
  void seed(Random random, {int rowCount = 3}) {
    for (var r = rows - 1; r >= rows - rowCount; r--) {
      for (var c = 0; c < cols; c++) {
        int v;
        do {
          v = random.nextInt(9) + 1;
        } while ((c > 0 && matches(v, cells[r][c - 1])) ||
            (r < rows - 1 && matches(v, cells[r + 1][c])));
        cells[r][c] = v;
      }
    }
  }

  /// The row a tile dropped into [col] would land on, or -1 if full.
  int landingRow(int col) {
    for (var r = rows - 1; r >= 0; r--) {
      if (cells[r][col] == 0) return r;
    }
    return -1;
  }

  /// Drops [value] into [col]. Returns the row it landed on, or -1 if the
  /// column is full.
  int drop(int col, int value) {
    for (var r = rows - 1; r >= 0; r--) {
      if (cells[r][col] == 0) {
        cells[r][col] = value;
        return r;
      }
    }
    return -1;
  }

  /// Removes one batch of matching pairs (each tile used at most once) and
  /// returns the number of pairs removed. Does not apply gravity.
  int clearMatches() {
    final remove = <Point<int>>{};
    bool free(int r, int c) => !remove.contains(Point(r, c));
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (cells[r][c] == 0 || !free(r, c)) continue;
        // Prefer a sum-to-10 partner so 4 next to 6 isn't wasted on a 4-4.
        final neighbours = [
          if (c + 1 < cols) Point(r, c + 1),
          if (r + 1 < rows) Point(r + 1, c),
          if (c > 0) Point(r, c - 1),
          if (r > 0) Point(r - 1, c),
        ].where((p) => free(p.x, p.y) && matches(cells[r][c], cells[p.x][p.y]));
        if (neighbours.isEmpty) continue;
        final partner = neighbours.first;
        remove..add(Point(r, c))..add(partner);
      }
    }
    for (final p in remove) {
      cells[p.x][p.y] = 0;
    }
    return remove.length ~/ 2;
  }

  /// Slides every tile down to fill gaps.
  void applyGravity() {
    for (var c = 0; c < cols; c++) {
      var write = rows - 1;
      for (var r = rows - 1; r >= 0; r--) {
        if (cells[r][c] != 0) {
          final v = cells[r][c];
          cells[r][c] = 0;
          cells[write][c] = v;
          write--;
        }
      }
    }
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/merge_ten_board.dart';
import 'package:spell_game/utils/playtime_guard.dart';

/// Merge Ten: a merge-fruit-style drop game with a maths twist. Tap a column
/// to drop the next fruit-number; touching tiles vanish when they show the
/// same number or add up to 10. Chains of clears multiply the score. The game
/// ends when every column is full.
class MergeTenScreen extends StatefulWidget {
  const MergeTenScreen({Key? key}) : super(key: key);

  @override
  State<MergeTenScreen> createState() => _MergeTenScreenState();
}

class _MergeTenScreenState extends State<MergeTenScreen>
    with PlaytimeGuardMixin {
  static const _bestKey = 'merge_ten_best';
  static const _fruits = ['🍒', '🍓', '🍊', '🍋', '🍎', '🍐', '🍇', '🍑', '🍉'];
  static const _colors = [
    Color(0xFFFFCDD2),
    Color(0xFFF8BBD0),
    Color(0xFFFFE0B2),
    Color(0xFFFFF59D),
    Color(0xFFFFCCBC),
    Color(0xFFDCEDC8),
    Color(0xFFE1BEE7),
    Color(0xFFFFE0CC),
    Color(0xFFC8E6C9),
  ];

  final _random = Random();
  late MergeTenBoard _board;
  late int _next;
  int _score = 0;
  int _best = 0;
  int _combo = 0;
  int _col = MergeTenBoard.cols ~/ 2;
  int? _fallRow; // row of the falling tile while it drops
  final _focus = FocusNode();
  bool _busy = false;
  bool _gameOver = false;
  bool _playtimeLocked = false;
  // Auto mode: the hovering tile drops by itself every second (the player
  // can still steer it left/right between drops).
  bool _auto = false;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _reset();
    _loadBest();
    startPlaytimeGuard();
  }

  @override
  void onPlaytimeLocked() {
    if (!mounted) return;
    setState(() => _playtimeLocked = true);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    disposePlaytimeGuard();
    _focus.dispose();
    super.dispose();
  }

  void _reset() {
    _board = MergeTenBoard()..seed(_random);
    _next = _randomTile();
    _score = 0;
    _combo = 0;
    _col = MergeTenBoard.cols ~/ 2;
    _fallRow = null;
    _busy = false;
    _gameOver = false;
  }

  void _setAuto(bool value) {
    setState(() {
      _auto = value;
      // Turning Auto off mid-fall puts the tile back to hovering.
      if (!value && !_busy) _fallRow = null;
    });
    _autoTimer?.cancel();
    if (!value) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 1), (_) => _autoStep());
  }

  /// One Auto tick: the tile enters the board, then falls one row per tick
  /// (steerable left/right in between) until it lands.
  void _autoStep() {
    if (!mounted || _busy || _gameOver || _playtimeLocked) return;
    final fall = _fallRow;
    if (fall == null) {
      // Top cell taken - slide to the nearest column that is still open.
      if (_board.cells[0][_col] != 0) {
        final open = [
          for (var c = 0; c < MergeTenBoard.cols; c++)
            if (_board.cells[0][c] == 0) c,
        ]..sort((a, b) => (a - _col).abs().compareTo((b - _col).abs()));
        if (open.isEmpty) return;
        _col = open.first;
      }
      setState(() => _fallRow = 0);
      return;
    }
    if (fall + 1 < MergeTenBoard.rows && _board.cells[fall + 1][_col] == 0) {
      setState(() => _fallRow = fall + 1);
    } else {
      _landFalling();
    }
  }

  /// Lands the falling tile where it is, then resolves any matches.
  Future<void> _landFalling() async {
    final col = _col;
    setState(() {
      _busy = true;
      _combo = 0;
      _fallRow = null;
      _board.drop(col, _next);
      _next = _randomTile();
    });
    await _resolveChains();
  }

  int _randomTile() => _random.nextInt(9) + 1;

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _best = prefs.getInt(_bestKey) ?? 0);
    } catch (_) {}
  }

  Future<void> _saveBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, _best);
    } catch (_) {}
  }

  void _move(int delta) => _moveTo(_col + delta);

  void _moveTo(int col) {
    if (_busy || _gameOver) return;
    col = col.clamp(0, MergeTenBoard.cols - 1);
    // A tile already falling can only slide into an empty cell beside it.
    final fall = _fallRow;
    if (fall != null && _board.cells[fall][col] != 0) return;
    setState(() => _col = col);
  }

  Future<void> _onDrop() async {
    if (_busy || _gameOver || _playtimeLocked) return;
    final col = _col;
    final land = _board.landingRow(col);
    if (land < 0) return;
    setState(() {
      _busy = true;
      _combo = 0;
    });
    // Animate the tile falling from the top lane to where it lands.
    for (var r = _fallRow ?? 0; r <= land; r++) {
      setState(() => _fallRow = r);
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
    }
    setState(() {
      _fallRow = null;
      _board.drop(col, _next);
      _next = _randomTile();
    });
    await _resolveChains();
  }

  /// Resolve chains one wave at a time so the player can follow them.
  Future<void> _resolveChains() async {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      final pairs = _board.clearMatches();
      if (pairs == 0) break;
      setState(() {
        _combo++;
        _score += pairs * 10 * _combo;
      });
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(_board.applyGravity);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _gameOver = _board.isFull;
      if (_score > _best) _best = _score;
    });
    if (_gameOver) _saveBest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Merge Ten', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Restart',
            icon: const Icon(Icons.refresh, color: DuolingoColors.darkText),
            onPressed: () => setState(_reset),
          ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (_, e) {
            if (e is! KeyDownEvent) return KeyEventResult.ignored;
            if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _move(-1);
            } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
              _move(1);
            } else if (e.logicalKey == LogicalKeyboardKey.arrowDown ||
                e.logicalKey == LogicalKeyboardKey.space) {
              _onDrop();
            } else {
              return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          },
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_playtimeLocked) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "You've used your 15 minutes of game time for today.\nCome back tomorrow!",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.all(DuolingoSpacing.lg),
      child: Column(
        children: [
          _buildHeader(),
          SizedBox(height: DuolingoSpacing.md),
          Text(
            'Move the tile left or right, then press Drop (or turn on Auto).\nTouching tiles vanish if they are the same or add up to 10!',
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.body,
          ),
          SizedBox(height: DuolingoSpacing.md),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: MergeTenBoard.cols / (MergeTenBoard.rows + 1),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(child: _buildLane()),
                        Expanded(
                          flex: MergeTenBoard.rows,
                          child: _buildGrid(),
                        ),
                      ],
                    ),
                    if (_gameOver) _buildGameOver(),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: DuolingoSpacing.md),
          _buildControls(),
        ],
      ),
    );
  }

  /// Horizontal drag moves the hovering tile column by column.
  Widget _buildLane() {
    return LayoutBuilder(
      builder: (_, box) {
        final colWidth = box.maxWidth / MergeTenBoard.cols;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _moveTo(d.localPosition.dx ~/ colWidth),
          onHorizontalDragUpdate: (d) => _moveTo(d.localPosition.dx ~/ colWidth),
          child: Row(
            children: List.generate(MergeTenBoard.cols, (c) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: c == _col && _fallRow == null && !_gameOver
                      ? LayoutBuilder(
                          builder: (_, b) =>
                              _tile(_next, size: min(b.maxWidth, b.maxHeight)),
                        )
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    Widget arrow(IconData icon, int delta) => IconButton.filled(
          iconSize: 36,
          onPressed: () => _move(delta),
          icon: Icon(icon),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        arrow(Icons.arrow_left, -1),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _onDrop,
              icon: const Icon(Icons.arrow_downward),
              label: const Text('Drop'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Auto', style: DuolingoTextStyles.label),
                Switch(value: _auto, onChanged: _setAuto),
              ],
            ),
          ],
        ),
        arrow(Icons.arrow_right, 1),
      ],
    );
  }

  Widget _buildHeader() {
    Widget stat(String label, String value) => Column(
          children: [
            Text(label, style: DuolingoTextStyles.label),
            Text(value, style: DuolingoTextStyles.cardTitle),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        stat('Score', '$_score'),
        Column(
          children: [
            Text('Next', style: DuolingoTextStyles.label),
            _tile(_next, size: 48),
          ],
        ),
        stat('Best', '$_best'),
      ],
    );
  }

  Widget _tile(int value, {required double size}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _colors[value - 1],
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: Colors.black12),
      ),
      child: FittedBox(
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_fruits[value - 1], style: const TextStyle(fontSize: 18)),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: DuolingoColors.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Container(
      decoration: BoxDecoration(
        color: DuolingoColors.neutralGray,
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(MergeTenBoard.cols, (c) {
          return Expanded(
            child: Container(
              color: c == _col ? Colors.black.withValues(alpha: 0.04) : null,
              child: Column(
                children: List.generate(MergeTenBoard.rows, (r) {
                  final falling = _fallRow == r && _col == c;
                  final v = falling ? _next : _board.cells[r][c];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: v == 0
                          ? Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (_, box) => _tile(
                                v,
                                size: min(box.maxWidth, box.maxHeight),
                              ),
                            ),
                    ),
                  );
                }),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGameOver() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Board full!', style: DuolingoTextStyles.sectionTitle),
            SizedBox(height: DuolingoSpacing.sm),
            Text('Score: $_score', style: DuolingoTextStyles.cardTitle),
            SizedBox(height: DuolingoSpacing.lg),
            ElevatedButton(
              onPressed: () => setState(_reset),
              child: const Text('Play again'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/word_wheel_puzzle.dart';
import 'package:spell_game/utils/playtime_guard.dart';
import 'package:spell_game/widgets/celebration.dart';

/// Word Wheel: a Words-of-Wonders-style puzzle built from the player's own
/// currently-practicing words. A handful of words that share enough
/// letters are laid out as a crossword; a circular "wheel" holds every
/// letter tile any of them need. Tracing a path across the wheel that
/// spells one of the target words reveals it on the grid and earns a real
/// spaced-repetition review credit for that word.
class WordWheelScreen extends StatefulWidget {
  const WordWheelScreen({Key? key}) : super(key: key);

  @override
  State<WordWheelScreen> createState() => _WordWheelScreenState();
}

class _WordWheelScreenState extends State<WordWheelScreen>
    with PlaytimeGuardMixin {
  bool _loading = true;
  WordWheelPuzzle? _puzzle;
  final Set<String> _found = {};
  // Cells revealed via the hint button, ahead of that word actually being
  // traced - separate from [_found] since a word becomes fully revealed
  // (and counted) once every one of its cells has been hinted.
  final Set<Point<int>> _hintedCells = {};
  int _hintsUsed = 0;
  final List<int> _trace = []; // indices into puzzle.wheelLetters
  bool _playtimeLocked = false;
  int _xpEarned = 0;
  int _coinsEarned = 0;
  bool _showError = false;

  final _wheelKey = GlobalKey();
  List<Offset> _tileCenters = [];
  final double _tileRadius = 22;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
    startPlaytimeGuard();
  }

  @override
  void onPlaytimeLocked() {
    if (!mounted) return;
    setState(() => _playtimeLocked = true);
  }

  @override
  void dispose() {
    disposePlaytimeGuard();
    super.dispose();
  }

  Future<void> _loadPuzzle() async {
    await gameProvider.loadDeck(limit: 50);
    var pool = gameProvider.deckWords;
    var puzzle = WordWheelPuzzle.build(pool);
    if (puzzle == null) {
      // Not enough usable words in the player's own due/new deck - top up
      // from the shared quiz pool, same fallback WordSnake uses.
      try {
        final extra = await gameProvider.apiClient.getQuizWordPool(
          limit: 100,
        );
        final seenIds = pool.map((w) => w.id).toSet();
        pool = [...pool, ...extra.where((w) => !seenIds.contains(w.id))];
        puzzle = WordWheelPuzzle.build(pool);
      } catch (_) {
        // Fall through with pool as-is; build already failed once.
      }
    }
    if (!mounted) return;
    setState(() {
      _puzzle = puzzle;
      _showError = puzzle == null;
      _loading = false;
    });
  }

  void _computeTileCenters(Size wheelSize) {
    final puzzle = _puzzle;
    if (puzzle == null) return;
    final n = puzzle.wheelLetters.length;
    final center = Offset(wheelSize.width / 2, wheelSize.height / 2);
    final radius = min(wheelSize.width, wheelSize.height) / 2 - _tileRadius;
    _tileCenters = [
      for (var i = 0; i < n; i++)
        center +
            Offset(
              radius * cos(2 * pi * i / n - pi / 2),
              radius * sin(2 * pi * i / n - pi / 2),
            ),
    ];
  }

  int? _tileAt(Offset local) {
    for (var i = 0; i < _tileCenters.length; i++) {
      if ((local - _tileCenters[i]).distance <= _tileRadius * 1.3) return i;
    }
    return null;
  }

  void _onPanStart(DragStartDetails details) {
    final box = _wheelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final tile = _tileAt(local);
    if (tile != null) setState(() => _trace.add(tile));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _wheelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final tile = _tileAt(local);
    if (tile == null || _trace.contains(tile)) return;
    setState(() => _trace.add(tile));
  }

  void _onPanEnd(DragEndDetails details) {
    _submitTrace();
  }

  void _submitTrace() {
    final puzzle = _puzzle;
    if (puzzle == null || _trace.isEmpty) {
      setState(() => _trace.clear());
      return;
    }
    final traced = _trace.map((i) => puzzle.wheelLetters[i]).join();
    final match = puzzle.matchTarget(traced, _found);
    if (match != null) {
      setState(() {
        _found.add(match.text);
        _trace.clear();
        _xpEarned += 10;
        _coinsEarned += 3;
      });
      Celebration.correct(context);
      Celebration.xpPop(context, 10);
      // Real spaced-repetition credit, same quality as a first-try-correct
      // exercise in a normal study session.
      gameProvider.submitReview(match.word.id, 5);
      if (_found.length == puzzle.placedWords.length) {
        _onPuzzleComplete();
      }
    } else {
      setState(() => _trace.clear());
    }
  }

  /// Reveals one more letter of whichever unfound word is closest to
  /// being fully hinted already (so hints finish one word at a time
  /// instead of spreading thin across every word), or the shortest unfound
  /// word if none has been hinted yet. Completing a word entirely this way
  /// still counts it as found (and still earns a review credit, so the
  /// spaced-repetition benefit isn't lost), but skips the XP/coin reward
  /// since the player didn't actually solve it.
  void _useHint() {
    final puzzle = _puzzle;
    if (puzzle == null) return;
    final unfound = puzzle.placedWords
        .where((p) => !_found.contains(p.text))
        .toList();
    if (unfound.isEmpty) return;

    PlacedWord? target;
    var bestHinted = -1;
    for (final p in unfound) {
      final hinted = p.blankCells.where(_hintedCells.contains).length;
      if (hinted >= p.blankCells.length) continue; // safe guard
      if (hinted > bestHinted ||
          (hinted == bestHinted &&
              (target == null ||
                  p.blankCells.length < target.blankCells.length))) {
        target = p;
        bestHinted = hinted;
      }
    }
    if (target == null) return;

    final cells = target.blankCells;
    final nextCell = cells.firstWhere((c) => !_hintedCells.contains(c));
    setState(() {
      _hintedCells.add(nextCell);
      _hintsUsed++;
    });

    final nowComplete = cells.every(_hintedCells.contains);
    if (nowComplete) {
      setState(() => _found.add(target!.text));
      // A modest credit, not the full first-try quality _submitTrace gives
      // - the player saw the answer rather than recalling it.
      gameProvider.submitReview(target.word.id, 3);
      if (_found.length == puzzle.placedWords.length) {
        _onPuzzleComplete();
      }
    }
  }

  Future<void> _onPuzzleComplete() async {
    Celebration.confetti(context);
    Celebration.reward(context);
    await gameProvider.loadUserStats();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusDialog),
        ),
        title: const Text('🎉 Puzzle solved!'),
        content: Text(
          'You found every word!\n+$_xpEarned XP · +$_coinsEarned coins',
          style: DuolingoTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'CLOSE',
              style: DuolingoTextStyles.label.copyWith(
                color: DuolingoColors.bodyText,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _playAgain();
            },
            child: Text(
              'NEW PUZZLE',
              style: DuolingoTextStyles.label.copyWith(
                color: DuolingoColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playAgain() {
    setState(() {
      _found.clear();
      _hintedCells.clear();
      _hintsUsed = 0;
      _trace.clear();
      _xpEarned = 0;
      _coinsEarned = 0;
      _loading = true;
    });
    _loadPuzzle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Word Wheel', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(child: _buildBody()),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final puzzle = _puzzle;
    if (_showError || puzzle == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📭', style: TextStyle(fontSize: 64)),
              SizedBox(height: DuolingoSpacing.lg),
              Text(
                'Not enough words to build a puzzle yet!',
                style: DuolingoTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: DuolingoSpacing.sm),
              Text(
                'Study a few more lessons first, then come back.',
                style: DuolingoTextStyles.body.copyWith(
                  color: DuolingoColors.bodyText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: DuolingoSpacing.lg,
            vertical: DuolingoSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_found.length} / ${puzzle.placedWords.length} words',
                style: DuolingoTextStyles.label,
              ),
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 18)),
                  Text(' $_xpEarned  ', style: DuolingoTextStyles.label),
                  const Text('💰', style: TextStyle(fontSize: 18)),
                  Text(' $_coinsEarned  ', style: DuolingoTextStyles.label),
                  _buildHintButton(),
                ],
              ),
            ],
          ),
        ),
        Expanded(flex: 3, child: _buildGrid(puzzle)),
        Expanded(flex: 4, child: _buildWheel(puzzle)),
      ],
    );
  }

  Widget _buildHintButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _useHint,
          tooltip: 'Hint',
          icon: const Icon(
            Icons.lightbulb,
            color: DuolingoColors.streakOrange,
          ),
        ),
        if (_hintsUsed > 0)
          Text(
            '$_hintsUsed',
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.bodyText,
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(WordWheelPuzzle puzzle) {
    final cellLetters = <Point<int>, String>{};
    final foundCells = <Point<int>>{};
    final givenCells = <Point<int>>{}; // pre-revealed scaffolding, see build()
    for (final p in puzzle.placedWords) {
      if (_found.contains(p.text)) {
        foundCells.addAll(p.cells);
      } else {
        for (final i in p.revealedIndices) {
          givenCells.add(p.cells[i]);
        }
      }
    }
    for (final p in puzzle.placedWords) {
      for (var i = 0; i < p.text.length; i++) {
        cellLetters[p.cells[i]] = p.text[i];
      }
    }
    final revealed = {...foundCells, ..._hintedCells, ...givenCells};
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = min(
          constraints.maxWidth / puzzle.cols,
          constraints.maxHeight / puzzle.rows,
        ).clamp(24.0, 48.0);
        return Center(
          child: SizedBox(
            width: cellSize * puzzle.cols,
            height: cellSize * puzzle.rows,
            child: Stack(
              children: [
                for (final entry in cellLetters.entries)
                  Positioned(
                    left: entry.key.y * cellSize,
                    top: entry.key.x * cellSize,
                    width: cellSize,
                    height: cellSize,
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: foundCells.contains(entry.key)
                            ? DuolingoColors.primaryGreen
                            : _hintedCells.contains(entry.key)
                            ? DuolingoColors.streakOrange
                            : givenCells.contains(entry.key)
                            ? DuolingoColors.informationBlue
                            : DuolingoColors.neutralGray,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: DuolingoColors.secondaryButtonGray,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: revealed.contains(entry.key)
                          ? Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: cellSize * 0.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWheel(WordWheelPuzzle puzzle) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Center(
            child: Text(
              _trace.map((i) => puzzle.wheelLetters[i]).join(),
              style: DuolingoTextStyles.pageTitle.copyWith(
                letterSpacing: 4,
                color: DuolingoColors.darkText,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = min(constraints.maxWidth, constraints.maxHeight);
                final size = Size(side, side);
                _computeTileCenters(size);
                return Center(
                  child: SizedBox(
                    key: _wheelKey,
                    width: side,
                    height: side,
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        painter: _TracePainter(
                          centers: _tileCenters,
                          trace: _trace,
                        ),
                        child: Stack(
                          children: [
                            for (
                              var i = 0;
                              i < puzzle.wheelLetters.length;
                              i++
                            )
                              Positioned(
                                left: _tileCenters.isEmpty
                                    ? 0
                                    : _tileCenters[i].dx - _tileRadius,
                                top: _tileCenters.isEmpty
                                    ? 0
                                    : _tileCenters[i].dy - _tileRadius,
                                width: _tileRadius * 2,
                                height: _tileRadius * 2,
                                child: _WheelTile(
                                  letter: puzzle.wheelLetters[i],
                                  active: _trace.contains(i),
                                  radius: _tileRadius,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WheelTile extends StatelessWidget {
  final String letter;
  final bool active;
  final double radius;

  const _WheelTile({
    required this.letter,
    required this.active,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? DuolingoColors.primaryGreen : Colors.white,
        border: Border.all(
          color: active
              ? const Color(0xFF58A700)
              : DuolingoColors.secondaryButtonGray,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (active ? const Color(0xFF58A700) : Colors.black12),
            offset: const Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: active ? Colors.white : DuolingoColors.darkText,
        ),
      ),
    );
  }
}

/// Draws lines connecting the currently-traced tiles, so a drag mid-swipe
/// reads as one continuous path rather than separate highlighted dots.
class _TracePainter extends CustomPainter {
  final List<Offset> centers;
  final List<int> trace;

  _TracePainter({required this.centers, required this.trace});

  @override
  void paint(Canvas canvas, Size size) {
    if (trace.length < 2 || centers.isEmpty) return;
    final paint = Paint()
      ..color = DuolingoColors.primaryGreen.withOpacity(0.6)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < trace.length - 1; i++) {
      canvas.drawLine(centers[trace[i]], centers[trace[i + 1]], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) =>
      oldDelegate.trace != trace || oldDelegate.centers != centers;
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/utils/exercise_content_parser.dart';
import '../main.dart' show gameProvider;

/// A continuous-movement (slither.io-style) snake game - NOT the classic
/// grid/turn-based snake. The player steers toward the pointer with a
/// capped turn rate, shares a circular arena with a few wandering AI
/// snakes, and grows by grazing scattered food orbs. Every ~20s a Word
/// Rune appears; eating it pauses play for a vocab question pulled from
/// the player's own study deck. A correct answer grants 15s of Ghost
/// (pass through other snakes); two correct answers in a row also grants
/// a Magnet (pulls food in from further away).
class WordSnakeScreen extends StatefulWidget {
  const WordSnakeScreen({Key? key}) : super(key: key);

  @override
  State<WordSnakeScreen> createState() => _WordSnakeScreenState();
}

class _Entity {
  double x, y;
  double angle;
  double targetAngle;
  double length; // mass - grows as it eats, drives body extent + score
  bool alive = true;
  bool boosting = false;
  final bool isAI;
  final List<Offset> trail = [];
  double ghostUntil = 0;
  double magnetUntil = 0;
  Offset? aiTarget;
  double aiRetargetMs = 0;

  // Boss-only fields.
  bool isBoss = false;
  int hp = 0;
  double invulnUntil = 0;
  double expireT = 0;
  int orbitDir = 1;
  double lungeUntil = 0;

  _Entity({
    required this.x,
    required this.y,
    required this.angle,
    required this.length,
    this.isAI = false,
  }) : targetAngle = angle;

  bool get ghostActive => ghostUntil > _nowMs();
  bool get magnetActive => magnetUntil > _nowMs();
}

class _Food {
  double x, y;
  _Food(this.x, this.y);
}

double _nowMs() => DateTime.now().millisecondsSinceEpoch.toDouble();

double _normAngle(double a) {
  while (a > pi) a -= 2 * pi;
  while (a < -pi) a += 2 * pi;
  return a;
}

class _WordSnakeScreenState extends State<WordSnakeScreen>
    with SingleTickerProviderStateMixin {
  // Tuned down from the reference game (smaller arena, fewer actors) to
  // keep a plain CustomPainter fast without spatial partitioning.
  static const double worldR = 1000;
  static const double turnRate = 0.11; // rad per 16.67ms frame
  static const double aiTurnRate = 0.07;
  static const double baseSpeed = 2.6;
  static const double boostSpeed = 4.6;
  static const double segmentSpacing = 5.0;
  static const double initialLength = 16;
  static const double minLength = 10;
  static const int foodCount = 90;
  static const int aiCount = 3;
  static const double runeIntervalMs = 20000;
  static const double ghostDurationMs = 15000;
  static const double magnetDurationMs = 15000;
  static const double aiSight = 260;
  static const double aiBoundaryBuffer = 140;
  static const double aiAvoidRange = 60;

  // Boss ("The Devourer") - only appears once the player has grown enough,
  // circles/lunges instead of food-seeking, and only the player's own BODY
  // (not head) damages it by ramming into it.
  static const double bossMinLength = 130;
  static const double bossIntervalMs = 45000;
  static const int bossHp = 2;
  static const double bossGraceMs = 2500;
  static const double bossLifetimeMs = 90000;
  static const double bossOrbitR = 240;
  static const double bossTurnRate = 0.085;

  final _random = Random();
  final GlobalKey _canvasKey = GlobalKey();

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  late _Entity _player;
  final List<_Entity> _aiSnakes = [];
  final List<_Food> _foods = [];
  Offset? _rune;
  double _nextRuneMs = 0;
  bool _bossActive = false;
  double _nextBossMs = 0;
  String? _bossBanner;
  double _bossBannerUntil = 0;

  Offset _pointer = Offset.zero;
  bool _boosting = false;

  int _score = 0;
  int _correctAnswers = 0;
  int _totalQuizzes = 0;
  int _quizStreak = 0;
  bool _gameOver = false;
  bool _quizOpen = false;
  bool _wordsLoading = true;
  List<Word> _quizWords = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadWords();
    _resetGame();
  }

  Future<void> _loadWords() async {
    await gameProvider.loadDeck(limit: 50);
    if (!mounted) return;
    setState(() {
      _quizWords = gameProvider.deckWords
          .where((w) => parseQuiz(w.quiz) != null)
          .toList();
      _wordsLoading = false;
    });
  }

  void _resetGame() {
    _player = _Entity(x: 0, y: 0, angle: 0, length: initialLength);
    _aiSnakes
      ..clear()
      ..addAll(List.generate(aiCount, (_) => _spawnAI()));
    _foods
      ..clear()
      ..addAll(List.generate(foodCount, (_) => _randomFood()));
    _rune = null;
    _nextRuneMs = _nowMs() + runeIntervalMs;
    _bossActive = false;
    _nextBossMs = 0;
    _bossBanner = null;
    _bossBannerUntil = 0;
    _score = 0;
    _correctAnswers = 0;
    _totalQuizzes = 0;
    _quizStreak = 0;
    _gameOver = false;
    _quizOpen = false;
    _lastElapsed = Duration.zero;
  }

  _Food _randomFood() {
    final a = _random.nextDouble() * 2 * pi;
    final r = _random.nextDouble() * (worldR - 40);
    return _Food(cos(a) * r, sin(a) * r);
  }

  _Entity _spawnAI() {
    final a = _random.nextDouble() * 2 * pi;
    final r = 200 + _random.nextDouble() * (worldR - 300);
    return _Entity(
      x: cos(a) * r,
      y: sin(a) * r,
      angle: _random.nextDouble() * 2 * pi,
      length: initialLength + _random.nextDouble() * 20,
      isAI: true,
    );
  }

  void _spawnBoss() {
    final now = _nowMs();
    const spawnDist = 700.0;
    final behind = _player.angle + pi;
    double? cx, cy;
    for (var tries = 0; tries < 12 && cx == null; tries++) {
      final off = tries == 0
          ? 0.0
          : (tries.isOdd ? 1 : -1) * 0.4 * ((tries + 1) / 2).ceil();
      final ang = behind + off + (_random.nextDouble() - 0.5) * 0.25;
      final tx = _player.x + cos(ang) * spawnDist;
      final ty = _player.y + sin(ang) * spawnDist;
      if (Point(tx, ty).distanceTo(const Point(0, 0)) < worldR - 150) {
        cx = tx;
        cy = ty;
      }
    }
    cx ??= 0;
    cy ??= 0;

    final boss = _Entity(
      x: cx,
      y: cy,
      angle: atan2(_player.y - cy, _player.x - cx),
      length: max(60, _player.length * 0.75),
      isAI: true,
    )
      ..isBoss = true
      ..hp = bossHp
      ..invulnUntil = now + bossGraceMs
      ..expireT = now + bossLifetimeMs;
    _aiSnakes.add(boss);
    _bossActive = true;
    _nextBossMs = now + bossIntervalMs;
    _bossBanner = '⚠ THE DEVOURER HAS ENTERED THE ARENA ⚠';
    _bossBannerUntil = now + 3000;
  }

  void _spawnFoodBurst(double x, double y, int count) {
    for (var i = 0; i < count; i++) {
      _foods.add(_Food(
        x + (_random.nextDouble() - 0.5) * 40,
        y + (_random.nextDouble() - 0.5) * 40,
      ));
    }
  }

  void _onTick(Duration elapsed) {
    final dtMs =
        (elapsed - _lastElapsed).inMicroseconds / 1000.0;
    _lastElapsed = elapsed;
    if (dtMs <= 0 || dtMs > 200) return; // clamp first-frame / tab-away jumps
    if (_gameOver || _quizOpen) return;
    _update(dtMs);
    setState(() {});
  }

  void _update(double dt) {
    final frames = dt / 16.67;

    // Player steering: angle toward pointer relative to canvas center.
    if (_pointer.distanceSquared > 4) {
      _player.targetAngle = atan2(_pointer.dy, _pointer.dx);
    }
    _player.boosting = _boosting && _player.length > minLength;

    for (final ai in _aiSnakes) {
      if (!ai.alive) continue;
      if (ai.isBoss) {
        _bossThink(ai);
      } else {
        _aiThink(ai);
      }
    }

    _advance(_player, frames, isPlayer: true);
    for (final ai in _aiSnakes) {
      if (ai.alive) _advance(ai, frames);
    }

    _handleFood(_player);
    for (final ai in _aiSnakes) {
      if (ai.alive && !ai.isBoss) _handleFood(ai);
    }

    _handleRune();
    _handleBossCollisions();
    _checkDeath();

    // Respawn non-boss AI that died, after a short delay handled by simply
    // topping back up to aiCount immediately (keeps the arena populated).
    _aiSnakes.removeWhere((ai) => !ai.alive);
    while (_aiSnakes.where((ai) => !ai.isBoss).length < aiCount) {
      _aiSnakes.add(_spawnAI());
    }

    final now = _nowMs();
    if (_rune == null && now >= _nextRuneMs && _quizWords.isNotEmpty) {
      _spawnRune();
    }
    if (!_bossActive &&
        _player.length >= bossMinLength &&
        now >= _nextBossMs) {
      _spawnBoss();
    }
  }

  void _advance(_Entity e, double frames, {bool isPlayer = false}) {
    double da = _normAngle(e.targetAngle - e.angle);
    final rate =
        (e.isBoss ? bossTurnRate : (e.isAI ? aiTurnRate : turnRate)) * frames;
    e.angle += da.sign * min(da.abs(), rate);

    final fast = e.boosting;
    final speed = (fast ? boostSpeed : baseSpeed) * frames;
    e.x += cos(e.angle) * speed;
    e.y += sin(e.angle) * speed;
    e.trail.add(Offset(e.x, e.y));

    final maxDist = e.length * segmentSpacing + 80;
    double acc = 0;
    int cut = 0;
    for (var i = e.trail.length - 1; i > 0; i--) {
      acc += (e.trail[i] - e.trail[i - 1]).distance;
      if (acc > maxDist) {
        cut = i;
        break;
      }
    }
    if (cut > 0) e.trail.removeRange(0, cut);

    if (isPlayer && e.boosting) {
      e.length = max(minLength, e.length - 0.02 * frames);
    }
  }

  List<Offset> _bodySegments(_Entity e) {
    final segs = <Offset>[];
    if (e.trail.isEmpty) return segs;
    final maxSegs = e.length.clamp(4, 220).toInt();
    segs.add(e.trail.last);
    double acc = 0;
    for (var i = e.trail.length - 1; i > 0 && segs.length < maxSegs; i--) {
      acc += (e.trail[i] - e.trail[i - 1]).distance;
      if (acc >= segmentSpacing) {
        segs.add(e.trail[i - 1]);
        acc = 0;
      }
    }
    return segs;
  }

  void _handleFood(_Entity e) {
    final radius = 8 + min(1.0, (e.length - initialLength) / 200) * 10;
    final magnetR = e.magnetActive ? 160.0 : (e.isAI ? 40.0 : 60.0);
    for (final f in _foods) {
      final d = (Offset(f.x, f.y) - Offset(e.x, e.y)).distance;
      if (d < magnetR && d > radius) {
        final pull = e.magnetActive ? 0.12 : 0.06;
        f.x += (e.x - f.x) * pull;
        f.y += (e.y - f.y) * pull;
      }
      if (d < radius + 6) {
        e.length += 0.6;
        if (!e.isAI) _score += 1;
        final idx = _foods.indexOf(f);
        if (idx != -1) _foods[idx] = _randomFood();
        break;
      }
    }
  }

  void _spawnRune() {
    var dist = 260 + _random.nextDouble() * 120;
    var ang = _player.angle + (_random.nextDouble() - 0.5);
    var x = _player.x + cos(ang) * dist;
    var y = _player.y + sin(ang) * dist;
    if (Point(x, y).distanceTo(const Point(0, 0)) > worldR - 60) {
      final toC = atan2(-_player.y, -_player.x);
      x = _player.x + cos(toC) * dist;
      y = _player.y + sin(toC) * dist;
    }
    _rune = Offset(x, y);
  }

  void _handleRune() {
    if (_rune == null) return;
    final d = (_rune! - Offset(_player.x, _player.y)).distance;
    if (d < 26) {
      _rune = null;
      _askQuiz();
    }
  }

  /// Only the player's own BODY (not head) damages the boss - ramming it
  /// into the boss counts as a hit. Boss body touching the player's head
  /// is handled separately by [_checkDeath] like any other snake.
  void _handleBossCollisions() {
    final now = _nowMs();
    for (final boss in _aiSnakes) {
      if (!boss.isBoss || !boss.alive) continue;

      if (now > boss.expireT) {
        boss.alive = false;
        _bossActive = false;
        _showBossBanner('👑 The Devourer withdrew...');
        continue;
      }
      if (now < boss.invulnUntil) continue;

      for (final seg in _bodySegments(_player)) {
        if ((seg - Offset(boss.x, boss.y)).distance < 16) {
          boss.hp -= 1;
          _score += 120;
          if (boss.hp <= 0) {
            boss.alive = false;
            _bossActive = false;
            _spawnFoodBurst(boss.x, boss.y, 8);
            _showBossBanner('👑 Boss defeated! +120');
          } else {
            boss.invulnUntil = now + 1500;
            final away = atan2(boss.y - _player.y, boss.x - _player.x);
            boss.x += cos(away) * 60;
            boss.y += sin(away) * 60;
            boss.angle = boss.targetAngle = away;
            _showBossBanner('👑 Boss hit! ${boss.hp} HP left');
          }
          break;
        }
      }
    }
  }

  void _showBossBanner(String text) {
    _bossBanner = text;
    _bossBannerUntil = _nowMs() + 2200;
  }

  void _bossThink(_Entity boss) {
    if (!_player.alive) return;
    final now = _nowMs();
    final dx = _player.x - boss.x, dy = _player.y - boss.y;
    final dist = sqrt(dx * dx + dy * dy);

    if (now > boss.lungeUntil + 3500 && _random.nextDouble() < 0.012) {
      boss.lungeUntil = now + 850;
      if (_random.nextDouble() < 0.35) boss.orbitDir *= -1;
    }
    final lunging = now < boss.lungeUntil;

    if (lunging || dist > bossOrbitR + 160) {
      final lead = min(170, dist * 0.3);
      final tx = _player.x + cos(_player.angle) * lead;
      final ty = _player.y + sin(_player.angle) * lead;
      boss.targetAngle = atan2(ty - boss.y, tx - boss.x);
      boss.boosting = lunging && dist > 150;
    } else {
      final angAround = atan2(boss.y - _player.y, boss.x - _player.x);
      final desired = angAround + boss.orbitDir * 0.55;
      final tx = _player.x + cos(desired) * bossOrbitR;
      final ty = _player.y + sin(desired) * bossOrbitR;
      boss.targetAngle = atan2(ty - boss.y, tx - boss.x);
      boss.boosting = false;
    }
  }

  void _checkDeath() {
    if (!_player.alive) return;
    final distFromCenter = Point(_player.x, _player.y).distanceTo(const Point(0, 0));
    if (distFromCenter > worldR) {
      _endGame();
      return;
    }
    if (_player.ghostActive) return;
    for (final ai in _aiSnakes) {
      if (!ai.alive) continue;
      for (final seg in _bodySegments(ai)) {
        if ((seg - Offset(_player.x, _player.y)).distance < 14) {
          _endGame();
          return;
        }
      }
    }
  }

  void _aiThink(_Entity ai) {
    ai.aiRetargetMs -= 16.67;
    final distFromCenter = Point(ai.x, ai.y).distanceTo(const Point(0, 0));

    if (distFromCenter > worldR - aiBoundaryBuffer) {
      ai.targetAngle = atan2(-ai.y, -ai.x);
      ai.boosting = false;
      ai.aiTarget = null;
      return;
    }

    // Swerve away from nearby player/AI bodies ahead of it.
    final lookAhead = 60.0;
    final aheadX = ai.x + cos(ai.angle) * lookAhead;
    final aheadY = ai.y + sin(ai.angle) * lookAhead;
    Offset? threat;
    double threatD = double.infinity;
    for (final other in [_player, ..._aiSnakes]) {
      if (other == ai || !other.alive) continue;
      if ((Offset(other.x, other.y) - Offset(ai.x, ai.y)).distance >
          360) {
        continue;
      }
      for (final seg in _bodySegments(other)) {
        final d = (seg - Offset(aheadX, aheadY)).distance;
        if (d < aiAvoidRange && d < threatD) {
          threatD = d;
          threat = seg;
        }
      }
    }
    if (threat != null) {
      final toThreat = atan2(threat.dy - ai.y, threat.dx - ai.x);
      final rel = _normAngle(toThreat - ai.angle);
      ai.targetAngle = ai.angle + (rel >= 0 ? -1 : 1) * 1.3;
      ai.boosting = false;
      ai.aiTarget = null;
      return;
    }

    final targetGone = ai.aiTarget == null ||
        (ai.aiTarget! - Offset(ai.x, ai.y)).distance < 20 ||
        (ai.aiTarget! - Offset(ai.x, ai.y)).distance > aiSight * 1.6;
    if (targetGone || ai.aiRetargetMs <= 0) {
      _Food? best;
      double bestScore = double.infinity;
      for (final f in _foods) {
        final d = (Offset(f.x, f.y) - Offset(ai.x, ai.y)).distance;
        if (d > aiSight || d < 40) continue;
        final angTo = atan2(f.y - ai.y, f.x - ai.x);
        final da = _normAngle(angTo - ai.angle).abs();
        if (da > 2.0) continue;
        final score = d + da * 70;
        if (score < bestScore) {
          bestScore = score;
          best = f;
        }
      }
      ai.aiTarget = best != null ? Offset(best.x, best.y) : null;
      ai.aiRetargetMs = 500 + _random.nextDouble() * 400;
    }

    if (ai.aiTarget != null) {
      ai.targetAngle = atan2(ai.aiTarget!.dy - ai.y, ai.aiTarget!.dx - ai.x);
    } else {
      ai.targetAngle = ai.angle + (_random.nextDouble() - 0.5) * 0.1;
    }
  }

  void _endGame() {
    setState(() {
      _player.alive = false;
      _gameOver = true;
    });
  }

  void _onPointerMove(Offset globalPos) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    _pointer = local - Offset(box.size.width / 2, box.size.height / 2);
  }

  Future<void> _askQuiz() async {
    final word = _quizWords[_random.nextInt(_quizWords.length)];
    final quiz = parseQuiz(word.quiz)!;
    setState(() => _quizOpen = true);
    _totalQuizzes += 1;

    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _QuizDialog(word: word.text, quiz: quiz),
    );

    if (!mounted) return;
    final correct = selected == quiz.correctOption;
    setState(() {
      _quizOpen = false;
      _nextRuneMs = _nowMs() + runeIntervalMs;
      if (correct) {
        _correctAnswers += 1;
        _quizStreak += 1;
        _score += 20;
        final chained = _quizStreak >= 2;
        _player.ghostUntil = _nowMs() + ghostDurationMs;
        if (chained) _player.magnetUntil = _nowMs() + magnetDurationMs;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(chained
                ? '👻 Ghost + 🧲 Magnet for 15s!'
                : '👻 Ghost mode for 15s!'),
          ),
        );
      } else {
        _quizStreak = 0;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050010),
      appBar: AppBar(
        title: Text('Word Snake', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildScoreBar(),
          if (_wordsLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (_quizWords.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: DuolingoSpacing.md,
                vertical: DuolingoSpacing.xs,
              ),
              child: Text(
                'No vocab quiz data in your deck yet - playing without runes.',
                style: DuolingoTextStyles.label.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(DuolingoSpacing.md),
              child: Listener(
                onPointerMove: (e) => _onPointerMove(e.position),
                onPointerHover: (e) => _onPointerMove(e.position),
                child: Stack(
                  key: _canvasKey,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ArenaPainter(
                          player: _player,
                          aiSnakes: _aiSnakes,
                          foods: _foods,
                          rune: _rune,
                          worldR: worldR,
                          bodySegmentsOf: _bodySegments,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: GestureDetector(
                        onTapDown: (_) => _boosting = true,
                        onTapUp: (_) => _boosting = false,
                        onTapCancel: () => _boosting = false,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _boosting
                                ? DuolingoColors.primaryGreen
                                : Colors.white24,
                          ),
                          child: const Icon(Icons.bolt, color: Colors.white),
                        ),
                      ),
                    ),
                    if (_bossBanner != null && _nowMs() < _bossBannerUntil)
                      _buildBossBanner(),
                    if (_gameOver) _buildGameOverOverlay(),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: DuolingoSpacing.md),
        ],
      ),
    );
  }

  Widget _buildScoreBar() {
    final ghostSecs = (_player.ghostUntil - _nowMs()) / 1000;
    _Entity? boss;
    if (_bossActive) {
      for (final a in _aiSnakes) {
        if (a.isBoss && a.alive) {
          boss = a;
          break;
        }
      }
    }
    return Container(
      color: DuolingoColors.backgroundWhite,
      padding: EdgeInsets.symmetric(
        horizontal: DuolingoSpacing.lg,
        vertical: DuolingoSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Score: $_score', style: DuolingoTextStyles.cardTitle),
          Text('Length: ${_player.length.toInt()}',
              style: DuolingoTextStyles.label),
          if (boss != null)
            Text('👑 ${boss.hp} HP',
                style: DuolingoTextStyles.label
                    .copyWith(color: DuolingoColors.mistakeRed)),
          if (ghostSecs > 0)
            Text('👻 ${ghostSecs.ceil()}s',
                style: DuolingoTextStyles.label
                    .copyWith(color: DuolingoColors.specialPurple)),
          Text(
            _totalQuizzes == 0
                ? 'Words: -'
                : 'Words: $_correctAnswers/$_totalQuizzes',
            style: DuolingoTextStyles.label,
          ),
        ],
      ),
    );
  }

  Widget _buildBossBanner() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: IgnorePointer(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: DuolingoSpacing.md,
            vertical: DuolingoSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: DuolingoColors.mistakeRed.withOpacity(0.85),
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          ),
          child: Text(
            _bossBanner ?? '',
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.cardTitle.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Game Over',
                  style: DuolingoTextStyles.sectionTitle
                      .copyWith(color: Colors.white)),
              SizedBox(height: DuolingoSpacing.sm),
              Text('Score: $_score',
                  style: DuolingoTextStyles.cardTitle
                      .copyWith(color: Colors.white)),
              if (_totalQuizzes > 0)
                Padding(
                  padding: EdgeInsets.only(top: DuolingoSpacing.xs),
                  child: Text(
                    'Words answered: $_correctAnswers/$_totalQuizzes',
                    style: DuolingoTextStyles.label
                        .copyWith(color: Colors.white70),
                  ),
                ),
              SizedBox(height: DuolingoSpacing.lg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(_resetGame),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DuolingoColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Play Again'),
                  ),
                  SizedBox(width: DuolingoSpacing.md),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  final _Entity player;
  final List<_Entity> aiSnakes;
  final List<_Food> foods;
  final Offset? rune;
  final double worldR;
  final List<Offset> Function(_Entity) bodySegmentsOf;

  _ArenaPainter({
    required this.player,
    required this.aiSnakes,
    required this.foods,
    required this.rune,
    required this.worldR,
    required this.bodySegmentsOf,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final camera = Offset(player.x, player.y);
    Offset toScreen(Offset world) => world - camera + center;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF050010));

    canvas.drawCircle(
      toScreen(Offset.zero),
      worldR,
      Paint()
        ..color = const Color(0xFF5fd0ff).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final foodPaint = Paint()..color = const Color(0xFFffd166);
    for (final f in foods) {
      final p = toScreen(Offset(f.x, f.y));
      if ((p - center).distance > size.longestSide) continue;
      canvas.drawCircle(p, 3.5, foodPaint);
    }

    for (final ai in aiSnakes) {
      _drawSnake(canvas, bodySegmentsOf(ai), toScreen,
          ai.isBoss ? const Color(0xFFE01B4A) : const Color(0xFFff5ec3),
          false, boss: ai.isBoss);
    }
    _drawSnake(canvas, bodySegmentsOf(player), toScreen,
        const Color(0xFF4ade80), player.ghostActive);

    for (final ai in aiSnakes) {
      if (!ai.isBoss) continue;
      final tp = TextPainter(
        text: const TextSpan(text: '👑', style: TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = toScreen(Offset(ai.x, ai.y));
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height + 8));
    }

    if (rune != null) {
      final tp = TextPainter(
        text: const TextSpan(text: '📖', style: TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = toScreen(rune!);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawSnake(Canvas canvas, List<Offset> segs,
      Offset Function(Offset) toScreen, Color color, bool ghost,
      {bool boss = false}) {
    final paint = Paint()..color = ghost ? color.withOpacity(0.5) : color;
    for (var i = segs.length - 1; i >= 0; i--) {
      final r = (i == 0 ? 9.0 : 6.5) * (boss ? 1.6 : 1.0);
      canvas.drawCircle(toScreen(segs[i]), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}

class _QuizDialog extends StatelessWidget {
  final String word;
  final QuizData quiz;

  const _QuizDialog({required this.word, required this.quiz});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('📖 Word Rune: $word', style: DuolingoTextStyles.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quiz.question, style: DuolingoTextStyles.body),
          SizedBox(height: DuolingoSpacing.md),
          ...quiz.options.map(
            (option) => Padding(
              padding: EdgeInsets.only(bottom: DuolingoSpacing.sm),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(option),
                  child: Text(option, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

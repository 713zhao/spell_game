import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/reading_story.dart';
import 'package:spell_game/services/speech_stream_service.dart';
import 'package:spell_game/utils/playtime_guard.dart';
import 'package:spell_game/widgets/celebration.dart';

enum _Phase { loading, ready, playing, over, done }

/// A collectible coin flying past. [x] is a fraction of the screen width
/// (1 = right edge); [alt] uses the same 0..1 altitude scale as the dog.
class _Coin {
  double x;
  final double alt;
  _Coin(this.x, this.alt);
}

/// A shark swimming toward the dog. It leaps out of the water in an arc as
/// it passes the dog's column; a dog flying lower than the arc gets eaten.
class _Shark {
  double x;
  _Shark(this.x);
}

/// Flying Dog: an oral-reading game. A winged dog flies over the sea while
/// one sentence of a story is shown on top. Reading aloud keeps the dog
/// flying (and higher); silence makes it sink, and hitting the water ends
/// the game. Reading a sentence correctly earns points.
class FlyingDogReadingScreen extends StatefulWidget {
  const FlyingDogReadingScreen({Key? key}) : super(key: key);

  @override
  State<FlyingDogReadingScreen> createState() => _FlyingDogReadingScreenState();
}

class _FlyingDogReadingScreenState extends State<FlyingDogReadingScreen>
    with PlaytimeGuardMixin {
  static const _prefsKey = 'flying_dog_settings';
  static const _tick = Duration(milliseconds: 33);
  static const _dogX = 0.28; // dog's column, as a fraction of screen width
  static const _scrollSpeed = 0.16; // screen widths per second
  static const _jumpHalfWidth = 0.2; // shark arc half-width (screen widths)
  static const _jumpHeight = 0.55; // shark arc peak (altitude units)
  static const _hitRadius = 0.07;
  // Altitude is 0 (touching the sea) .. 1 (top of the sky).
  static const _riseRate = 0.28;
  static const _fallRate = 0.07;
  static const _speechFresh = Duration(milliseconds: 1400);

  // Settings (persisted).
  bool _chinese = false;
  bool _pinyin = true;
  bool _spellingStory = true;

  _Phase _phase = _Phase.loading;
  ReadingStory? _story;
  String? _notice; // shown under the sentence (fallback / unsupported info)
  int _sentenceIdx = 0;
  double _altitude = 0.5;
  int _points = 0;
  bool _advancing = false;
  bool _playtimeLocked = false;
  bool _micDenied = false;
  bool _eaten = false;

  // Moving world.
  final _rng = Random();
  double _scroll = 0; // total distance scrolled, in screen widths
  final List<_Coin> _coins = [];
  final List<_Shark> _sharks = [];
  double _nextCoinIn = 3;
  double _nextSharkIn = 6;

  final _listener = SpeechListener();
  Timer? _timer;
  DateTime _lastSpeech = DateTime.now();
  String _transcript = '';
  int _consumed = 0; // transcript chars already credited to earlier sentences
  List<bool> _read = [];

  @override
  void initState() {
    super.initState();
    startPlaytimeGuard();
    _init();
  }

  @override
  void onPlaytimeLocked() {
    if (!mounted) return;
    _stopGame();
    setState(() => _playtimeLocked = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _listener.stop();
    disposePlaytimeGuard();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey);
      if (saved != null && saved.length == 3) {
        _chinese = saved[0] == '1';
        _pinyin = saved[1] == '1';
        _spellingStory = saved[2] == '1';
      }
    } catch (_) {}
    await _loadStory();
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, [
        _chinese ? '1' : '0',
        _pinyin ? '1' : '0',
        _spellingStory ? '1' : '0',
      ]);
    } catch (_) {}
  }

  Future<void> _loadStory() async {
    _stopGame();
    setState(() => _phase = _Phase.loading);
    ReadingStory? story;
    String? notice;
    if (_spellingStory) {
      try {
        await gameProvider.loadDeck(limit: 50);
        story = buildSpellingStory(gameProvider.deckWords, chinese: _chinese);
        if (story == null) {
          try {
            final extra = await gameProvider.apiClient.getQuizWordPool(
              limit: 100,
            );
            story = buildSpellingStory(extra, chinese: _chinese);
          } catch (_) {}
        }
      } catch (_) {}
      if (story == null) {
        notice = _chinese
            ? '没有找到你的拼写词，先读一个现成的故事吧。'
            : 'No spelling words found yet - here is a ready-made story.';
      }
    }
    story ??= presetStory(_chinese);
    if (!mounted) return;
    setState(() {
      _story = story;
      _notice = notice;
      _sentenceIdx = 0;
      _points = 0;
      _altitude = 0.5;
      _transcript = '';
      _consumed = 0;
      _read = _freshRead();
      _phase = _Phase.ready;
    });
  }

  List<bool> _freshRead() {
    final story = _story;
    if (story == null) return [];
    return List.filled(
      readingUnits(story.sentences[_sentenceIdx], chinese: story.chinese)
          .length,
      false,
    );
  }

  void _startGame() {
    if (_playtimeLocked) return;
    final ok = _listener.start(
      lang: _chinese ? 'zh-CN' : 'en-US',
      onTranscript: _onTranscript,
      onError: () {
        if (mounted) setState(() => _micDenied = true);
      },
    );
    setState(() {
      _phase = _Phase.playing;
      _altitude = max(_altitude, 0.5);
      _lastSpeech = DateTime.now();
      _transcript = '';
      _consumed = 0;
      _advancing = false;
      _resetWorld();
      _micDenied = !ok && !SpeechListener.supported;
    });
    _timer?.cancel();
    _timer = Timer.periodic(_tick, _onTick);
  }

  void _resetWorld() {
    _eaten = false;
    _coins.clear();
    _sharks.clear();
    _nextCoinIn = 3;
    _nextSharkIn = 6;
  }

  void _stopGame() {
    _timer?.cancel();
    _timer = null;
    _listener.stop();
  }

  void _onTick(Timer t) {
    if (_phase != _Phase.playing || !mounted) return;
    final dt = _tick.inMilliseconds / 1000;
    final speaking = DateTime.now().difference(_lastSpeech) < _speechFresh;
    setState(() {
      _altitude += (speaking ? _riseRate : -_fallRate) * dt;
      _altitude = _altitude.clamp(0.0, 1.0);
      _stepWorld(dt);
    });
    if (_altitude <= 0) {
      _gameOver();
    } else if (_sharkBites()) {
      _gameOver(eaten: true);
    }
  }

  void _stepWorld(double dt) {
    final dx = _scrollSpeed * dt;
    _scroll += dx;
    for (final c in _coins) {
      c.x -= dx;
    }
    for (final sh in _sharks) {
      sh.x -= dx * 1.15; // sharks swim a little faster than the scenery
    }
    _coins.removeWhere((c) => c.x < -0.1);
    _sharks.removeWhere((sh) => sh.x < _dogX - _jumpHalfWidth - 0.1);

    // Coins sit up high, so the dog has to be reading to reach them.
    _nextCoinIn -= dt;
    if (_nextCoinIn <= 0 && _coins.length < 2) {
      _coins.add(_Coin(1.1, 0.72 + _rng.nextDouble() * 0.23));
      _nextCoinIn = 5 + _rng.nextDouble() * 3;
    }
    _nextSharkIn -= dt;
    if (_nextSharkIn <= 0 && _sharks.isEmpty) {
      _sharks.add(_Shark(1.1));
      _nextSharkIn = 8 + _rng.nextDouble() * 5;
    }

    // Collect coins the dog touches.
    final hit = _coins
        .where(
          (c) =>
              (c.x - _dogX).abs() < _hitRadius &&
              (c.alt - _altitude).abs() < 0.12,
        )
        .toList();
    for (final c in hit) {
      _coins.remove(c);
      _points += 5;
      Celebration.reward(context);
    }
  }

  /// Altitude of [shark] above the water: 0 while cruising, an arc while
  /// it is leaping through the dog's column.
  double _sharkAlt(_Shark shark) {
    final u = (shark.x - _dogX) / _jumpHalfWidth;
    if (u.abs() >= 1) return 0;
    return _jumpHeight * (1 - u * u);
  }

  bool _sharkBites() {
    for (final sh in _sharks) {
      if ((sh.x - _dogX).abs() < _hitRadius &&
          _altitude < _sharkAlt(sh) + 0.05) {
        return true;
      }
    }
    return false;
  }

  void _gameOver({bool eaten = false}) {
    _stopGame();
    setState(() {
      _eaten = eaten;
      _phase = _Phase.over;
    });
  }

  void _onTranscript(String transcript) {
    if (!mounted || _phase != _Phase.playing) return;
    if (transcript.length < _consumed) _consumed = 0; // new session
    if (transcript.trim().isNotEmpty) _lastSpeech = DateTime.now();
    _transcript = transcript;
    final story = _story;
    if (story == null || _advancing) return;
    final units = readingUnits(
      story.sentences[_sentenceIdx],
      chinese: story.chinese,
    );
    final read = unitsRead(
      units,
      transcript.substring(_consumed),
      chinese: story.chinese,
    );
    setState(() => _read = read);
    if (readCoverage(read) >= readPassThreshold) _sentenceDone();
  }

  Future<void> _sentenceDone() async {
    final story = _story!;
    _advancing = true;
    _consumed = _transcript.length;
    final word = story.wordForSentence[_sentenceIdx];
    setState(() {
      _points += 10;
      _altitude = min(1.0, _altitude + 0.2);
      _read = List.filled(_read.length, true);
    });
    Celebration.correct(context);
    Celebration.xpPop(context, 10);
    Celebration.reward(context, withSound: false);
    if (word != null) gameProvider.submitReview(word.id, 5);

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted || _phase != _Phase.playing) return;
    if (_sentenceIdx + 1 >= story.sentences.length) {
      _stopGame();
      Celebration.confetti(context);
      await gameProvider.loadUserStats();
      if (mounted) setState(() => _phase = _Phase.done);
      return;
    }
    setState(() {
      _sentenceIdx++;
      _read = _freshRead();
      _advancing = false;
    });
  }

  void _restart() {
    setState(() {
      _sentenceIdx = 0;
      _points = 0;
      _altitude = 0.5;
      _read = _freshRead();
      _resetWorld();
      _phase = _Phase.ready;
    });
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7EC8F5),
      body: Stack(
        children: [
          Positioned.fill(child: _buildScene()),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                if (_story != null) _buildSentenceCard(),
              ],
            ),
          ),
          if (_phase == _Phase.loading)
            const Center(child: CircularProgressIndicator()),
          if (_phase == _Phase.ready) _buildOverlay(_readyContent()),
          if (_phase == _Phase.over) _buildOverlay(_overContent()),
          if (_phase == _Phase.done) _buildOverlay(_doneContent()),
          if (_playtimeLocked) _buildOverlay(_lockedContent()),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'flying-dog-config',
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: DuolingoColors.darkText,
                tooltip: 'Settings',
                onPressed: _openSettings,
                child: const Icon(Icons.settings),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _story?.title ?? '',
              overflow: TextOverflow.ellipsis,
              style: DuolingoTextStyles.pageTitle.copyWith(color: Colors.white),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '⭐ $_points',
              style: DuolingoTextStyles.label.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceCard() {
    final story = _story!;
    final sentence = story.sentences[_sentenceIdx];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusDialog),
        ),
        child: Column(
          children: [
            Text(
              '${_sentenceIdx + 1} / ${story.sentences.length}',
              style: DuolingoTextStyles.label.copyWith(
                color: DuolingoColors.bodyText,
              ),
            ),
            const SizedBox(height: 8),
            story.chinese ? _chineseSentence(sentence) : _englishSentence(sentence),
            if (_notice != null) ...[
              const SizedBox(height: 8),
              Text(
                _notice!,
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.label.copyWith(
                  color: DuolingoColors.bodyText,
                ),
              ),
            ],
            if (_micDenied) ...[
              const SizedBox(height: 8),
              Text(
                _chinese
                    ? '无法使用麦克风，请在浏览器（Chrome）中允许麦克风权限。'
                    : 'Speech recognition needs microphone permission in a supported browser (Chrome).',
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.label.copyWith(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _unitColor(int unit) => (unit < _read.length && _read[unit])
      ? DuolingoColors.primaryGreen
      : DuolingoColors.darkText;

  Widget _englishSentence(String sentence) {
    var unit = 0;
    final spans = <InlineSpan>[];
    for (final m in RegExp(r"[A-Za-z']+|[^A-Za-z']+").allMatches(sentence)) {
      final tok = m.group(0)!;
      final isWord = RegExp(r"^[A-Za-z']").hasMatch(tok);
      spans.add(
        TextSpan(
          text: tok,
          style: TextStyle(color: isWord ? _unitColor(unit) : DuolingoColors.darkText),
        ),
      );
      if (isWord) unit++;
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.4),
    );
  }

  Widget _chineseSentence(String sentence) {
    var unit = 0;
    final cells = <Widget>[];
    for (final ch in sentence.split('')) {
      final isHan = ch.codeUnitAt(0) >= 0x4E00 && ch.codeUnitAt(0) <= 0x9FFF;
      final color = isHan ? _unitColor(unit) : DuolingoColors.darkText;
      String py = '';
      if (isHan && _pinyin) {
        try {
          py = PinyinHelper.getPinyin(
            ch,
            format: PinyinFormat.WITH_TONE_MARK,
          );
        } catch (_) {}
      }
      cells.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pinyin)
              Text(
                py,
                style: TextStyle(fontSize: 13, color: color.withOpacity(0.8)),
              ),
            Text(
              ch,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      );
      if (isHan) unit++;
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 6,
      children: cells,
    );
  }

  Widget _buildScene() {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final seaHeight = h * 0.22;
        // Dog flies between just above the waves and near the sentence card.
        final minBottom = seaHeight - 10;
        final maxBottom = h - 300;
        final range = (maxBottom - minBottom).clamp(60.0, h);
        double bottomFor(double alt) => minBottom + range * alt;
        final flap = sin(DateTime.now().millisecondsSinceEpoch / 110);

        // Scenery loops: position = base - scroll*parallax, wrapped.
        double loop(double base, double factor) {
          final v = (base - _scroll * factor) % 1.3;
          return (v < 0 ? v + 1.3 : v) - 0.15;
        }

        Widget cloud(double base, double factor, double top, double size) =>
            Positioned(
              left: loop(base, factor) * w,
              top: top,
              child: Text('☁️', style: TextStyle(fontSize: size)),
            );

        const waveRow = '🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊';
        Widget waves(double top, double factor, double size, double opacity) {
          final period = size * 1.25; // approx width of one wave glyph
          final off = (_scroll * factor * w) % period;
          return Positioned(
            left: -off - period,
            top: top,
            child: Opacity(
              opacity: opacity,
              child: Text(
                waveRow * 3,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(fontSize: size),
              ),
            ),
          );
        }

        return ClipRect(
          child: Stack(
            children: [
              cloud(0.1, 0.25, 190, 48),
              cloud(0.6, 0.15, 290, 64),
              cloud(0.95, 0.35, 120, 40),
              const Positioned(
                right: 30,
                top: 100,
                child: Text('☀️', style: TextStyle(fontSize: 56)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: seaHeight,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2E9BD6), Color(0xFF14588C)],
                    ),
                  ),
                ),
              ),
              waves(h - seaHeight - 14, 0.9, 28, 1),
              // Coins.
              for (final coin in _coins)
                Positioned(
                  left: coin.x * w - 16,
                  bottom: bottomFor(coin.alt),
                  child: const Text('🪙', style: TextStyle(fontSize: 34)),
                ),
              // Sharks: fin cruising on the surface, then a leap.
              for (final sh in _sharks)
                Positioned(
                  left: sh.x * w - 30,
                  bottom: bottomFor(_sharkAlt(sh)) - 26,
                  child: Text(
                    '🦈',
                    style: TextStyle(fontSize: _sharkAlt(sh) > 0 ? 60 : 46),
                  ),
                ),
              waves(h - seaHeight + 10, 1.5, 32, 0.9),
              waves(h - seaHeight + 46, 2.1, 36, 0.7),
              Positioned(
                left: _dogX * w - 65,
                bottom: bottomFor(_altitude),
                child: _dog(flap, splash: _phase == _Phase.over && !_eaten),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dog(double flap, {required bool splash}) {
    Widget wing(double sign) => Transform.rotate(
      angle: sign * (0.5 + 0.35 * flap),
      child: Container(
        width: 34,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.blue.shade100),
        ),
      ),
    );
    return SizedBox(
      width: 130,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 4, top: 14, child: wing(-1)),
          Positioned(right: 4, top: 14, child: wing(1)),
          const Text('🐕', style: TextStyle(fontSize: 56)),
          if (splash) const Positioned(bottom: 0, child: Text('💦', style: TextStyle(fontSize: 34))),
        ],
      ),
    );
  }

  Widget _buildOverlay(Widget child) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DuolingoSpacing.radiusDialog),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _bigButton(String label, VoidCallback onTap) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: DuolingoColors.primaryGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
    ),
    onPressed: onTap,
    child: Text(label, style: DuolingoTextStyles.label.copyWith(color: Colors.white)),
  );

  Widget _readyContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('🐕', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 8),
      Text(
        _chinese ? '大声朗读，让小狗飞得更高！' : 'Read out loud to keep the dog flying!',
        textAlign: TextAlign.center,
        style: DuolingoTextStyles.body,
      ),
      const SizedBox(height: 8),
      Text(
        _chinese
            ? '不出声，小狗就会掉进大海。飞高一点拿金币，躲开鲨鱼！'
            : 'Stay quiet and it falls into the sea. Fly high to grab coins and dodge the sharks!',
        textAlign: TextAlign.center,
        style: DuolingoTextStyles.label.copyWith(color: DuolingoColors.bodyText),
      ),
      const SizedBox(height: 16),
      _bigButton(_chinese ? '开始 🎤' : 'START 🎤', _startGame),
    ],
  );

  Widget _overContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(_eaten ? '🦈' : '💦', style: const TextStyle(fontSize: 56)),
      Text(
        _eaten
            ? (_chinese ? '小狗被鲨鱼吃掉了！' : 'Eaten by a shark! Fly higher!')
            : (_chinese ? '小狗掉进海里了！' : 'Splash! Game over'),
        textAlign: TextAlign.center,
        style: DuolingoTextStyles.pageTitle,
      ),
      const SizedBox(height: 8),
      Text('⭐ $_points', style: DuolingoTextStyles.body),
      const SizedBox(height: 16),
      _bigButton(_chinese ? '再来一次' : 'TRY AGAIN', _restart),
      TextButton(
        onPressed: _loadStory,
        child: Text(_chinese ? '换个故事' : 'NEW STORY'),
      ),
    ],
  );

  Widget _doneContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('🎉', style: TextStyle(fontSize: 56)),
      Text(_chinese ? '故事读完啦！' : 'Story complete!', style: DuolingoTextStyles.pageTitle),
      const SizedBox(height: 8),
      Text('⭐ $_points', style: DuolingoTextStyles.body),
      const SizedBox(height: 16),
      _bigButton(_chinese ? '新故事' : 'NEW STORY', _loadStory),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_chinese ? '关闭' : 'CLOSE'),
      ),
    ],
  );

  Widget _lockedContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('⏰', style: TextStyle(fontSize: 48)),
      Text("Time's up for today!", style: DuolingoTextStyles.pageTitle),
      const SizedBox(height: 16),
      _bigButton('BACK', () => Navigator.pop(context)),
    ],
  );

  void _openSettings() {
    if (_phase == _Phase.playing) {
      _stopGame();
      setState(() => _phase = _Phase.ready);
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void change(VoidCallback fn, {bool reload = false}) {
            setSheet(fn);
            setState(() {});
            _saveSettings();
            if (reload) {
              Navigator.pop(ctx);
              _loadStory();
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Language / 语言', style: DuolingoTextStyles.label),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('English')),
                      ButtonSegment(value: true, label: Text('中文')),
                    ],
                    selected: {_chinese},
                    onSelectionChanged: (s) =>
                        change(() => _chinese = s.first, reload: true),
                  ),
                  const SizedBox(height: 16),
                  Text('Story / 故事', style: DuolingoTextStyles.label),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Spelling story')),
                      ButtonSegment(value: false, label: Text('Reading story')),
                    ],
                    selected: {_spellingStory},
                    onSelectionChanged: (s) =>
                        change(() => _spellingStory = s.first, reload: true),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pinyin 拼音 (Chinese)'),
                    value: _pinyin,
                    onChanged: (v) => change(() => _pinyin = v),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

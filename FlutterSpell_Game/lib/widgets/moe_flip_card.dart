import 'dart:math';
import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/moe_word_models.dart';
import 'package:spell_game/utils/moe_phrases.dart';

/// A Buzzi-style (https://chinese.getbuzzi.com) flip flashcard for a single
/// MOE character. Front: the character, large, with a tap-to-play audio
/// button. Back: pinyin, English meaning, a "practiced N times" badge, and
/// a "Practice writing" button. Tapping anywhere on the card (other than
/// the audio/practice buttons) flips it and plays the audio automatically.
class MoeFlipCard extends StatefulWidget {
  final MoeCharacter character;
  final double width;
  final double height;
  final VoidCallback? onPlayAudio;

  /// Called when the card turns to its back, to read the character and its
  /// 词语. Falls back to [onPlayAudio] when not provided.
  final VoidCallback? onPlayBackAudio;
  final VoidCallback? onPracticeWriting;
  final bool isDifficult;
  final VoidCallback? onToggleDifficult;

  /// When true (Anki mode), shows an Again/Hard/Good/Easy SM-2 rating row
  /// on the back face above the "Practice writing" button, and [onRate]
  /// must be provided. Defaults to false so existing callers (browse mode)
  /// render exactly as before.
  final bool showRatingButtons;
  final void Function(int quality)? onRate;

  const MoeFlipCard({
    super.key,
    required this.character,
    this.width = 260,
    this.height = 320,
    this.onPlayAudio,
    this.onPlayBackAudio,
    this.onPracticeWriting,
    this.isDifficult = false,
    this.onToggleDifficult,
    this.showRatingButtons = false,
    this.onRate,
  });

  @override
  State<MoeFlipCard> createState() => MoeFlipCardState();
}

class MoeFlipCardState extends State<MoeFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showingFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    if (MoePhrases.forCharacter(widget.character.text).isEmpty) {
      MoePhrases.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant MoeFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new character (e.g. swiped to a different card) should always
    // start front-side-up rather than keep whatever flip state the
    // previous character was left in.
    if (oldWidget.character.id != widget.character.id && !_showingFront) {
      _controller.value = 0;
      _showingFront = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void flip() {
    setState(() {
      _showingFront = !_showingFront;
      if (_showingFront) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });
    // Read the character aloud each time the card turns over. This runs
    // inside the tap that triggered the flip, which keeps iOS Safari's
    // user-gesture requirement for audio satisfied.
    if (_showingFront) {
      widget.onPlayAudio?.call();
    } else {
      (widget.onPlayBackAudio ?? widget.onPlayAudio)?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: flip,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final angle = _controller.value * pi;
            final showFrontFace = angle <= pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: showFrontFace
                  ? _buildFront()
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _buildBack(),
                    ),
            );
          },
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    gradient: const LinearGradient(
      colors: DuolingoColors.wordCardsGradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
    border: Border.all(color: DuolingoColors.specialPurple, width: 2),
    boxShadow: DuolingoShadows.cardShadow,
  );

  Widget _buildStarButton() {
    return GestureDetector(
      onTap: widget.onToggleDifficult,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
        child: Text(
          widget.isDifficult ? '⭐' : '☆',
          style: TextStyle(
            fontSize: 18,
            color: widget.isDifficult
                ? DuolingoColors.streakOrange
                : DuolingoColors.bodyText,
          ),
        ),
      ),
    );
  }

  Widget _buildFront() {
    final c = widget.character;
    return Container(
      decoration: _cardDecoration,
      padding: EdgeInsets.all(DuolingoSpacing.lg),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 0, right: 0, child: _buildStarButton()),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (c.writeRequired)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 36),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: DuolingoSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DuolingoColors.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '✍️ Write',
                        style: DuolingoTextStyles.label.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                c.text,
                style: DuolingoTextStyles.pageTitle.copyWith(
                  fontSize: 96,
                  color: DuolingoColors.darkText,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onPlayAudio,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: DuolingoColors.informationBlue,
                    borderRadius: BorderRadius.circular(
                      DuolingoSpacing.radiusButton,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF1876BF),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.volume_up,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              SizedBox(height: DuolingoSpacing.sm),
              Text(
                'Tap to flip',
                style: DuolingoTextStyles.label.copyWith(
                  color: DuolingoColors.bodyText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Anki-style Again/Hard/Easy row, mapped to the standard SM-2 quality
  /// scale the backend's `update_sm2` branches on (>=3 passes, <3 fails and
  /// resets the interval) - matches the app's existing 0/1/3/5 convention.
  Widget _buildRatingRow() {
    final ratings = [
      (0, 'Again', DuolingoColors.mistakeRed),
      (3, 'Hard', DuolingoColors.streakOrange),
      (5, 'Easy', DuolingoColors.primaryGreen),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ratings
          .map(
            (r) => Padding(
              padding: EdgeInsets.symmetric(horizontal: DuolingoSpacing.xs),
              child: _buildRatingButton(
                quality: r.$1,
                label: r.$2,
                color: r.$3,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRatingButton({
    required int quality,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => widget.onRate?.call(quality),
      child: Container(
        width: 56,
        padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.sm),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: DuolingoTextStyles.label.copyWith(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBack() {
    final c = widget.character;
    final phrases = MoePhrases.forCharacter(c.text);
    return Container(
      decoration: _cardDecoration,
      padding: EdgeInsets.all(DuolingoSpacing.lg),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 0, right: 0, child: _buildStarButton()),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  c.text,
                  style: DuolingoTextStyles.cardTitle.copyWith(fontSize: 28),
                ),
                SizedBox(height: DuolingoSpacing.sm),
                Text(
                  c.pinyin ?? '—',
                  style: DuolingoTextStyles.sectionTitle.copyWith(
                    color: DuolingoColors.informationBlue,
                  ),
                ),
                SizedBox(height: DuolingoSpacing.sm),
                Text(
                  c.meaning ?? '',
                  textAlign: TextAlign.center,
                  style: DuolingoTextStyles.body,
                ),
                if (phrases.isNotEmpty) ...[
                  SizedBox(height: DuolingoSpacing.sm),
                  Text(
                    phrases.join('   '),
                    textAlign: TextAlign.center,
                    style: DuolingoTextStyles.sectionTitle.copyWith(
                      color: DuolingoColors.darkText,
                    ),
                  ),
                ],
                SizedBox(height: DuolingoSpacing.lg),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: DuolingoSpacing.md,
                    vertical: DuolingoSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: DuolingoColors.rewardYellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Practiced ${c.practicedCount} ${c.practicedCount == 1 ? 'time' : 'times'}',
                    style: DuolingoTextStyles.label.copyWith(
                      color: DuolingoColors.darkText,
                    ),
                  ),
                ),
                SizedBox(height: DuolingoSpacing.md),
                GestureDetector(
                  onTap: widget.onPracticeWriting,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: DuolingoSpacing.lg,
                      vertical: DuolingoSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: DuolingoColors.primaryGreen,
                      borderRadius: BorderRadius.circular(
                        DuolingoSpacing.radiusButton,
                      ),
                    ),
                    child: Text(
                      'Practice writing ✍️',
                      style: DuolingoTextStyles.label.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (widget.showRatingButtons) ...[
                  SizedBox(height: DuolingoSpacing.xxl),
                  _buildRatingRow(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

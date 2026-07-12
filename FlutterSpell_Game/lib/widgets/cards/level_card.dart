import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class LevelCard extends StatefulWidget {
  final String icon;
  final String name;
  final String difficulty;
  final int wordCount;
  final int starsEarned; // 0-3
  final bool isLocked;
  final bool isCompleted;
  final VoidCallback? onPlayTap;
  final VoidCallback? onReviewTap;

  const LevelCard({
    Key? key,
    required this.icon,
    required this.name,
    required this.difficulty,
    required this.wordCount,
    required this.starsEarned,
    this.isLocked = false,
    this.isCompleted = false,
    this.onPlayTap,
    this.onReviewTap,
  }) : super(key: key);

  @override
  State<LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<LevelCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isLocked ? DuolingoColors.neutralGray : DuolingoColors.informationBlue;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered && !widget.isLocked ? -4 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: DuolingoColors.levelCardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          boxShadow: _isHovered && !widget.isLocked
              ? DuolingoShadows.cardHoverShadow
              : DuolingoShadows.cardShadow,
        ),
        child: Opacity(
          opacity: widget.isLocked ? 0.5 : 1.0,
          child: Padding(
            padding: EdgeInsets.all(DuolingoSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side: icon, name, difficulty, word count
                Expanded(
                  child: Row(
                    children: [
                      Text(widget.icon, style: TextStyle(fontSize: DuolingoSpacing.iconSize)),
                      SizedBox(width: DuolingoSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(widget.name, style: DuolingoTextStyles.cardTitle),
                            SizedBox(height: DuolingoSpacing.xs),
                            Text(
                              '${widget.difficulty} • ${widget.wordCount} words',
                              style: DuolingoTextStyles.body,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: DuolingoSpacing.lg),

                // Right side: stars and button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: List.generate(3, (i) {
                        final isFilled = i < widget.starsEarned;
                        return Padding(
                          padding: EdgeInsets.only(left: DuolingoSpacing.xs),
                          child: Text(
                            '⭐',
                            style: TextStyle(
                              fontSize: 16,
                              color: isFilled ? DuolingoColors.streakOrange : DuolingoColors.neutralGray,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: DuolingoSpacing.md),
                    _buildButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton() {
    if (widget.isLocked) {
      return _Button(label: 'Unlock', onTap: null, isPrimary: false);
    }
    if (widget.isCompleted) {
      return _Button(label: 'Review', onTap: widget.onReviewTap, isPrimary: false);
    }
    return _Button(label: 'Play', onTap: widget.onPlayTap, isPrimary: true);
  }
}

class _Button extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _Button({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: DuolingoSpacing.lg,
          vertical: DuolingoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isPrimary ? DuolingoColors.primaryGreen : DuolingoColors.secondaryButtonGray,
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        ),
        child: Text(
          label,
          style: DuolingoTextStyles.label.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

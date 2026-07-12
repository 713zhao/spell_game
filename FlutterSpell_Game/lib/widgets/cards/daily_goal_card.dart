import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

const double _progressBarBgOpacity = 0.6;

class DailyGoalCard extends StatefulWidget {
  final int completed;
  final int total;
  final VoidCallback? onTap;

  const DailyGoalCard({
    Key? key,
    required this.completed,
    required this.total,
    this.onTap,
  }) : super(key: key);

  @override
  State<DailyGoalCard> createState() => _DailyGoalCardState();
}

class _DailyGoalCardState extends State<DailyGoalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _initializeAnimation();
    _controller.forward();
  }

  void _initializeAnimation() {
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.completed / widget.total,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(DailyGoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completed != widget.completed ||
        oldWidget.total != widget.total) {
      _controller.reset();
      _initializeAnimation();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _progress => widget.completed / widget.total;
  int get _filledStars => ((widget.completed / widget.total) * 3).ceil();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: DuolingoSpacing.minTouchTarget),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: DuolingoColors.infoGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          boxShadow: DuolingoShadows.cardShadow,
        ),
        padding: EdgeInsets.all(DuolingoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Label and stars
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📍 DAILY GOAL',
                  style: DuolingoTextStyles.label.copyWith(
                    color: DuolingoColors.informationBlue,
                  ),
                ),
                Row(
                  children: List.generate(3, (i) {
                    final isFilled = i < _filledStars;
                    return Padding(
                      padding: EdgeInsets.only(left: DuolingoSpacing.xs),
                      child: Text(
                        '⭐',
                        style: TextStyle(
                          fontSize: DuolingoSpacing.starSize,
                          color: isFilled
                              ? DuolingoColors.streakOrange
                              : DuolingoColors.neutralGray,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            SizedBox(height: DuolingoSpacing.md),

            // Progress bar
            Container(
              width: double.infinity,
              height: DuolingoSpacing.progressBarHeight,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_progressBarBgOpacity),
                borderRadius: BorderRadius.circular(DuolingoSpacing.radiusBadge),
              ),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            DuolingoColors.primaryGreen,
                            DuolingoColors.primaryGreenLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusBadge),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: DuolingoSpacing.md),

            // Status text
            Text(
              '${widget.completed} of ${widget.total} lessons completed',
              style: DuolingoTextStyles.body.copyWith(
                color: DuolingoColors.informationBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

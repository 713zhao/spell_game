import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class JourneyCard extends StatelessWidget {
  final String kingdom; // "english" or "chinese"
  final String icon; // 🏰 or 🐉
  final String label; // "English Kingdom" or "Chinese Kingdom"
  final String current; // "Stage 5" or "Forest Stage 7"
  final int completed; // 8
  final int total; // 10
  final int stars; // 0-3
  final VoidCallback onTap;

  const JourneyCard({
    Key? key,
    required this.kingdom,
    required this.icon,
    required this.label,
    required this.current,
    required this.completed,
    required this.total,
    required this.stars,
    required this.onTap,
  }) : super(key: key);

  List<Color> get _gradientColors {
    switch (kingdom) {
      case 'english':
        return DuolingoColors.englishKingdomGradient;
      case 'chinese':
        return DuolingoColors.chineseKingdomGradient;
      default:
        return DuolingoColors.infoGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          border: Border.all(
            color: const Color(0xFF1F9DFF),
            width: 2,
          ),
          boxShadow: DuolingoShadows.cardShadow,
        ),
        padding: EdgeInsets.all(DuolingoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$icon $label',
                  style: DuolingoTextStyles.cardTitle,
                ),
                Row(
                  children: List.generate(3, (i) {
                    final filled = i < stars;
                    return Text(
                      '⭐',
                      style: TextStyle(
                        fontSize: 16,
                        color: filled ? Colors.orange : Colors.grey[300],
                      ),
                    );
                  }),
                ),
              ],
            ),
            SizedBox(height: DuolingoSpacing.md),
            Text(
              current,
              style: DuolingoTextStyles.body,
            ),
            SizedBox(height: DuolingoSpacing.sm),
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: total > 0 ? completed / total : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        DuolingoColors.primaryGreen,
                        Color(0xFF7ed321),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            SizedBox(height: DuolingoSpacing.sm),
            Text(
              '$completed/$total',
              style: DuolingoTextStyles.label,
            ),
            SizedBox(height: DuolingoSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: DuolingoSpacing.lg,
                    vertical: DuolingoSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: DuolingoColors.primaryGreen,
                    borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                    boxShadow: DuolingoShadows.cardShadow,
                  ),
                  child: Text(
                    'Continue ▶',
                    style: DuolingoTextStyles.label.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

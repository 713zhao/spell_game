import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class BossBattleCard extends StatelessWidget {
  final String bossName;
  final int weakWordsCount;
  final List<String> weakWords;
  final VoidCallback onTap;

  const BossBattleCard({
    Key? key,
    required this.bossName,
    required this.weakWordsCount,
    required this.weakWords,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: DuolingoColors.bossArenaGradient,
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
            Text('⚔️ Boss Battle', style: DuolingoTextStyles.cardTitle),
            SizedBox(height: DuolingoSpacing.sm),
            Text(
              '$weakWordsCount difficult ${weakWordsCount == 1 ? 'word' : 'words'} remain!',
              style: DuolingoTextStyles.body,
            ),
            SizedBox(height: DuolingoSpacing.md),
            Text(
              weakWords.join(' • '),
              style: DuolingoTextStyles.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
                    color: DuolingoColors.mistakeRed,
                    borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                  ),
                  child: Text(
                    'Fight ▶',
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

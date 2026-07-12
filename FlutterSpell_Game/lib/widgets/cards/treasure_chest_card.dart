import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class TreasureChestCard extends StatelessWidget {
  final bool isAvailable;
  final String reward;
  final VoidCallback onTap;

  const TreasureChestCard({
    Key? key,
    required this.isAvailable,
    required this.reward,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: DuolingoColors.treasureIslandGradient,
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🎁 Daily Treasure Chest', style: DuolingoTextStyles.cardTitle),
                if (isAvailable)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: DuolingoSpacing.sm,
                      vertical: DuolingoSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: DuolingoColors.primaryGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('NEW', style: DuolingoTextStyles.label.copyWith(color: Colors.white, fontSize: 10)),
                  ),
              ],
            ),
            SizedBox(height: DuolingoSpacing.md),
            Text(
              isAvailable ? 'Open to claim reward' : 'Available tomorrow',
              style: DuolingoTextStyles.body,
            ),
            if (isAvailable) Text(reward, style: DuolingoTextStyles.label),
            SizedBox(height: DuolingoSpacing.md),
            GestureDetector(
              onTap: isAvailable ? onTap : null,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DuolingoSpacing.lg,
                  vertical: DuolingoSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isAvailable ? DuolingoColors.primaryGreen : Colors.grey,
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
                child: Text(
                  isAvailable ? 'Open ▶' : 'Locked',
                  style: DuolingoTextStyles.label.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

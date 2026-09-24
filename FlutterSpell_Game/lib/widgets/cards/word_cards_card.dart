import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

/// Home screen entry point into the "Chinese Word Cards" flip-card
/// browsing screen (official MOE Primary 1 vocabulary).
class WordCardsCard extends StatelessWidget {
  final VoidCallback onTap;

  const WordCardsCard({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: DuolingoColors.wordCardsGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          border: Border.all(color: DuolingoColors.specialPurple, width: 2),
          boxShadow: DuolingoShadows.cardShadow,
        ),
        padding: EdgeInsets.all(DuolingoSpacing.lg),
        child: Row(
          children: [
            const Text('🈶', style: TextStyle(fontSize: 36)),
            SizedBox(width: DuolingoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chinese Word Cards', style: DuolingoTextStyles.cardTitle),
                  SizedBox(height: DuolingoSpacing.xs),
                  Text(
                    'Flip through official MOE Primary 1 characters',
                    style: DuolingoTextStyles.body,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DuolingoColors.darkText),
          ],
        ),
      ),
    );
  }
}

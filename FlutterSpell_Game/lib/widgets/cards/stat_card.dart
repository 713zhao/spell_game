import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const StatCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  }) : super(key: key);

  List<Color> get _gradientColors {
    if (label.toUpperCase() == 'STREAK') {
      return DuolingoColors.streakGradient;
    }
    return DuolingoColors.rewardGradient;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: DuolingoSpacing.minTouchTarget),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          boxShadow: DuolingoShadows.cardShadow,
        ),
        padding: EdgeInsets.all(DuolingoSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            SizedBox(height: DuolingoSpacing.sm),
            Text(
              label,
              style: DuolingoTextStyles.label,
            ),
            SizedBox(height: DuolingoSpacing.xs),
            Text(
              value,
              style: DuolingoTextStyles.largeValue,
            ),
          ],
        ),
      ),
    );
  }
}

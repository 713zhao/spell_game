import 'package:flutter/material.dart';
import '../design_system/design_system.dart';

/// Bright, kid-friendly avatar colors. Red is deliberately excluded - it
/// already means "wrong answer" throughout the study screens.
const List<Color> avatarColorPalette = [
  DuolingoColors.primaryGreen,
  DuolingoColors.informationBlue,
  DuolingoColors.specialPurple,
  DuolingoColors.streakOrange,
  DuolingoColors.treasureGold,
  Color(0xFF00B8A9), // teal
];

/// Deterministically picks an avatar background color for [name] from
/// [avatarColorPalette], so the same username always gets the same color
/// everywhere it's shown (account button, login quick-pick, profile).
Color avatarColorFor(String name) {
  if (name.isEmpty) return DuolingoColors.neutralGray;
  final upper = name.toUpperCase();
  final hash = upper.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return avatarColorPalette[hash % avatarColorPalette.length];
}

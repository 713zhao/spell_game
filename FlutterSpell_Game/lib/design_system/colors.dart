import 'package:flutter/material.dart';

class DuolingoColors {
  // Primary brand colors
  static const Color primaryGreen = Color(0xFF58CC02);      // Action buttons
  static const Color primaryGreenLight = Color(0xFF7ed321); // Light green gradient
  static const Color streakOrange = Color(0xFFFFA500);      // Streak counter
  static const Color rewardYellow = Color(0xFFFFD700);      // Points/celebration
  static const Color informationBlue = Color(0xFF1F9DFF);   // Info cards
  static const Color mistakeRed = Color(0xFFFF4D4D);        // Wrong answers
  static const Color specialPurple = Color(0xFFA366FF);    // Special lessons

  // Neutrals
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color neutralGray = Color(0xFFF5F5F5);
  static const Color secondaryButtonGray = Color(0xFFCCCCCC);

  // Gradients (for cards)
  static const List<Color> streakGradient = [
    Color(0xFFFFF5E6),  // Light orange
    Color(0xFFFFE6CC),  // Medium orange
  ];

  static const List<Color> rewardGradient = [
    Color(0xFFFFFDE6),
    Color(0xFFFFFFCC),
  ];

  static const List<Color> infoGradient = [
    Color(0xFFE6F5FF),
    Color(0xFFCCE6FF),
  ];

  static const List<Color> levelCardGradient = [
    Color(0xFFF0F9FF),  // Light blue
    Color(0xFFE6F2FF),  // Medium blue
  ];

  // Adventure World specific colors
  static const Color treasureGold = Color(0xFFFFB800);
  static const Color darkText = Color(0xFF333333);
  static const Color bodyText = Color(0xFF666666);

  // New gradients for kingdoms
  static const List<Color> englishKingdomGradient = [Color(0xFFE6F5FF), Color(0xFFCCE6FF)];
  static const List<Color> chineseKingdomGradient = [Color(0xFFFFE6CC), Color(0xFFFFD9B3)];
  static const List<Color> reviewCaveGradient = [Color(0xFFF0E6FF), Color(0xFFE6D9FF)];
  static const List<Color> treasureIslandGradient = [Color(0xFFFFFDE6), Color(0xFFFFFFE0)];
  static const List<Color> bossArenaGradient = [Color(0xFFFFE6E6), Color(0xFFFFCCCC)];
}

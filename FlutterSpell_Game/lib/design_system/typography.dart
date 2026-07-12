import 'package:flutter/material.dart';

class DuolingoTextStyles {
  static const String fontFamily = 'Segoe UI';

  // Page titles and main headings
  static const TextStyle pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Color(0xFF333333),
    fontFamily: fontFamily,
  );

  // Section headers ("Lessons", "Rewards")
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Color(0xFF333333),
    fontFamily: fontFamily,
    letterSpacing: 0.5,
  );

  // Card titles (level names, challenge titles)
  static const TextStyle cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: Color(0xFF333333),
    fontFamily: fontFamily,
  );

  // Body text (descriptions, stats)
  static const TextStyle body = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Color(0xFF666666),
    fontFamily: fontFamily,
  );

  // Labels and tags
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF666666),
    fontFamily: fontFamily,
    letterSpacing: 0.5,
  );

  // Large value numbers (streak, points)
  static const TextStyle largeValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Color(0xFF333333),
    fontFamily: fontFamily,
  );
}

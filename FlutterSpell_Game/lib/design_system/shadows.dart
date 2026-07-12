import 'package:flutter/material.dart';

class DuolingoShadows {
  // Subtle shadow for cards (normal state)
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1A000000),  // 10% black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // Elevated shadow for hover state (lift effect)
  static const List<BoxShadow> cardHoverShadow = [
    BoxShadow(
      color: Color(0x26000000),  // 15% black
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  // Green shadow for success/primary buttons
  static const List<BoxShadow> primaryButtonShadow = [
    BoxShadow(
      color: Color(0x4058CC02),  // Green with transparency
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

# Duolingo-Style UI Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Spell Adventure UI from functional to game-first using Duolingo's proven design system (rounded corners, bright colors, friendly dog mascot, instant feedback, micro-animations).

**Architecture:** Build design system first (centralized colors, typography, spacing), then redesign screens incrementally using new components. Backend unchanged. Pure UI/UX layer redesign with micro-interactions.

**Tech Stack:** Flutter, provider (state management), no new dependencies. Design system constants in `lib/design_system/`, new reusable widgets in `lib/widgets/`, screens redesigned in `lib/screens/`.

---

## Phase 1: Design System (8 tasks, ~2 hours)

### Task 1: Create DuolingoColors class

**Files:**
- Create: `lib/design_system/colors.dart`
- Create: `test/design_system/colors_test.dart`

**Code:**

colors.dart:
```dart
class DuolingoColors {
  // Primary brand colors
  static const Color primaryGreen = Color(0xFF58CC02);      // Action buttons
  static const Color streakOrange = Color(0xFFFFA500);      // Streak counter
  static const Color rewardYellow = Color(0xFFFFD700);      // Points/celebration
  static const Color informationBlue = Color(0xFF1F9DFF);   // Info cards
  static const Color mistakeRed = Color(0xFFFF4D4D);        // Wrong answers
  static const Color specialPurple = Color(0xFFA366FF);    // Special lessons
  
  // Neutrals
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color neutralGray = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF999999);
  
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
}
```

colors_test.dart:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/design_system/colors.dart';

void main() {
  test('DuolingoColors has all required colors', () {
    expect(DuolingoColors.primaryGreen, isNotNull);
    expect(DuolingoColors.streakOrange, isNotNull);
    expect(DuolingoColors.rewardYellow, isNotNull);
    expect(DuolingoColors.informationBlue, isNotNull);
    expect(DuolingoColors.mistakeRed, isNotNull);
    expect(DuolingoColors.specialPurple, isNotNull);
    expect(DuolingoColors.primaryGreen.value, equals(0xFF58CC02));
  });
}
```

**Steps:**
- [ ] Create colors.dart with all 8 colors + gradients
- [ ] Create colors_test.dart with test
- [ ] Run: `flutter test test/design_system/colors_test.dart`
- [ ] Expected: PASS
- [ ] Commit: `git add lib/design_system/colors.dart test/design_system/colors_test.dart && git commit -m "feat: add Duolingo color system"`

---

### Task 2: Create DuolingoTextStyles class

**Files:**
- Create: `lib/design_system/typography.dart`
- Create: `test/design_system/typography_test.dart`

**Code:**

typography.dart:
```dart
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
```

typography_test.dart:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/design_system/typography.dart';

void main() {
  test('DuolingoTextStyles has all required styles', () {
    expect(DuolingoTextStyles.pageTitle.fontSize, equals(24));
    expect(DuolingoTextStyles.pageTitle.fontWeight, equals(FontWeight.bold));
    expect(DuolingoTextStyles.sectionTitle.fontSize, equals(16));
    expect(DuolingoTextStyles.cardTitle.fontSize, equals(14));
    expect(DuolingoTextStyles.body.fontSize, equals(12));
  });
}
```

**Steps:**
- [ ] Create typography.dart with 6 text styles
- [ ] Create typography_test.dart with test
- [ ] Run: `flutter test test/design_system/typography_test.dart`
- [ ] Expected: PASS
- [ ] Commit: `git add lib/design_system/typography.dart test/design_system/typography_test.dart && git commit -m "feat: add Duolingo typography system"`

---

### Task 3: Create DuolingoSpacing class

**Files:**
- Create: `lib/design_system/spacing.dart`
- Create: `test/design_system/spacing_test.dart`

**Code:**

spacing.dart:
```dart
class DuolingoSpacing {
  // 4px grid spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  
  // Border radius
  static const double radiusButton = 16;
  static const double radiusCard = 20;
  static const double radiusDialog = 24;
  static const double radiusAvatar = 30;
  
  // Minimum touch target (48x48px for children)
  static const double minTouchTarget = 48;
}
```

spacing_test.dart:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/design_system/spacing.dart';

void main() {
  test('DuolingoSpacing has all constants', () {
    expect(DuolingoSpacing.xs, equals(4));
    expect(DuolingoSpacing.md, equals(12));
    expect(DuolingoSpacing.radiusCard, equals(20));
    expect(DuolingoSpacing.minTouchTarget, greaterThanOrEqualTo(48));
  });
}
```

**Steps:**
- [ ] Create spacing.dart with spacing and radius constants
- [ ] Create spacing_test.dart with test
- [ ] Run: `flutter test test/design_system/spacing_test.dart`
- [ ] Expected: PASS
- [ ] Commit: `git add lib/design_system/spacing.dart test/design_system/spacing_test.dart && git commit -m "feat: add Duolingo spacing system"`

---

### Task 4: Create DuolingoShadows class

**Files:**
- Create: `lib/design_system/shadows.dart`
- Create: `test/design_system/shadows_test.dart`

**Code:**

shadows.dart:
```dart
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
```

shadows_test.dart:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/design_system/shadows.dart';

void main() {
  test('DuolingoShadows has all shadow definitions', () {
    expect(DuolingoShadows.cardShadow, isNotNull);
    expect(DuolingoShadows.cardShadow.length, equals(1));
    expect(DuolingoShadows.cardHoverShadow.length, equals(1));
  });
}
```

**Steps:**
- [ ] Create shadows.dart with 3 shadow definitions
- [ ] Create shadows_test.dart with test
- [ ] Run: `flutter test test/design_system/shadows_test.dart`
- [ ] Expected: PASS
- [ ] Commit: `git add lib/design_system/shadows.dart test/design_system/shadows_test.dart && git commit -m "feat: add Duolingo shadow system"`

---

### Task 5: Create design_system barrel export

**Files:**
- Create: `lib/design_system/design_system.dart`

**Code:**

design_system.dart:
```dart
export 'colors.dart';
export 'typography.dart';
export 'spacing.dart';
export 'shadows.dart';
```

**Steps:**
- [ ] Create design_system.dart barrel file
- [ ] Run: `flutter analyze` (verify no import errors)
- [ ] Expected: No errors
- [ ] Commit: `git add lib/design_system/design_system.dart && git commit -m "feat: add design system barrel export"`

---

## Execution Notes

**Repository:** C:\ZJB\archive\spell\  
**Branch:** master  
**Test Command:** `flutter test test/design_system/`  
**All Code:** Complete, ready to implement (no TODOs)  
**Backend:** Not needed for Phase 1 (design system only)

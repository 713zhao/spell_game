# Spell Adventure — Duolingo-Style UI Redesign

> **For agentic workers:** Use superpowers:writing-plans to create an implementation plan after design approval.

**Status:** Design Approved | Ready for Implementation Plan  
**Target:** Flutter Web (localhost:8000 backend already functional)  
**Audience:** P1–P4 children (ages 6–12)

---

## 🎯 Goal

Transform Spell Adventure from a functional spelling app into a game-first learning experience inspired by Duolingo's proven design system. Focus on friendly personality, instant rewards, animations, and positive encouragement to build daily learning habits.

**Design Principle:** Every screen should feel like a casual mobile game, not a traditional educational app.

---

## 🎨 Design System

### Color Palette (Duolingo Official)

| Color | Hex | Usage | Psychology |
|-------|-----|-------|-----------|
| Primary Green | #58CC02 | Action buttons, progress bars, success states | Growth, progress, go |
| Streak Orange | #FFA500 | Streak counter, daily bonus multipliers | Energy, momentum, fire |
| Reward Yellow | #FFD700 | Points earned, celebrations | Joy, reward, achievement |
| Information Blue | #1F9DFF | Info cards, daily goals, notifications | Trust, calm, clarity |
| Mistake Red | #FF4D4D | Wrong answers, warnings | Gentle correction (not punitive) |
| Secondary Purple | #A366FF | Special lessons, premium features | Mystery, magic, special |
| Background White | #FFFFFF | Main background | Clean, calm |
| Neutral Gray | #F5F5F5 | Disabled states, secondary backgrounds | Subtle, unobtrusive |

### Typography

**Font Family:** Segoe UI (Flutter default, accessible)

| Element | Size | Weight | Usage |
|---------|------|--------|-------|
| Page Title | 24px | Bold (700) | Screen headers, greeting |
| Section Title | 16px | Bold (700) | "Lessons", "Rewards" headers |
| Card Title | 14px | Bold (700) | Level names, challenge titles |
| Body Text | 12px | Regular (400) | Descriptions, stats |
| Labels | 11px | Semi-bold (600) | Stat labels, tags |

**Characteristics:** Bold, rounded, large, easy to read. Headings stand out. Body text legible for children.

### Spacing & Sizing

**Border Radius:**
- Buttons: 16px
- Cards: 20px
- Dialogs: 24px
- Avatars: 30px (more playful)

**Spacing Grid:** 4px increments
- XS: 4px | S: 8px | M: 12px | L: 16px | XL: 20px | 2XL: 24px

**Touch Targets:** Minimum 48x48px (comfortable for children and elderly users)

---

## 📱 Screen Redesigns

### 1. Home Screen (Priority 1)

**Purpose:** Daily landing page. Shows progress, celebrates user, invites next action.

**Key Elements:**

#### Header Section (Top)
- **Dog Mascot (animated)** 80px emoji with bounce animation
  - Appears on load with celebratory bounce
  - Changes expression based on daily progress (happy at high goal, encouraging if low)
- **Greeting Message** "Let's Learn!" or "Welcome back, [Name]!"
- **Progress Indicator** "3 lessons completed today" or "2 more to reach daily goal!"

#### Stats Cards (Below Header)
Two cards in a row:
- **Streak Card** (Orange gradient background #FFF5E6 → #FFE6CC)
  - Icon: 🔥
  - Label: "STREAK"
  - Value: "12 days"
  - Action: Tap to see streak details (bonus multiplier, milestones, revive cost)

- **Points Card** (Yellow gradient background)
  - Icon: ⭐
  - Label: "POINTS"
  - Value: "485 XP"
  - Action: Tap to see all-time stats

#### Daily Goal Card (Full width)
- Background: Blue gradient (#E6F5FF → #CCE6FF)
- Label: "📍 DAILY GOAL"
- Progress Bar: Green fill (#58CC02), smooth animation
- Status Text: "3 of 5 lessons completed"
- Visual: Stars fill as goal progresses (3/5 = 3 stars)

#### Lessons Section
**Title:** "LESSONS" (uppercase, bold)

**Level Cards** (Vertical list, scrollable):
- Background: Soft gradient (white → light blue)
- Border: 2px solid accent color (blue for available, gray for locked)
- Border-radius: 20px

**Layout per card:**
```
[Icon] Level Name      [Progress]
       Difficulty      [★★☆]
       X words
                       [Play ▶]
```

**Card States:**
- **Available:** Bright, tap-able, shows 3-star progress
- **In Progress:** Highlight with subtle glow effect
- **Locked:** 50% opacity, lock icon (🔒), tap shows "Complete Level X to unlock"
- **Completed:** Full 3 stars, "Review" button instead of "Play"

**Card Interactions:**
- Hover: Lift effect (translateY -4px, subtle shadow)
- Tap: Navigate to study screen or show level preview

#### Bottom Navigation (Always visible)
5 tabs with icons + labels:
- 🏠 Home (active)
- 📚 Study
- 🎁 Rewards
- 🏆 Leaderboard
- 👤 Profile

Active tab color: #58CC02, inactive: #999999

---

### 2. Study Screen (Priority 2)

**Purpose:** Present questions in focused, game-like interface.

**Key Elements:**

#### Header Bar (Minimal)
- Back button (←)
- Level name ("Level 1: Vowels")
- Progress indicator: "Word 3 of 8" with progress bar

#### Question Area (Large, centered)
- **Dog Mascot** (smaller, 40px) top-right corner, reacting to correct/wrong
- **Word Display** Large, colorful text (28px bold)
- **Challenge Type Indicator** Badge ("Multiple Choice" / "Type the Word" / "Speak")

#### Answer Options (Varies by type)

**Multiple Choice:**
- 4 large rounded buttons (#58CC02 or gray background)
- Button text: Spelling options
- Hover: Lift effect
- Selected: Bounce animation + highlight

**Typing:**
- Text input field (rounded, 20px border-radius)
- Large keyboard-friendly input area
- Submit button: "Check" (green #58CC02)
- Show typed text in progress (visual confirmation)

**Speech (TTS):**
- "Tap to Listen" button (blue, rounded)
- Input field below for transcribed answer
- Submit button: "Speak" or "Check"

#### Feedback Section
- **Correct Answer:** 
  - Green flash background (50ms)
  - "✓ Correct!" message
  - Dog mascot celebrates (happy emoji, stars burst animation)
  - Points popup: "+10 XP" floating up
  - Sound effect: cheerful "ding"
  - Auto-advance to next after 1s

- **Wrong Answer:**
  - Red highlight on wrong answer
  - Shake animation on input
  - Encouraging message: "Oops! Try again" or "Almost there!"
  - Show correct answer in green
  - Dog mascot encouraging (concerned emoji → thumbs up)
  - Sound effect: gentle "buzz" (not harsh)
  - Allow retry or move to next

#### Bottom Action Button
- Primary: "Next" (green) after correct answer
- Secondary: "Skip" (gray) after 2 wrong attempts

---

### 3. Rewards Shop Screen (Priority 3)

**Purpose:** Display cosmetics, show progress toward purchases, celebrate purchases.

**Key Elements:**

#### Header
- XP Balance (top-right): "💰 485 XP"
- Title: "REWARDS"

#### Filter/Tabs (Optional for MVP)
- "All" | "Avatars" | "Themes" | "Effects"

#### Cosmetics Grid
- 2 columns (mobile-optimized)
- Each cosmetic card:
  - Preview image/emoji (large)
  - Name (14px bold)
  - Rarity badge (color-coded: common gray, rare blue, epic purple)
  - Cost: "50 XP" in smaller text
  - Status button:
    - If owned & equipped: "✓ Equipped"
    - If owned & not equipped: "Equip" (blue button)
    - If not owned: "Redeem" (green button)

#### Purchase Flow
- Tap "Redeem" → Confirmation dialog
  - Shows cosmetic preview
  - "Cost: 50 XP | You have: 485 XP"
  - Cancel / Confirm buttons
- On confirm:
  - Deduct XP
  - Show celebration animation (confetti, stars)
  - Update balance
  - Close dialog
  - Show newly owned cosmetic

#### My Cosmetics Section (Below shop)
- Toggle/collapse section
- Shows all owned cosmetics
- Equip buttons on hover

---

### 4. Leaderboard Screen (Priority 4)

**Purpose:** Show rankings, encourage friendly competition.

**Key Elements:**

#### Filter Bar
- Dropdown: "Global" / "Friends" / "School" / "Grade"
- Refresh button

#### Top 3 Podium (Celebratory)
Three large cards in a row:
- **2nd Place (Left, smaller):** Silver medal 🥈, user name, points
- **1st Place (Center, largest):** Gold medal 🥇, user name, points, star burst animation
- **3rd Place (Right, smaller):** Bronze medal 🥉, user name, points

#### Leaderboard List (Below podium)
Ranks 4–20 as cards:
- Rank number (4, 5, 6...)
- User avatar (rounded 30px)
- User name
- Points (large, right-aligned)
- Current user highlighted in soft blue background

#### Challenge Section (Optional for MVP)
- Button: "Create Challenge"
- Shows pending challenges from friends
- Each challenge card: opponent name, level, "Accept" button

---

### 5. Profile Screen (Priority 5)

**Purpose:** Show user stats, achievements, settings.

**Key Elements:**

#### User Card (Top)
- Avatar (emoji or image, 60px rounded)
- Name (large, bold)
- Grade/Level (smaller text)
- Edit button (pencil icon)

#### Stats Grid (2x3)
Six stat cards in grid:
- Total Points
- Levels Completed
- Current Streak
- Longest Streak
- Words Learned
- Daily Goal Progress

Each shows icon + number + label.

#### Achievements Section
- Title: "ACHIEVEMENTS"
- 6 badge cards in 2x3 grid
- Each badge: icon + name + progress bar (if not completed)
  - "First Correct Answer" (10/10 needed)
  - "Streak Master" (30 days)
  - "500 Points Earned"
  - "Perfect Lesson" (3 stars)
  - "7-Day Streak"
  - "Level Completion"

#### My Cosmetics (Collapse-able)
- Shows equipped cosmetics
- Grid of owned cosmetics
- Quick equip buttons

#### Settings
- Toggle: "Sound Effects" (ON/OFF)
- Toggle: "Notifications" (ON/OFF)
- Toggle: "Parent Mode" (ON/OFF for parental controls)
- Logout button

---

## 🎬 Animations & Interactions

### Micro-animations (Brief, <500ms)
- **Button tap:** Bounce scale (1.0 → 1.05 → 1.0)
- **Card hover:** Lift up (Y -4px) + shadow increase
- **Progress bar fill:** Smooth width transition (300ms)
- **Star appear:** Pop-in scale (0 → 1.2 → 1) + fade
- **XP popup:** Float up + fade out (1s total)

### Celebratory Animations (1-2s, optional for full version)
- **Correct answer:** Confetti burst, stars shower, dog happy emoji
- **Level complete:** Full-screen celebration, animation cascade
- **Achievement unlock:** Badge bounces in, sparkles around

### Error Animations (Non-punitive)
- **Wrong answer:** Input shake (20px left-right × 3)
- **Locked level:** Pulse animation (opacity 0.7 → 1 → 0.7)

---

## 🎮 Reward Loop Implementation

Every interaction follows this cycle:

```
User taps "Play" (Home)
    ↓
Load Study screen (satisfying fade-in)
    ↓
User answers question
    ↓
Instant feedback (green/red, 50ms flash)
    ↓
Animation plays (stars, confetti, or shake)
    ↓
XP awarded with floating popup
    ↓
Sound effect (success ding or gentle buzz)
    ↓
Auto-advance to next question (1s)
    ↓
Progress bar fills (Level 8/10)
    ↓
[Repeat or Celebrate on Level Complete]
    ↓
Return to Home (update streak, points)
    ↓
"Great job!" message from dog mascot
```

---

## 🔧 Technical Implementation Notes

### Flutter Component Structure

```
lib/
├── design_system/
│   ├── colors.dart (DuolingoColors class)
│   ├── typography.dart (DuolingoTextStyles)
│   ├── spacing.dart (DuolingoSpacing)
│   └── shadows.dart (DuolingoShadows)
├── widgets/
│   ├── buttons/
│   │   ├── primary_button.dart (green, #58CC02)
│   │   ├── secondary_button.dart (gray)
│   │   └── icon_button.dart
│   ├── cards/
│   │   ├── stat_card.dart
│   │   ├── level_card.dart
│   │   ├── cosmetic_card.dart
│   │   └── leaderboard_card.dart
│   ├── progress/
│   │   ├── progress_bar.dart (with animation)
│   │   ├── stars_display.dart
│   │   └── streak_counter.dart
│   └── animations/
│       ├── xp_popup.dart
│       ├── confetti.dart (already exists)
│       ├── celebration.dart
│       └── shake_animation.dart
└── screens/
    ├── home_screen.dart (redesigned)
    ├── study_screen.dart (redesigned)
    ├── rewards_screen.dart (redesigned)
    ├── leaderboard_screen.dart (redesigned)
    └── profile_screen.dart (redesigned)
```

### Design System Constants

All colors, spacing, and animations defined in centralized files for easy theme switching and consistency.

### Responsive Design

- Primary target: Mobile (375px width)
- Fallback: Scale appropriately for tablet/desktop
- Bottom navigation persists on mobile; sidebar option for desktop (future)

---

## ✅ Success Criteria

**Visual Fidelity:**
- ✓ All screens use rounded corners (16–30px)
- ✓ Duolingo green (#58CC02) on CTAs
- ✓ Orange streak counter (#FFA500)
- ✓ All card backgrounds are gradient or soft colors
- ✓ Dog mascot visible on home and study screens

**Interaction Quality:**
- ✓ Every button has hover state (lift + shadow)
- ✓ Every action has instant visual feedback (<100ms)
- ✓ Animations are brief and non-intrusive (<500ms)
- ✓ No loading spinners (instant from cached backend)

**User Experience:**
- ✓ Progress visible everywhere (streaks, points, stars, daily goal)
- ✓ Tone is always encouraging (never punitive)
- ✓ No overwhelming text (max 2 lines per section)
- ✓ Large touch targets (48px+ buttons)
- ✓ Clear hierarchy: one focal point per screen

**Accessibility:**
- ✓ High contrast (text on background)
- ✓ No color-only information (always has icon + text)
- ✓ Large fonts (minimum 12px body, 16px+ headings)
- ✓ Readable for children ages 6–12 and elderly users

---

## 📋 Deployment Notes

**Phase 1:** Build design system + redesign Home screen (high impact, quick)  
**Phase 2:** Redesign Study screen (core interaction)  
**Phase 3:** Redesign Rewards, Leaderboard, Profile screens  
**Phase 4:** Polish animations, add celebratory effects  

**No backend changes needed.** All API endpoints remain the same. This is a pure UI/UX redesign with new visual language and micro-interactions.

---

## 🎨 Reference

- **Duolingo Design:** https://design.duolingo.com (their public design system)
- **Material Design 3:** Rounded corners, elevation shadows
- **Flutter Animation Best Practices:** Brevity, delight without delay
- **Child UX Research:** Large targets, encouraging language, instant feedback


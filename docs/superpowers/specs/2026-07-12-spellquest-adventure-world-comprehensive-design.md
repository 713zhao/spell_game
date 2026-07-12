# SpellQuest Adventure World — Comprehensive Design Spec v3

**Status:** For Final Review & Implementation  
**Version:** 3.0 (Adventure World PRD v2 + Duolingo Design + Game Enhancements)  
**Target:** Flutter Web (localhost:8000 backend)  
**Audience:** Primary & Secondary students (ages 6–14) in Singapore  

**Vision:** The most engaging spelling adventure game. Students open the app because they want to continue their adventure—learning is the tool for progression, not the destination.

---

## 🎮 Core Philosophy

> "What adventure should I continue today?"

This is the **only question** the home page should answer.

**Key Principles:**
1. **Not homework.** Feels like Pokémon, Mario World, or Candy Crush—adventure-first.
2. **One primary action.** Students tap "Continue Adventure" within 5 seconds.
3. **Immersive world.** Curriculum mapping is hidden; students explore kingdoms, not "lessons."
4. **Consistent progression.** Every action (practice, boss fight, daily quest) moves story forward.
5. **No pay-to-win.** Gems earned through gameplay, not purchases (optional: cosmetics-only purchases).

---

## 🎨 Design System (Duolingo Foundation)

### Color Palette
| Color | Hex | Usage | Psychology |
|-------|-----|-------|------------|
| **Primary Green** | #58CC02 | Primary CTAs, progress bars, success states | Growth, go, action |
| **Streak Orange** | #FFA500 | Streak counter, milestones, heat | Energy, momentum |
| **Reward Yellow** | #FFD700 | XP earned, celebrations, treasure | Joy, achievement |
| **Information Blue** | #1F9DFF | Quest cards, info, calm spaces | Trust, clarity |
| **Mistake Red** | #FF4D4D | Boss battles, challenges, weak words | Energy, challenge (not punitive) |
| **Secondary Purple** | #A366FF | Special achievements, rare items, gems | Magic, special, premium |
| **Treasure Gold** | #FFB800 | Treasure chests, rare rewards | Rarity, excitement |
| **Background White** | #FFFFFF | Main background, cards | Clean, calm |
| **Neutral Gray** | #F5F5F5 | Disabled states, secondary surfaces | Subtle |
| **Dark Text** | #333333 | Headings, high contrast | Readability |
| **Body Text** | #666666 | Body text, descriptions | Comfortable |

### Gradients (Kingdom Theming)
- **English Kingdom:** Blue gradient #E6F5FF → #CCE6FF (calm, academic)
- **Chinese Kingdom:** Red/orange gradient #FFE6CC → #FFD9B3 (warm, festive)
- **Review Cave:** Purple gradient #F0E6FF → #E6D9FF (mysterious)
- **Treasure Island:** Gold gradient #FFFDE6 → #FFFFE0 (bright, reward)
- **Boss Arena:** Red gradient #FFE6E6 → #FFCCCC (intensity, challenge)

### Typography
| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Page Title | 24px | Bold (700) | Greeting, screen headers |
| Section Title | 16px | Bold (700) + letter-spacing 0.5px | Kingdom names, "Continue Adventure" |
| Card Title | 14px | Bold (700) | Stage names, challenge titles |
| Body | 12px | Regular (400) | Descriptions, objectives |
| Label | 11px | Semi-bold (600) + letter-spacing 0.5px | Stat labels, badges |
| Large Value | 24px | Bold (700) | XP count, coin amount, streak number |
| Tiny | 10px | Regular (400) | Secondary info, timestamps |

**Font Family:** Segoe UI (accessible, clear for children)

### Spacing Grid
- **xs:** 4px
- **sm:** 8px
- **md:** 12px
- **lg:** 16px
- **xl:** 20px
- **xxl:** 24px

### Border Radius
- **Button:** 16px
- **Card:** 20px
- **Chest:** 24px
- **Avatar:** 30px
- **Kingdom Icon:** 32px

### Shadows
- **Card Default:** 10% black, blur 8px, offset (0, 2px)
- **Card Hover:** 15% black, blur 16px, offset (0, 8px)
- **Button Shadow:** Green #4058CC02, blur 12px, offset (0, 4px)
- **Treasure Glow:** Gold #FFB80040, blur 20px

### Touch Targets
- **Minimum:** 48x48px (children + accessibility)
- **Recommended:** 56x56px for primary actions

---

## 🗺️ World Architecture

### Game Worlds Structure

```
┌─────────────────────────────────────────┐
│         SPELLQUEST ADVENTURE WORLD      │
├─────────────────────────────────────────┤
│                                         │
│  Village (Hub - Always Available)       │
│  ├─ 🏰 English Kingdom (T1-T3)         │
│  │  ├─ Stage 1 (Week 1)                │
│  │  ├─ Stage 2 (Week 2)                │
│  │  └─ ... Stage 15+ (Terminal)        │
│  │                                     │
│  ├─ 🐉 Chinese Kingdom (P3-P6)         │
│  │  ├─ Forest (Lessons 1-10)           │
│  │  ├─ River (Lessons 11-20)           │
│  │  └─ Mountain (Lessons 21-30)        │
│  │                                     │
│  ├─ 🔍 Review Cave                     │
│  │  ├─ Weak Words Dojo                 │
│  │  ├─ Speed Challenge Arena           │
│  │  └─ Perfect Score Trials            │
│  │                                     │
│  ├─ 🏝️ Treasure Island                 │
│  │  ├─ Collection of unlocked items    │
│  │  ├─ Cosmetics showcase              │
│  │  └─ Achievement gallery             │
│  │                                     │
│  └─ ⚔️ Boss Arena (Unlocks with levels)
│     ├─ Boss 1 (After Stage 5)          │
│     ├─ Boss 2 (After Stage 10)         │
│     └─ ... Legendary Bosses            │
│                                         │
└─────────────────────────────────────────┘
```

### Kingdom Progression
- **English Kingdom:** Sequential weeks (can replay any completed stage)
- **Chinese Kingdom:** Sequential within sections (Forest → River → Mountain)
- **Review Cave:** Unlocked after Stage 3 (English) or Lesson 5 (Chinese)
- **Treasure Island:** Unlocked after first boss win
- **Boss Arena:** New bosses unlock every 5 stages

### Hidden Curriculum Mapping
```
Student View:      English Kingdom Stage 5
Maps to:           Teacher Spelling List (Term 3, Week 5)

Student View:      Chinese Kingdom Forest Stage 7
Maps to:           MOE P4 Chinese Spelling Lesson 7

Student View:      Boss 1 (20 words)
Maps to:           Cumulative assessment of Stage 1-5

This mapping is INVISIBLE to students but visible to:
- Parents (via Parent Mode)
- Teachers (via analytics dashboard)
- System (for adaptive difficulty)
```

---

## 🏠 Screen 1: Home Page

### Layout (No Scroll Required)

```
┌──────────────────────────────────────────┐
│ HEADER (No Scroll)                       │
├──────────────────────────────────────────┤
│                                          │
│  Good Evening, Alex! 👋  🔥 8 Streak    │
│                                          │
│            [Animated Mascot]             │
│        (Panda with expression)           │
│                                          │
│  "Your English test is in 3 days!"       │
│                                          │
│    [ ▶ Continue Adventure ]              │
│                                          │
├──────────────────────────────────────────┤
│ QUICK STATS (Horizontal Scroll or Grid) │
├──────────────────────────────────────────┤
│                                          │
│  ⭐ 250 XP    🪙 85 Coins   💎 12 Gems  │
│                                          │
├──────────────────────────────────────────┤
│ ACTIVE QUESTS (Scrollable)               │
├──────────────────────────────────────────┤
│                                          │
│  🏰 English Kingdom                      │
│  Stage 5 · ████████░░ 8/10              │
│  [Continue ▶]                           │
│                                          │
│  ─────────────────────────────────────  │
│                                          │
│  🐉 Chinese Kingdom                      │
│  Forest Stage 7 · ███████░░░ 7/10       │
│  [Continue ▶]                           │
│                                          │
├──────────────────────────────────────────┤
│ TODAY'S OPPORTUNITIES (Scrollable)       │
├──────────────────────────────────────────┤
│                                          │
│  🎯 Daily Quest                          │
│  • Practice 10 words                     │
│  • Review 3 weak words                   │
│  Reward: 50 XP + 20 Coins                │
│  [Start ▶]                               │
│                                          │
│  ─────────────────────────────────────  │
│                                          │
│  🎁 Daily Treasure Chest                 │
│  Open to claim random reward             │
│  [Open ▶]                                │
│                                          │
│  ─────────────────────────────────────  │
│                                          │
│  ⚔️ Boss Battle (If Available)           │
│  Defeat 3 weak words boss                │
│  Reward: 100 XP + Rare Item              │
│  [Fight ▶]                               │
│                                          │
└──────────────────────────────────────────┘
🏠 Home | 🗺 World Map | 🎒 Backpack | 🏆 Progress | 👤 Profile
```

### Components

**1. Header Section**
- Greeting (page title): "Good [Time], [Name]! 👋"
- Streak counter: 🔥 X Streak (orange badge)
- Animated mascot (50x50px): Centered, bounces on load
- Contextual message: Dynamic based on progress
- Primary CTA: "Continue Adventure" (green #58CC02, 48px button, scale animation)

**2. Quick Stats Row**
- XP counter (star icon + number)
- Coins counter (coin icon + number)
- Gems counter (gem icon + number)
- Each animates when value updates

**3. Active Journeys (2 scrollable cards)**
- **JourneyCard component**
  - Background: Kingdom-specific gradient
  - Icon: 🏰 (English), 🐉 (Chinese)
  - Content: Kingdom name, current stage, progress bar (green #58CC02), star rating
  - Button: Green "Continue ▶"
  - Touch target: 56x48px minimum
  - Hover effect: Lift -4px, shadow increase

**4. Daily Opportunities (3 scrollable cards)**
- **DailyQuestCard**
  - Background: Blue gradient #E6F5FF → #CCE6FF
  - Icon: 🎯
  - Content: 2-3 objectives (bullet list), reward display (XP + coins)
  - Button: Green "Start ▶" or gray "Completed ✓"
  - Updates daily at midnight local time

- **TreasureChestCard**
  - Background: Gold gradient #FFFDE6 → #FFFFE0
  - Icon: 🎁
  - Content: "Open to claim random reward" + last opened time
  - Button: Green "Open ▶" or gray "Available Tomorrow"
  - Animated chest icon when available
  - Rarity indicator: Bronze/Silver/Gold chest type

- **BossBattleCard** (conditional, only if weak words exist)
  - Background: Red gradient #FFE6E6 → #FFCCCC
  - Icon: ⚠️
  - Content: "Defeat X words boss" + weak word preview
  - Button: Red "Fight ▶"
  - Pulses/shakes to draw attention

### Visual Feedback

| Action | Animation | Duration |
|--------|-----------|----------|
| Page load | Mascot bounce (scale 1 → 1.1) | 1s elasticInOut |
| Streak return | Streak counter pulse + glow | 2s (loop until dismissed) |
| CTA tap | Button scale 1.0 → 1.05 | 200ms |
| Quest complete | Cards slide out + celebration | 1.5s |
| Stats update | Number increment animation | 500ms |
| Chest open | Chest rotates + sparkles | 1.5s + Lottie animation |

---

## 🗺️ Screen 2: World Map

### Layout

```
┌──────────────────────────────────────────┐
│ WORLD MAP (Scrollable/Pannable)         │
├──────────────────────────────────────────┤
│                                          │
│           ┌─── 🏰 English Castle       │
│          /                              │
│    🏘️ VILLAGE                           │
│          \                              │
│           └─── 🐉 Chinese Forest        │
│                                          │
│  (Below, unlocked after progress)       │
│           ┌─── 🔍 Review Cave          │
│          /                              │
│    [locked]                             │
│          \                              │
│           └─── 🏝️ Treasure Island       │
│                                          │
│  (Bottom right)                          │
│           ⚔️ Boss Arena                  │
│                                          │
└──────────────────────────────────────────┘
🏠 Home | 🗺 World Map | 🎒 Backpack | 🏆 Progress | 👤 Profile
```

### Components

**World Nodes (5 Locations)**

1. **Village (Always Available)**
   - Icon: 🏘️ (large, 40x40px)
   - Label: "Village"
   - Tap: Opens location details or returns to home

2. **English Castle**
   - Icon: 🏰 (animated, slight rotation)
   - Label: "English Kingdom"
   - Status: Stage number (e.g., "Stage 5") + star rating
   - Tap: Shows stage list (Week 1, Week 2... Week 15+)
   - Color: Blue-tinted #E6F5FF

3. **Chinese Forest**
   - Icon: 🐉 (breathing animation)
   - Label: "Chinese Kingdom"
   - Status: Section + stage (e.g., "Forest Stage 7") + star rating
   - Tap: Shows section map (Forest → River → Mountain)
   - Color: Warm orange-tinted #FFE6CC

4. **Review Cave** (Unlocked after Stage 3)
   - Icon: 🔍 (magnifying glass, glowing)
   - Label: "Review Cave"
   - Contains: Weak words dojo, speed challenges, perfect score trials
   - Tap: Opens review mode selection
   - Color: Purple-tinted #F0E6FF

5. **Treasure Island** (Unlocked after first boss win)
   - Icon: 🏝️ (palm tree + treasure)
   - Label: "Treasure Island"
   - Contains: Cosmetics showcase, achievement gallery, collection
   - Tap: Opens backpack-like view
   - Color: Gold-tinted #FFFDE6

6. **Boss Arena** (Unlocks progressively)
   - Icon: ⚔️ (sword clash animation)
   - Label: "Boss Arena"
   - Shows: Available bosses (e.g., "Boss 1, 2, 3")
   - Tap: Opens boss selection
   - Color: Red-tinted #FFE6E6

### Visual Feedback

| Element | Animation | Effect |
|---------|-----------|--------|
| Node entry | Scale in from 0 → 1 | Bounce easing, 500ms |
| Active node | Pulse glow | Opacity 0.7 → 1 (2s loop) |
| Locked node | Faded + lock icon | 50% opacity, "🔒 Unlock after X" |
| Tap node | Scale 1 → 1.08 | Haptic feedback (mobile) |
| Transition out | Fade to white | 300ms, then navigate |

---

## ⚔️ Screen 3: Practice/Study Screen

### Layout (During a Stage/Lesson)

```
┌──────────────────────────────────────────┐
│ HEADER (Sticky)                          │
├──────────────────────────────────────────┤
│ < Back | Stage 5: Vowels | X/10 Words   │
│ Progress: ████████░░ (8/10 correct)     │
│                                          │
├──────────────────────────────────────────┤
│ MASCOT REACTION (Top Center)             │
├──────────────────────────────────────────┤
│                                          │
│       [Mascot Animation/Expression]      │
│                                          │
├──────────────────────────────────────────┤
│ WORD DISPLAY (Large, Centered)           │
├──────────────────────────────────────────┤
│                                          │
│              BEAUTIFUL                   │
│        (Large, 28px bold)                │
│                                          │
│     How do you spell this word?          │
│                                          │
├──────────────────────────────────────────┤
│ CHALLENGE TYPE (Multiple Choice Example)│
├──────────────────────────────────────────┤
│                                          │
│  [ BEAUTIFUL ] [ BEATIFUL ]             │
│  [ BEAUTIFULL ] [ BEATIIFUL ]           │
│                                          │
├──────────────────────────────────────────┤
│ FEEDBACK (Appears after tap)             │
├──────────────────────────────────────────┤
│                                          │
│  ✓ Correct!  (+10 XP)                   │
│  [XP popup floats up]                    │
│                                          │
│  [Next Word ▶]                           │
│                                          │
└──────────────────────────────────────────┘
```

### Challenge Types

1. **Multiple Choice** (4 options)
   - Visual: 4 buttons with words
   - Animation: Scale 1.0 → 1.05 on tap
   - Feedback: Green flash on correct, red shake on wrong

2. **Spelling Input** (Type the word)
   - Visual: Large text input field
   - Animation: Keyboard slides up
   - Feedback: Character-by-character highlight, autocorrect hints

3. **Listening** (Hear & spell)
   - Visual: Speaker icon with play button
   - Animation: Waveform animation during playback
   - Feedback: Transcription appears, verify correct spelling

4. **Sentence** (Use word in context)
   - Visual: Sentence with blank, 3-4 word options
   - Animation: Word options slide in
   - Feedback: Sentence highlights on correct

### Mascot Reactions

| Reaction | Trigger | Animation | Expression |
|----------|---------|-----------|-----------|
| Happy | Correct answer | Jump bounce + sparkles | 😊 or 🐼😄 |
| Encouraging | Wrong answer | Gentle nod + thumbs up | 😌 or 🐼🤔 |
| Excited | Perfect streak (3+ correct) | Spinning jump | 🤩 or 🐼🎉 |
| Tired | Too many wrong answers | Sad slouch | 😓 or 🐼😴 |
| Victory | Stage complete | Full celebration (confetti + stars) | 🏆 or 🐼👑 |

### Visual Feedback

| Event | Animation | Duration |
|-------|-----------|----------|
| Word reveals | Fade in + scale 0.9 → 1.0 | 300ms |
| Correct answer | Green background flash + confetti | 500ms + 2s |
| Wrong answer | Red shake on input (20px left-right × 3) | 400ms |
| XP popup | Float up + fade out (yellow text) | 1000ms |
| Mascot reaction | Expression change + gesture animation | 600ms |
| Stage progress | Progress bar animates | 300ms |

---

## 🏆 Screen 4: Boss Battle

### Layout (Multi-Round)

```
┌──────────────────────────────────────────┐
│ BOSS BATTLE: "Spelling Dragon" 🐉       │
│ HP: ████████░░ 3/4                      │
├──────────────────────────────────────────┤
│                                          │
│      [Large Boss Character/Animation]    │
│                                          │
│         🐉 Spelling Dragon              │
│      "Defeat me to progress!"            │
│                                          │
├──────────────────────────────────────────┤
│ ROUND 1/4: LISTEN                       │
├──────────────────────────────────────────┤
│                                          │
│  Hear the word, identify it              │
│                                          │
│  [ 🔊 Listen ]                           │
│                                          │
│  (Word plays, student hears it)          │
│                                          │
│  Multiple choice: 4 options              │
│                                          │
├──────────────────────────────────────────┤
│ FEEDBACK & XP REWARD                     │
├──────────────────────────────────────────┤
│                                          │
│  ✓ Correct! (+25 XP)                    │
│                                          │
│  [Boss HP decreases animation]           │
│  [Next Round ▶]                          │
│                                          │
└──────────────────────────────────────────┘
```

### Boss Progression (4 Rounds)

1. **Round 1: Listen** (Auditory)
   - Hear word → identify from 4 options
   - Reward: +25 XP, -1 boss HP
   - Feedback: Boss flinches on correct

2. **Round 2: Spell** (Production)
   - Type the word correctly
   - Reward: +25 XP, -1 boss HP
   - Feedback: Boss stumbles on correct

3. **Round 3: Sentence** (Context)
   - Complete sentence with word
   - Reward: +25 XP, -1 boss HP
   - Feedback: Boss weakens on correct

4. **Round 4: Speed Challenge** (Rapid)
   - 3 words in 60 seconds (timer visible)
   - Reward: +50 XP (bonus for speed), Boss defeated!
   - Feedback: Celebration animation + treasure chest unlock

### Boss Defeat

```
╔══════════════════════════════════════════╗
║     🎉 BOSS DEFEATED! 🎉               ║
║                                         ║
║     Victory Rewards:                    ║
║     ⭐ 100 XP Bonus                     ║
║     🪙 50 Coins                         ║
║     💎 5 Gems (Rare!)                   ║
║     🎖️ Badge Unlocked: "Boss Hunter"   ║
║                                         ║
║     🎁 Treasure Chest Appears!          ║
║                                         ║
║     [Continue to World Map]             ║
╚══════════════════════════════════════════╝
```

### Visual Feedback

| Event | Animation | Effect |
|-------|-----------|--------|
| Boss appears | Scale in from center | Bounce easing, 600ms |
| Boss flinch | Shake left-right + color flash | 300ms |
| HP decrease | Healthbar shrinks + particle effect | 400ms |
| Wrong answer | Boss attacks (visual effect) | 500ms, shake screen |
| Boss defeated | Confetti burst + explosion | 2s Lottie animation |
| Reward popup | Each reward item floats up | Sequential, 100ms apart |

---

## 🎒 Screen 5: Backpack (Collection/Cosmetics)

### Layout

```
┌──────────────────────────────────────────┐
│ BACKPACK                                 │
├──────────────────────────────────────────┤
│                                          │
│  Tabs: 🐾 Pets | 👕 Avatar | 🎖️ Badges │
│                                          │
├──────────────────────────────────────────┤
│ SELECTED TAB: PETS (Mascot Cosmetics)   │
├──────────────────────────────────────────┤
│                                          │
│  Currently Equipped: Panda (Normal)      │
│                                          │
│  [Panda Sprite Display - Large]          │
│                                          │
│  Available Outfits:                      │
│  ┌──────────┬──────────┬──────────┐     │
│  │ Panda    │ Pirate   │ Astronaut│    │
│  │ (Equip)  │ (Equip)  │ (Unlock │    │
│  │          │          │  50 Gems)│    │
│  └──────────┴──────────┴──────────┘     │
│                                          │
│  ┌──────────┬──────────┐                │
│  │ Detective│ Wizard   │                │
│  │ (Equip)  │ (Unlock  │                │
│  │          │  100 Gems)│               │
│  └──────────┴──────────┘                │
│                                          │
├──────────────────────────────────────────┤
│ BADGES TAB (Achievements)                │
├──────────────────────────────────────────┤
│                                          │
│  🎖️ Perfect Day (10/10 correct)  [✓]   │
│  🎖️ Streak Master (7 days)       [✓]   │
│  🎖️ Boss Slayer (5 bosses)       [ ]   │
│  🎖️ Gem Collector (100 gems)     [2/10]│
│                                          │
└──────────────────────────────────────────┘
🏠 Home | 🗺 World Map | 🎒 Backpack | 🏆 Progress | 👤 Profile
```

### Tabs

1. **Pets (Mascots & Cosmetics)**
   - Display: Currently equipped mascot (large sprite)
   - Grid: 3 columns of cosmetics
   - Each item shows:
     - Costume preview (small icon)
     - Name (label)
     - Status: "Equip" (owned), "Unlock X Gems" (locked)
   - Tap equipped: Shows mascot animations
   - Tap to equip: Confirmation + sprite updates

2. **Avatar Items** (Future expansion)
   - Frames, borders, backgrounds
   - Status: Locked by progress milestone

3. **Badges** (Achievements)
   - Grid: 2x3 layout
   - Each badge shows:
     - Icon (emoji or illustration)
     - Name
     - Progress bar (if incomplete, e.g., 2/10)
     - Completion status (checkmark if complete)

### Visual Feedback

| Action | Animation | Effect |
|--------|-----------|--------|
| Tab switch | Fade transition | 200ms |
| Equip item | Mascot spins + icon floats | 800ms + confetti (small) |
| Unlock item | Item glows + shroud lifts | 1.5s |
| Badge earn | Pop-in with sparkles | 1.5s Lottie animation |

---

## 🏅 Screen 6: Progress (Stats & Milestones)

### Layout

```
┌──────────────────────────────────────────┐
│ PROGRESS DASHBOARD                       │
├──────────────────────────────────────────┤
│                                          │
│ STATS GRID (2 columns):                  │
│                                          │
│  ┌────────────┬────────────┐            │
│  │ 250 XP     │ 8 Streak   │            │
│  │ Total      │ Days       │            │
│  └────────────┴────────────┘            │
│                                          │
│  ┌────────────┬────────────┐            │
│  │ 45 Coins   │ 12 Gems    │            │
│  │ Spent: 5   │ Spent: 2   │            │
│  └────────────┴────────────┘            │
│                                          │
│  ┌────────────┬────────────┐            │
│  │ 10 Levels  │ 5 Bosses   │            │
│  │ Completed  │ Defeated   │            │
│  └────────────┴────────────┘            │
│                                          │
├──────────────────────────────────────────┤
│ MILESTONES (Scrollable List)             │
├──────────────────────────────────────────┤
│                                          │
│  🏁 Stage 1 Complete (Vowels)     ✓     │
│     Unlocked: English Castle             │
│                                          │
│  🏁 Stage 5 Complete (Review)     ✓     │
│     Unlocked: Review Cave                │
│                                          │
│  🏁 Boss 1 Defeated                ✓     │
│     Unlocked: Treasure Island            │
│                                          │
│  🏁 7-Day Streak Achieved          ✓     │
│     Reward: 50 Bonus XP                  │
│                                          │
│  🏁 First Gem Earned              [ ]   │
│     Progress: 3/1 (Complete!)            │
│                                          │
│  🏁 100 XP Milestone              [ ]   │
│     Progress: 250/100 (Complete!)        │
│                                          │
└──────────────────────────────────────────┘
🏠 Home | 🗺 World Map | 🎒 Backpack | 🏆 Progress | 👤 Profile
```

### Components

**Stats Cards (6-grid)**
- Large, colorful backgrounds (gradient)
- Icon + number + label
- Animated value updates (increment animation)

**Milestone List**
- Completed milestones: Checkmark, light background
- In-progress: Progress bar (e.g., 3/5 gems)
- Upcoming: Grayed out with "Coming soon"
- Tap to see more details (e.g., "Reward: 50 XP")

---

## 👤 Screen 7: Profile

### Layout

```
┌──────────────────────────────────────────┐
│ PROFILE                                  │
├──────────────────────────────────────────┤
│                                          │
│  [Avatar Frame - Large Circle]           │
│  Alex Chen                               │
│  Level 5 • Primary 4                     │
│  Member since Jan 2026                   │
│                                          │
│  [ Edit Profile ] [Settings]             │
│                                          │
├──────────────────────────────────────────┤
│ QUICK STATS                              │
├──────────────────────────────────────────┤
│                                          │
│  Joined: 45 days ago                     │
│  Best Streak: 12 days                    │
│  Favorite Kingdom: English (72% progress)│
│  Weakest Area: Compound words            │
│                                          │
├──────────────────────────────────────────┤
│ SETTINGS & ACCOUNT                       │
├──────────────────────────────────────────┤
│                                          │
│  🔊 Sound Effects: ON                    │
│  📢 Notifications: ON                    │
│  🌙 Dark Mode: OFF                       │
│  👨‍👩‍👧 Parent Mode: Available (Login)      │
│                                          │
│  [Logout]                                │
│                                          │
└──────────────────────────────────────────┘
🏠 Home | 🗺 World Map | 🎒 Backpack | 🏆 Progress | 👤 Profile
```

---

## 💎 Economy System

### Currency Types

| Currency | Icon | Earn Method | Use Case | Cap |
|----------|------|-------------|----------|-----|
| **XP** | ⭐ | Lessons (+10), Bosses (+50-100), Quests (+50), Daily bonus (+20) | Progress, visible count | Unlimited |
| **Coins** | 🪙 | Lessons (+5), Bosses (+50), Quests (+20), Chests (random) | Cosmetics, boosts (future) | Soft cap 500 |
| **Gems** | 💎 | Boss wins (+5), Perfect rounds (+2), Weekly streaks (+10), Events | Premium cosmetics, rare items | Soft cap 100 |

### Earning Schedule

**Per Lesson/Stage:**
- Correct answer: +10 XP
- Complete stage (8/10+): +30 XP bonus + 20 coins
- Perfect stage (10/10): +50 XP bonus + 30 coins + 2 gems

**Per Boss Battle:**
- Boss defeated: +100 XP + 50 coins + 5 gems

**Daily Activities:**
- Daily quest complete: +50 XP + 20 coins
- Treasure chest open: Random (10-50 XP, 5-20 coins, 1-3 gems)
- Login streak milestone (every 7 days): +50 XP + 50 coins + 10 gems

**Weekly:**
- 7-day streak: +50 XP, +50 coins
- 5 bosses defeated in week: +100 XP, +30 gems

### No Pay-to-Win

- **No paid XP/coins** (can't buy progression currency)
- **Optional cosmetics** (cosmetics-only gems available for purchase)
- **All progression free** (every milestone accessible through gameplay)

---

## 🎬 Animation Specifications

### Entrance Animations

| Screen | Animation | Duration | Easing |
|--------|-----------|----------|--------|
| Home | Mascot bounce + cards fade in | 1s + 600ms | elasticInOut + easeOut |
| World Map | Nodes scale in from center | 500ms each | bounceOut |
| Boss Battle | Boss enters from top + HP bar fills | 1s + 500ms | easeOut + linear |
| Backpack | Tab content fades + mascot spins | 300ms + 600ms | easeInOut + easeInOut |

### Button Interactions

| Element | Tap State | Duration | Effect |
|---------|-----------|----------|--------|
| Primary CTA | Scale 1.0 → 1.05 | 200ms | Haptic + visual feedback |
| Secondary Button | Opacity 1.0 → 0.8 | 150ms | Light press effect |
| Card | Lift Y-4px + shadow increase | 200ms | Depth indication |

### Celebration Animations

| Event | Animation | Tool | Duration |
|-------|-----------|------|----------|
| Correct Answer | Confetti burst + stars | Lottie (pre-built) | 2s |
| Boss Defeated | Explosion + character victory pose | Rive (animated sprite) | 2.5s |
| Streak Milestone | Fireworks + badge pop-in | Lottie | 3s |
| Level Complete | Full-screen celebration | Lottie + Rive combined | 3s |
| Chest Open | Chest opens + items float out | Rive (interactive) | 2s |

### Transition Animations

| From → To | Animation | Duration |
|-----------|-----------|----------|
| Home → Practice | Slide up + fade | 300ms |
| Practice → Home | Slide down + fade | 300ms |
| Tab change | Fade crossfade | 200ms |
| World Map node → Detail | Scale in from node | 400ms |

### Mascot Animations

| Expression | Animation | Duration | Loop |
|------------|-----------|----------|------|
| Idle/Happy | Gentle bounce | 2s | ∞ |
| Encouraging | Nod gesture | 1s | Once |
| Excited | Jump + spin | 1.5s | Once |
| Victory | Full celebration dance | 2s | Once |
| Tired | Slouch + sigh | 1s | Once |

**Implementation:** Sprite sheet (static) + position/rotation animators (Flutter) OR Rive for interactive animations

---

## 🎮 Daily Gameplay Loop

```
1. Student opens app
   ↓ (Notification on badge if last visited >24h ago)
   
2. Home page loads
   ├─ Greeting updated to time-of-day
   ├─ Mascot bounces + shows expression
   ├─ Stats displayed (XP, coins, gems, streak)
   └─ "What adventure should I continue?" frame

3. Student chooses action (under 5 seconds)
   ├─ Continue English Kingdom (Stage 5) → Practice screen
   ├─ Continue Chinese Kingdom (Forest 7) → Practice screen
   ├─ Start Daily Quest → Practice focused on objectives
   ├─ Open Treasure Chest → Random reward animation
   └─ (Optionally) Fight Boss → Boss Battle screen

4. Student practices (15-30 min typical session)
   ├─ Per lesson: 10 words, variety of challenge types
   ├─ Feedback: Instant visual + audio + XP popups
   ├─ Mascot reacts to success/struggles
   └─ Progress bar updates after each word

5. Student completes session
   ├─ Stage completion: Animation + reward summary
   ├─ XP/coins/gems awarded
   ├─ Progress saved immediately
   └─ Return to home screen

6. Optional: Student fights boss
   ├─ 4-round battle (Listen → Spell → Sentence → Speed)
   ├─ Each round: +25-50 XP, -1 boss HP
   ├─ Boss defeat: +100 XP + 50 coins + 5 gems + rare item
   └─ Celebration + treasure chest unlock

7. Student logs off
   ├─ Session stats summarized
   ├─ Streak counter incremented (+1 day)
   ├─ Notifications scheduled for tomorrow
   └─ Data synced to backend

---

## 🧩 Component Library

### Core Components (Reuse from Phase 2)

| Component | File | Used On | Status |
|-----------|------|---------|--------|
| **PrimaryButton** | `lib/widgets/buttons/primary_button.dart` | All CTAs | ✅ Complete |
| **DuolingoColors** | `lib/design_system/colors.dart` | All screens | ✅ Complete (add new gradients) |
| **DuolingoTextStyles** | `lib/design_system/typography.dart` | All text | ✅ Complete |
| **DuolingoSpacing** | `lib/design_system/spacing.dart` | All layouts | ✅ Complete (add new constants) |
| **DuolingoShadows** | `lib/design_system/shadows.dart` | All cards | ✅ Complete |

### New Components (Phase 3/4)

| Component | Purpose | Status |
|-----------|---------|--------|
| **JourneyCard** | Kingdom progress display | New |
| **DailyQuestCard** | Daily objectives + rewards | New |
| **TreasureChestCard** | Daily reward opener | New |
| **BossBattleCard** | Boss challenge display | New |
| **WorldNode** | Map location (clickable) | New |
| **ChallengeView** | Word presentation (Listen/Spell/Sentence/Speed) | New |
| **BossCharacter** | Boss visual + HP bar | New (Rive animation) |
| **MascotSprite** | Animated companion | New (Rive animation + expressions) |
| **StatsCard** | XP/coins/gems display | Adapt from existing |
| **ProgressBar** | Horizontal progress indicator | Adapt from existing |
| **BadgeCard** | Achievement display | New |
| **MilestoneItem** | Timeline milestone | New |

---

## 🎯 Success Metrics

### User Engagement
- ✅ **5-second rule:** 80%+ students tap action within 5s of landing on home
- ✅ **Daily active:** 60%+ return next day (7-day retention)
- ✅ **Session length:** Average 20-30 min per session
- ✅ **Progression:** Complete 1+ stage per session

### Learning Outcomes
- ✅ **Accuracy:** 85%+ correct answers by Stage 5
- ✅ **Recall:** 90%+ retain previously learned words
- ✅ **Boss pass rate:** 70%+ pass bosses without retry
- ✅ **Weak word improvement:** 75% reduce errors on previously weak words

### Monetization (Optional)
- ✅ **Cosmetic appeal:** 20%+ purchase cosmetics within first month
- ✅ **Average revenue per user:** $1-2 per month (cosmetics-only)
- ✅ **No pay-to-win complaints:** 95%+ positive sentiment

---

## 📋 Implementation Phases

### Phase 3 (3-4 weeks): Core Adventure Experience
- [ ] World map structure + node navigation
- [ ] JourneyCard, DailyQuestCard, BossBattleCard components
- [ ] Practice screen redesign (challenge types)
- [ ] Boss battle system (4-round progression)
- [ ] Treasure chest system (daily rewards)
- [ ] Backpack (cosmetics + badges)
- [ ] Economy system (XP, coins, gems tracking)
- [ ] Progress dashboard

### Phase 4 (2-3 weeks): Polish & Animations
- [ ] Rive animations (mascot + boss characters)
- [ ] Lottie celebrations (confetti, fireworks, badge unlocks)
- [ ] Transition animations (screen → screen, tab → tab)
- [ ] Sound effects (correct/wrong, level up, boss defeat)
- [ ] Haptic feedback (mobile)
- [ ] Performance optimization

### Phase 5 (1 week): Parental Controls & Analytics
- [ ] Parent Mode login + dashboard
- [ ] Curriculum mapping visibility
- [ ] Practice history + weak word reports
- [ ] Analytics dashboard (teachers/admins)

### Phase 6 (Optional): Advanced Features
- [ ] Cosmetic store (cosmetics-only purchases)
- [ ] Multiplayer leaderboards
- [ ] Friend challenges
- [ ] Events & seasonal content
- [ ] Difficulty adaptation (AI)

---

## 🔐 Backend Integration

### New API Endpoints Needed

| Endpoint | Method | Purpose | Response |
|----------|--------|---------|----------|
| `/journeys` | GET | List all journeys | `[{id, name, icon, stages: [...]}]` |
| `/journeys/{id}/stages` | GET | Get stages in journey | `[{stageNum, week, stars, isLocked}]` |
| `/challenges/{id}` | GET | Get word list for challenge | `[{word, hints, audioUrl}]` |
| `/challenges/{id}/submit` | POST | Submit answer | `{correct, xp, coins, gems}` |
| `/boss/{id}` | GET | Get boss battle | `{name, icon, hp, rounds: [...]}` |
| `/boss/{id}/submit` | POST | Submit round answer | `{correct, hp, reward}` |
| `/treasure-chest` | GET | Get daily chest | `{type, reward}` |
| `/treasure-chest/open` | POST | Open chest | `{xp, coins, gems, item}` |
| `/user/economy` | GET | Get XP/coins/gems | `{xp, coins, gems}` |
| `/user/cosmetics` | GET | Get owned cosmetics | `[{id, type, name}]` |
| `/user/cosmetics/{id}/equip` | POST | Equip cosmetic | `{success, newSprite}` |
| `/user/badges` | GET | Get badge progress | `[{id, progress, unlocked}]` |

---

## 📱 Responsive Design

**Primary Target:** Mobile (375px width)  
**Secondary:** Tablet (600px+)  
**Tertiary:** Desktop (1024px+)

- Bottom navigation persists on mobile
- Navigation drawer on tablet/desktop (side panel)
- Cards scale with available width
- Touch targets maintain 48px minimum across all sizes

---

## ✨ Key Differentiators from Competitors

1. **Immersive world** (not list-based)
2. **Companion growth** (mascot levels up with player)
3. **Sophisticated economy** (3 currencies, real progression)
4. **Hidden curriculum** (students explore, learning happens naturally)
5. **No pay-to-win** (all progression free, cosmetics-only monetization)
6. **Parental transparency** (parents see curriculum + progress)
7. **Local relevance** (Singapore MOE curriculum + Teacher spelling lists)

---

## 🎨 Visual Reference (Screenshots)

*(To be created in Figma/mockup tool during Phase 3)*

- Home page mockup
- World map mockup
- Practice screen mockup (each challenge type)
- Boss battle mockup (4 rounds)
- Backpack mockup
- Celebration animations (before/after)

---

## 📝 Notes for Stakeholders

### For Teachers/Parents
- Adventure mode keeps students engaged without exposing curriculum complexity
- Parent mode provides full curriculum transparency + progress tracking
- Weak word detection automatic—no manual grading needed
- Boss battles = summative assessments (cumulative review)

### For Developers
- Use Rive for complex animations (mascot, boss, celebrations)
- Use Lottie for celebration effects (pre-built animations)
- Keep component library reusable (same button/card styles across all screens)
- Prefetch audio files for TTS to reduce latency
- Cache completed stages locally (works offline)

### For Product/UX
- A/B test treasure chest rarity distribution (should feel rewarding, not grindy)
- Monitor daily quest completion rate (should be 60%+)
- Track boss pass rate (should be 70%+)
- Survey students on which kingdom they prefer (English vs Chinese)

---

## ✅ Final Checklist Before Implementation

- [ ] Color palette approved by stakeholders
- [ ] World structure finalized (5 kingdoms confirmed)
- [ ] Mascot character selected (Panda, Fox, Penguin, Monkey?)
- [ ] Cosmetic ideas brainstormed (Pirate, Astronaut, Detective, Wizard, etc.)
- [ ] Economy values tested with game balance (XP/coin earn rates)
- [ ] Backend database schema reviewed (journeys, stages, economy tables)
- [ ] Animation tool chosen (Rive vs Lottie vs Flutter built-in)
- [ ] Responsive breakpoints defined (mobile/tablet/desktop)
- [ ] Parent mode permissions configured
- [ ] Analytics tracking plan finalized

---

## 🚀 Ready for Phase 3 Implementation

This spec is comprehensive and actionable. Phase 3 can begin immediately with:
1. Design system updates (add new colors/gradients/constants)
2. API endpoint implementation (backend)
3. Component development (JourneyCard, DailyQuestCard, etc.)
4. Screen wireframes in Flutter
5. Animation specs in Rive/Lottie

**Estimated Timeline:** 6-8 weeks (Phases 3-4) to full launch-ready build.

---

**Document Version:** 3.0  
**Last Updated:** 2026-07-12  
**Status:** Ready for Stakeholder Review & Approval

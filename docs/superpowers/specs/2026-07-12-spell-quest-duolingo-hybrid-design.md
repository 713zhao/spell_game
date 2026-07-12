# SpellQuest with Duolingo Design System — Hybrid Design Spec

**Status:** Proposed for Review  
**Target:** Flutter Web (localhost:8000 backend)  
**Audience:** Primary and secondary children 
**Vision:** Adventure-game progression (journeys/weeks) with Duolingo's colorful, rewarding visual language

---

## 🎯 Core Principle

**Students should tap "Start Adventure" within 5 seconds.**

Home page is a **launch pad** showing:
- Current progress (streak, XP)
- Next immediate action (Continue Teacher Journey OR MOE Journey)
- Daily motivational quest
- Quick portals to other worlds

No overwhelming content. No scrolling beyond fold. **Game-first, not homework.**

---

## 🎨 Design System (Duolingo Foundation)

### Color Palette
| Color | Hex | Usage |
|-------|-----|-------|
| Primary Green | #58CC02 | Action buttons, progress bars, CTAs |
| Streak Orange | #FFA500 | Streak counter, milestones |
| Reward Yellow | #FFD700 | XP earned, celebrations, badges |
| Information Blue | #1F9DFF | Journey info cards, daily quests |
| Mistake Red | #FF4D4D | Weak words, boss battle |
| Secondary Purple | #A366FF | Special achievements, rare items |
| Background White | #FFFFFF | Main background |
| Neutral Gray | #F5F5F5 | Disabled states, secondary content |

### Gradients
- **Streak Gradient:** #FFF5E6 → #FFE6CC (orange card backgrounds)
- **Reward Gradient:** #FFFDE6 → #FFFFCC (yellow/gold backgrounds)
- **Info Gradient:** #E6F5FF → #CCE6FF (blue card backgrounds)
- **Journey Gradient (NEW):** #F0E6FF → #E6D9FF (purple for journeys)

### Typography
- **Page Title:** 24px bold (greeting)
- **Section Title:** 16px bold (uppercase, letter-spacing 0.5px)
- **Card Title:** 14px bold (journey/quest names)
- **Body:** 12px regular (descriptions, stats)
- **Label:** 11px semi-bold (stat labels)
- **Large Value:** 24px bold (streak count, week number)

### Spacing & Sizing
- **Grid:** 4px increments (xs:4, sm:8, md:12, lg:16, xl:20, xxl:24)
- **Border Radius:** Cards 20px, Buttons 16px, Avatars 30px
- **Touch Target:** 48x48px minimum
- **Shadow:** Card shadow 10% black, Hover shadow 15% black

### Animations
- **Button Tap:** Scale 1.0 → 1.05 (200ms)
- **Card Hover:** Lift Y-4px, shadow increase (200ms)
- **Progress Bar Fill:** Smooth width animation (300ms)
- **Mascot Bounce:** Celebratory animation on load (elasticInOut)
- **XP Popup:** Float up + fade (1s total)

---

## 📱 Home Page Layout (Duolingo Visual + Journey Structure)

### 1. Header Section (No Scroll)
```
┌─────────────────────────────────────────┐
│ Good Evening, Alex! 👋   🔥 8 Day Streak│
│                                         │
│              🦉 Mascot                  │
│  "Your English test is in 3 days!"      │
│                                         │
│      [▶ Continue Adventure]              │
└─────────────────────────────────────────┘
```

**Elements:**
- Greeting text (page title style): "Good [Time], [Name]! 👋"
- Streak counter (orange badge with icon): 🔥 X Day Streak
- Animated mascot emoji (dog)
- Contextual message: Dynamic text based on next milestone
- Primary CTA button: "Continue Adventure" (green #58CC02, gradient)

**Visual Feedback:**
- Mascot bounces on load (ScaleTransition + elasticInOut curve)
- Streak counter pulses when user returns after missing a day
- CTA button has scale animation on tap

---

### 2. Active Journey Card (Full Width)

**Teacher Journey:**
```
┌──────────────────────────────────┐
│ 🏰 Teacher Journey               │
│ Week 5 (Current)                 │
│ ████████░░ 16/20                │
│ ⭐⭐⭐ Almost Ready              │
│                                  │
│        [Continue ▶]              │
└──────────────────────────────────┘
```

**MOE Journey (if unlocked):**
```
┌──────────────────────────────────┐
│ 🐉 MOE Chinese Journey          │
│ Forest - Lesson 7 (Current)      │
│ ███████░░░ 7/10                 │
│ ⭐⭐☆ In Progress                │
│                                  │
│        [Continue ▶]              │
└──────────────────────────────────┘
```

**Component: JourneyCard**
- Background: Gradient (purple #F0E6FF → #E6D9FF)
- Icon: Journey theme emoji (🏰 teacher, 🐉 MOE)
- Content: Journey name, current week/lesson, progress bar, star rating
- Progress bar: Green fill #58CC02, smooth animation
- Stars: Filled (gold #FFD700) or empty (gray)
- Button: Green "Continue" (primary action)
- Touch target: 48px+ minimum
- Hover effect: Lift -4px, shadow increase

**Visual Feedback:**
- Progress bar animates when data updates (300ms)
- Star rating transitions smoothly
- Button scale animation on tap (1.0 → 1.05)
- Celebration animation when week completed (confetti, star burst)

---

### 3. Daily Quest Card

```
┌──────────────────────────────────┐
│ 🎯 Daily Quest                   │
│ • Practice 10 words              │
│ • Review 3 difficult words       │
│ Reward: ⭐50 XP + 🪙20 Coins     │
│                                  │
│      [Start Quest ▶]             │
└──────────────────────────────────┘
```

**Component: DailyQuestCard**
- Background: Blue gradient (#E6F5FF → #CCE6FF)
- Icon: 🎯
- Content: Quest objectives (bullet list), reward summary
- Reward display: XP amount + Coin icon
- Button: Green "Start Quest" or gray "Completed ✓"
- Touch target: 48px+ minimum
- State: Active (green CTA), Completed (gray, checkmark)

**Visual Feedback:**
- Quest updates daily (at midnight local time)
- Completed quest shows celebration animation
- XP amount highlights in yellow when completed
- Coin counter increments with sound effect

---

### 4. Boss Battle Card (Conditional)

*Only appears when weak words exist (>3 errors)*

```
┌──────────────────────────────────┐
│ ⚠️ Boss Battle                    │
│ 4 difficult words remain!         │
│ because • beautiful •             │
│ responsible • environment          │
│                                  │
│      [Fight Boss ▶]              │
└──────────────────────────────────┘
```

**Component: BossBattleCard**
- Background: Red gradient (light red #FFE6E6 → #FFCCCC)
- Icon: ⚠️ (warning/challenge)
- Content: Weak word list (sample words shown)
- Button: Red/Orange "Fight Boss" (danger/challenge color)
- Touch target: 48px+ minimum
- State: Active (red CTA), Hidden (not visible if no weak words)

**Visual Feedback:**
- Card pulses/blinks to draw attention
- Weak word list shows shaking animation
- Button has red shadow (#FF4D4D)
- Completion shows burst animation + XP popup

---

### 5. Explore More Section (Quick Portals)

```
═════════════════════════════════════
🚪 Explore More

📚 Teacher Worlds →
🎓 MOE Worlds →
🏆 Collection →
═════════════════════════════════════
```

**Component: PortalRow**
- Background: Subtle separator (light gray #F5F5F5)
- Content: 3 tap-able portal items
- Items: Icon + Label + Chevron (→)
- Navigation: Each opens corresponding screen

**Visual Feedback:**
- Each portal has hover lift effect
- Icon enlarges on tap (scale animation)
- Chevron animates (slide right) on tap

---

### 6. Bottom Navigation (5 Tabs)

```
🏠 Home (Active - Green #58CC02)
🗺️ Journey (Inactive - Gray #999)
🎒 Collection (Inactive - Gray #999)
🏆 Progress (Inactive - Gray #999)
👤 Profile (Inactive - Gray #999)
```

**Features:**
- Home tab always shows active green (#58CC02)
- Icons large and clear for child accessibility
- Label text 11px, semi-bold
- No scrolling in bottom nav
- Smooth transition between screens

---

## 🗺️ Journey Structure (Content Organization)

### Teacher World (Spell Content)

**Hierarchy:**
```
Term 1
  ├─ Week 1 ✓
  ├─ Week 2 ✓
  ├─ Week 3 ✓
  ├─ Week 4 ✓
  └─ Week 5 🔥 (Current)
      ├─ Lesson 1 (Vowels)
      ├─ Lesson 2 (Consonants)
      └─ Lesson 3 (Blends)

Term 2
  ├─ Week 6 🔒 (Locked until Week 5 complete)
  ├─ Week 7
  └─ Week 8

Term 3
  ├─ Week 9
  ├─ Week 10
  └─ Week 11
```

**Home Page Shows:** Only current week (Week 5) progress in JourneyCard
**Journey Page Shows:** Full term/week/lesson hierarchy

### MOE World (Chinese Content)

**Hierarchy:**
```
Forest
  ○─○─○─●─○─○─○─○  (●= current node, ○= available/locked)

River
  ○─○─○─○─○─○─○─○  (Unlocked after Forest)

Mountain
  ○─○─○─○─○─○─○─○  (Locked)
```

**Home Page Shows:** Current forest/lesson progress in JourneyCard
**Journey Page Shows:** Full node map with progression

---

## 🎮 Reward Loop Integration

### Progression Rewards
- **Complete Lesson:** +50 XP, +10 Coins, star earned
- **Complete Week:** +200 XP, +50 Coins, badge unlocked, mascot animation
- **Complete Boss Battle:** All weak words cleared, +100 XP bonus
- **Daily Quest:** +50 XP, +20 Coins (varies by quest type)
- **7-Day Streak:** Milestone celebration, special badge

### Visual Feedback
- **XP Earned:** Float-up animation (yellow text, fade out)
- **Coins Earned:** Coin icon with counter animation
- **Badge Unlock:** Full-screen celebration, confetti burst
- **Streak Milestone:** Streak counter glows/pulses orange
- **Mascot Reaction:** Happy emoji on completion, encouraging emoji on struggle

---

## 🔄 User Flows

### Start of Session
1. User opens app → Home page loads
2. Mascot bounces (celebrate return)
3. Greeting updated to time-of-day
4. Streak displays (with pulsing animation if user returned after gap)
5. Current journey card shows progress
6. Daily quest refreshed (if new day)
7. User taps "Continue Adventure" → Study screen loads

### Returning User (Next Day)
1. Home shows updated stats
2. Streak counter increments (+1 day)
3. Daily quest resets (new randomized quest)
4. Mascot shows encouraging message
5. All progress preserved from previous days

### Week Completion
1. User completes final lesson of week
2. Full-screen celebration: confetti, stars, badge unlock
3. Next week unlocked (if hierarchically next)
4. Journey card updates to show new week
5. XP/Coins tallied with animation
6. Return to home, ready for next week

---

## 📊 States & Edge Cases

### Loading State
- Skeleton loaders for journey cards
- Pulse animation on stats
- "Loading..." message with spinner

### Empty State
- First-time user: Shortened greeting, tutorial journey card
- No boss battles: Section simply hidden
- Locked journeys: Grayed out cards with lock icon

### Error State
- API failure: Offline mode with cached data
- Retry button with error message
- Stats remain visible (last known state)

### Celebration States
- Lesson complete: Green flash + confetti
- Week complete: Full-screen animation + badge
- Boss battle win: Red-to-green transition + XP shower
- Daily quest: Coin counter animation + success sound

---

## 🎬 Micro-Interactions

| Interaction | Animation | Duration |
|-------------|-----------|----------|
| Tap button | Scale 1.0 → 1.05 | 200ms |
| Card hover | Lift Y-4px, shadow | 200ms |
| Progress update | Width animation | 300ms |
| XP popup | Float up + fade | 1000ms |
| Streak pulse | Opacity + scale | 1500ms (loop) |
| Completion burst | Confetti + sparkle | 2000ms |
| Mascot bounce | Scale elasticInOut | 1500ms (loop) |

---

## 🛠️ Technical Implementation

### New Components Needed
- **JourneyCard:** Shows teacher/MOE journey progress (reusable for both)
- **DailyQuestCard:** Shows randomized daily quest objectives
- **BossBattleCard:** Shows weak words + boss battle challenge
- **PortalRow:** Quick navigation to other screens

### Existing Components Reused (From Phase 2)
- **PrimaryButton:** "Continue Adventure", "Continue", "Fight Boss", "Start Quest"
- **StatCard:** Streak + XP display (top of home page)
- **DailyGoalCard:** Could adapt for daily quest (or create new)
- **Design System:** Colors, typography, spacing, shadows, animations

### State Management (GameProvider)
- `currentTeacherWeek` / `currentMOENode`
- `completedLessons` / `completedWeeks`
- `streakCount` / `dailyGoalProgress`
- `weakWords` / `bossActive`
- `dailyQuestType` / `questProgress`
- `totalXP` / `totalCoins`

### API Endpoints Needed
- `GET /journeys/{journeyId}` — Get journey structure
- `GET /weeks/{weekId}` — Get week lessons
- `POST /lessons/{lessonId}/start` — Begin lesson
- `GET /user/stats` — Streak, XP, coins (existing)
- `GET /user/weak-words` — Words for boss battle
- `GET /daily-quest` — Today's randomized quest
- `POST /daily-quest/complete` — Claim quest reward

---

## ✅ Success Criteria

### Visual Design
- ✓ All Duolingo colors used consistently
- ✓ Rounded corners on all cards (20px)
- ✓ Green CTAs on all primary actions
- ✓ Smooth animations (no jank)
- ✓ No overwhelming text (max 2 lines per section)

### User Experience
- ✓ "Start Adventure" button visible within fold
- ✓ Current journey prominently displayed
- ✓ Daily quest motivates daily return
- ✓ Boss battle appears only when needed
- ✓ Rewards celebrated with visual + audio feedback
- ✓ Streak counter visible at all times

### Game Feel
- ✓ Journey progression feels like adventure
- ✓ Rewards accumulate visibly (XP + Coins)
- ✓ Mascot reacts to user actions
- ✓ No pay-to-win mechanics
- ✓ Children ages 6-12 find it engaging

### Performance
- ✓ Home loads in <2 seconds
- ✓ Animations run at 60 FPS
- ✓ No lag on button taps
- ✓ Transitions between screens smooth

---

## 📋 Deployment Notes

**Phase 1 (Completed):** Design System (colors, typography, spacing, shadows)

**Phase 2 (Completed):** Duolingo UI Components (buttons, cards, home screen)

**Phase 3 (Recommended):** Journey System
- Add JourneyCard, DailyQuestCard, BossBattleCard components
- Redesign HomeScreen to show journeys + rewards
- Add Journey/Collection/Progress screens
- Backend: Add journey data endpoints
- Testing: Verify journey progression logic

**Phase 4 (Optional):** Animations & Polish
- Add confetti on completions
- Add mascot expressions (happy, encouraging, proud)
- Add sound effects for rewards
- Add haptic feedback for button taps (mobile)

---

## 🎨 Reference Designs

**Inspiration:** Duolingo (visual language) + SpellQuest (journey progression)

**Color Palette:** Duolingo official colors (bright, encouraging, child-friendly)

**Typography:** Segoe UI (accessible, clean)

**Components:** Flutter Material Design 3 (rounded corners, elevation shadows)

---

## 📝 Next Steps for Review

1. **Visual Approval:** Does home page layout feel right? Is "Continue Adventure" prominent enough?
2. **Journey Structure:** Are weeks/lessons organized logically for spelling curriculum?
3. **Reward Balance:** Do XP/coin amounts feel motivating without pay-to-win?
4. **Content Questions:** 
   - How many weeks per term?
   - How many lessons per week?
   - What are MOE Chinese spelling levels?
5. **Implementation Questions:**
   - Should weak words be tracked automatically or require manual marking?
   - How often should daily quest reset (midnight local or UTC)?
   - Should boss battles scale in difficulty?

Please review and provide feedback. Once approved, implementation plan can be created for Phase 3.

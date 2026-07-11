# Game-Based Spelling App UI Design
**Date:** 2026-07-11  
**Status:** Design Phase  
**Target Users:** P1-P4 children (ages 6-10, Singapore curriculum)  
**Platforms:** Flutter (iOS/Android) primary, web fallback  

---

## 1. Vision & Principles

This design replaces the basic quiz-style frontend with a **game-based adventure** modeled on Duolingo's reward loop mechanics. Rather than copying Duolingo visually, we adopt its core principle: **continuous reward feedback + habit formation** keeps users engaged.

**Core Principles:**
- **Immediate feedback:** Every correct answer celebrated (animation + sound)
- **Clear progression:** Levels lock/unlock based on prior mastery
- **Daily habit:** Streak counter incentivizes daily login
- **Social proof:** Leaderboard + friend challenges
- **Variety:** Mixed study modes (multiple choice, typing, speech) prevent monotony
- **Safe for kids:** No ads, no expensive cosmetics, parental transparency

---

## 2. Architecture

### 2.1 High-Level Stack

| Component | Technology | Role |
|-----------|-----------|------|
| Frontend (Mobile) | Flutter | iOS/Android app (primary) |
| Frontend (Web) | Flutter Web or React | Browser fallback, teacher dashboard |
| Backend | FastAPI (extended) | Game logic, validation, progression |
| Database | SQLite | Levels, progress, unlockables, challenges |
| AI (Future) | Google Cloud (TTS, speech recognition) | Speech challenges, word pronunciation |

### 2.2 Backend Strategy: Hybrid Approach

**Reuse existing tables:**
- `User` (name, age, school, grade, total_points)
- `SpellingWord` (text, language, created_by)
- `Tag` (tag system for word filtering)
- `RewardHistory` (all point earn/redeem events)

**Add new game tables:**
- `Level` — level definitions (Animals, Colors, etc.)
- `LevelProgress` — per-user progress tracking
- `Unlockable` — cosmetic rewards (avatars, themes, effects)
- `UserUnlockable` — tracks owned cosmetics
- `Challenge` — friend challenges and daily challenges
- `LevelStatistics` — per-word performance within levels

**Rationale:**
- Keeps proven reward system intact
- Separates learning (words) from game mechanics (levels, progression)
- Server validates all game logic (cheat prevention)
- Scales for web + mobile + future API
- Ready for AI features (OCR, speech verification)

---

## 3. Data Model

### 3.1 Level Table

```sql
CREATE TABLE level (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,           -- "Animals", "Colors", etc.
  description TEXT,             -- "Learn common animals"
  difficulty INTEGER (1-5),     -- 1=P1 beginner, 5=P4 advanced
  unlock_requirement TEXT,      -- "complete_level_X" or "points_Y"
  created_at DATETIME,
  updated_at DATETIME
);

-- Junction table: link words to levels (many-to-many)
CREATE TABLE level_word (
  level_id INTEGER FK,
  word_id INTEGER FK,
  position INTEGER,            -- order in level
  PRIMARY KEY (level_id, word_id)
);
```

### 3.2 LevelProgress Table

```sql
CREATE TABLE level_progress (
  id INTEGER PRIMARY KEY,
  user_id INTEGER FK,
  level_id INTEGER FK,
  status TEXT,                 -- "locked", "in_progress", "completed"
  stars_earned INTEGER (0-3),  -- 0=incomplete, 1-3=mastery levels
  points_earned INTEGER,       -- bonus for completing level
  study_count INTEGER,         -- how many times practiced
  started_at DATETIME,
  completed_at DATETIME,
  UNIQUE (user_id, level_id)
);
```

### 3.3 Unlockable Table

```sql
CREATE TABLE unlockable (
  id INTEGER PRIMARY KEY,
  type TEXT,                   -- "avatar_skin", "theme", "effect"
  name TEXT,                   -- "Blue Cat", "Rainbow Theme"
  description TEXT,
  points_cost INTEGER,         -- cost to redeem
  unlock_method TEXT,          -- "earn_level_X", "earn_streak_Y", "redeem_points"
  rarity TEXT,                 -- "common", "rare", "epic"
  created_at DATETIME
);

CREATE TABLE user_unlockable (
  user_id INTEGER FK,
  unlockable_id INTEGER FK,
  acquired_at DATETIME,
  is_equipped BOOLEAN,        -- for cosmetics (one per type)
  PRIMARY KEY (user_id, unlockable_id)
);
```

### 3.4 Challenge Table

```sql
CREATE TABLE challenge (
  id INTEGER PRIMARY KEY,
  challenger_id INTEGER FK,   -- user who initiated
  challengee_id INTEGER FK,   -- user being challenged
  level_id INTEGER FK,
  status TEXT,                -- "pending", "accepted", "completed"
  created_at DATETIME,
  completed_at DATETIME,
  winner_id INTEGER FK,       -- null until completed
  points_at_stake INTEGER
);
```

---

## 4. Reward Loop Design

### 4.1 Per-Question Rewards (Immediate Feedback)

**Correct answer:**
- +1 point (added to `RewardHistory` with reason="study")
- Pop animation (star burst, number +1)
- Chime sound (success SFX)
- Text: "Great job!" or "Perfect!"

**Incorrect answer:**
- No points lost
- Encouraging hint shown
- Text: "Try again!" or "Close!"
- Can retry without penalty

**Why this works for kids:**
- Constant positive reinforcement (every 5-10 seconds)
- Low stakes (no punishment for mistakes)
- Gamification of learning (points feel like currency)

### 4.2 Per-Level Rewards (Milestone Celebration)

**Level completion:**
- Chest animation opens (celebratory visual)
- Bonus +10 points (level completion bonus)
- Earn 1-3 stars (based on accuracy in that level)
  - 1 star: ≥60% correct first try
  - 2 stars: ≥80% correct first try
  - 3 stars: 100% correct first try
- Unlock cosmetic (progression-based or random)
  - Example: Level 1 → Blue Cat avatar
  - Example: Level 5 → Rainbow theme
  - Example: Level 10 → Special effect pack

**Why this works for kids:**
- Breaks up study into achievable milestones (5-10 min per level)
- Stars give visual sense of mastery (collect them all)
- Cosmetics are tangible rewards (use them in profile/app)

### 4.3 Streak System (Habit Formation)

**Daily streak tracking:**
- First login of the day increments streak counter
- Streak counter displayed prominently on home screen (large, with 🔥 icon)
- Visual progression: "3 days 🔥", "7 days 🔥", "30 days 🔥"

**Streak bonuses:**
- Day 5: 2x points multiplier for next study session
- Day 10: Unlock exclusive cosmetic + special animated effect
- Day 30: Unlock "Master Speller" badge

**Streak loss & revival:**
- Miss a day: streak resets to 0 (visible notification)
- Optional: Revive for 50 points (one-time per break)
- Shows countdown: "Return in 00:06:30 to keep your streak!"

**Why this works:**
- Fear of losing streak is powerful motivator
- Duolingo effect: kids check back daily to maintain 🔥
- Small multiplier boost (2x) keeps engagement high without breaking balance

### 4.4 Weekly Challenges (Social & Competitive)

**Challenge mechanics:**
- "Challenge Sarah to spell 20 words" → invite sent
- Challengee accepts → both race to complete level
- Winner = higher accuracy or faster completion
- Loser doesn't lose points, but winner gets +20 bonus points

**Why this works:**
- Taps into social motivation (friendly competition)
- Encourages daily login to maintain winning streak
- No punishment for losing (stays positive)

---

## 5. Frontend Screens & Flows

### 5.1 Home Screen

**Layout:**
```
┌─────────────────────────┐
│  Spell Adventure        │
├─────────────────────────┤
│  🔥 3 Days              │  ← Streak counter (prominent)
│  Tap to keep it going!  │
├─────────────────────────┤
│  Daily Goal: Complete 1 Level (50 pts)
│  [ ✓ Completed ]  or  [ In Progress ]
├─────────────────────────┤
│  LEVELS                 │
│  [⭐⭐⭐] Level 1       │  ← Can replay for bonus
│  [⭐⭐  ] Level 2       │
│  [  ⭐  ] Level 3       │
│  [Locked] Level 4       │  ← Shows unlock requirement
├─────────────────────────┤
│  Quick Links:           │
│  [Leaderboard] [Shop] [Profile]
└─────────────────────────┘
```

**Interactions:**
- Tap level → Study screen
- Tap streak → shows history of daily logins
- Tap "Daily Goal" → claim bonus
- Bottom nav: Home | Levels | Leaderboard | Rewards | Profile

### 5.2 Level Select Screen

**Layout:**
```
┌─────────────────────────┐
│  LEVELS                 │
├─────────────────────────┤
│  Level 1: Animals       │
│  ⭐⭐⭐ 45/50 words    │  ← Progress bar
│  [Play]                 │
├─────────────────────────┤
│  Level 2: Colors        │
│  ⭐ 12/50 words         │
│  [Play]                 │
├─────────────────────────┤
│  Level 3: Numbers       │
│  [Locked]               │
│  Unlock: Complete Level 2
│  (or: 300 points)
├─────────────────────────┤
│  Filter: [All] [New] [In Progress] [Completed]
└─────────────────────────┘
```

### 5.3 Study Screen (Mixed Modes)

**Three challenge types rotate within a level:**

**Type 1: Multiple Choice**
```
┌─────────────────────────┐
│  Listen & Choose        │
│  [Play sound 🔊]        │
│  Which is correct?      │
├─────────────────────────┤
│  ◯ cat                  │
│  ◯ dog  ✓               │  ← User tapped
│  ◯ bird                 │
│  ◯ fish                 │
│  [Submit]               │
└─────────────────────────┘
```

**Type 2: Typing**
```
┌─────────────────────────┐
│  Spell the Word         │
│  [Play sound 🔊]        │
│  Spell: c_t             │  ← Partial reveal or blank
├─────────────────────────┤
│  [cat         ]         │  ← Text input
│  [Check]                │
└─────────────────────────┘
```

**Type 3: Speech (Future with AI)**
```
┌─────────────────────────┐
│  Say the Word           │
│  [Play sound 🔊]        │
│  Listen and repeat      │
├─────────────────────────┤
│  [🎤 Tap to Record]     │
│  Recording...           │
│  [Stop]                 │
└─────────────────────────┘
```

**Flow within a level:**
1. 5-10 words (mix of 3 types)
2. Each correct: +1 point + pop animation
3. After last word: "Level Complete! 🎉"
4. Chest opens → +10 bonus + cosmetic unlocked
5. Back to home screen

### 5.4 Rewards Shop

**Layout:**
```
┌─────────────────────────┐
│  REWARDS SHOP           │
│  You have: 245 points   │
├─────────────────────────┤
│  COSMETICS              │
│  ┌─────────────────┐    │
│  │ [Blue Cat]      │    │
│  │ Owned ✓         │    │  ← Owned items
│  │ Set as avatar   │    │
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │ [Rainbow Theme] │    │
│  │ 50 points       │    │  ← Available cosmetics
│  │ [Redeem]        │    │
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │ [Gold Effect]   │    │
│  │ 100 points      │    │
│  │ [Redeem]        │    │
│  └─────────────────┘    │
├─────────────────────────┤
│  ACHIEVEMENTS           │
│  🏆 Level 1 Master      │  ← Earned badges
│  🏆 7-Day Streak        │
│  ⭕ 30-Day Streak (4 away)
└─────────────────────────┘
```

**Interactions:**
- Tap cosmetic → preview in your avatar
- Tap "Redeem" → deduct points, add to inventory
- Equipped cosmetics shown in profile

### 5.5 Leaderboard & Challenges

**Layout:**
```
┌─────────────────────────┐
│  LEADERBOARD            │
│  🌍 Global              │  ← Filter tabs
├─────────────────────────┤
│  1. 🥇 Alice    325 pts  │
│  2. 🥈 Bob      298 pts  │
│  3. 🥉 Charlie  267 pts  │
│  7. You        180 pts   │  ← Highlight current user
│  ...                     │
├─────────────────────────┤
│  ACTIONS:               │
│  [Challenge Sarah]      │  ← Tap to send challenge
│  [View Profile]         │
│  [Leaderboard Type]     │  ← Filter: Friends, School, Grade
└─────────────────────────┘
```

**Challenge flow:**
1. Tap "Challenge Sarah" → creates challenge record
2. Notification sent to Sarah
3. Sarah taps challenge → both do same level
4. Whoever finishes with higher accuracy wins
5. Winner gets +20 points, both stay friendly

### 5.6 Profile & Settings

**Layout:**
```
┌─────────────────────────┐
│  MY PROFILE             │
│  [Avatar: Blue Cat]     │  ← Equipped cosmetic
│  [Your Name]            │
│  Level: 8               │
├─────────────────────────┤
│  STATS                  │
│  Total Points: 245      │
│  Current Streak: 3 days │
│  Best Streak: 12 days   │
│  Levels Completed: 5/10 │
├─────────────────────────┤
│  COSMETICS              │
│  [Blue Cat] [Theme] ... │
├─────────────────────────┤
│  SETTINGS               │
│  [Sound: On/Off]        │
│  [Notifications: On]    │
│  [Parent Mode]          │  ← Show activity to parents
└─────────────────────────┘
```

---

## 6. Backend API Endpoints (New)

### 6.1 Level Endpoints

```
GET /levels/
  → List all levels (with progress for logged-in user)
  Response: [{ id, name, difficulty, stars_earned, status, ... }]

GET /users/{name}/levels/{level_id}
  → Get level details + word list + user progress
  Response: { level, words, user_progress, ... }

POST /users/{name}/level-progress/{level_id}/start
  → Mark level as started
  Response: { level_id, status: "in_progress", ... }

POST /users/{name}/level-progress/{level_id}/complete
  → Mark level complete + award stars + bonus points
  Body: { accuracy_percentage, time_taken_seconds }
  Response: { stars, points_earned, unlockable_id, ... }
```

### 6.2 Unlockable Endpoints

```
GET /unlockables/
  → List all available cosmetics (owned + available)
  Response: [{ id, name, type, points_cost, rarity, owned, equipped }]

POST /users/{name}/unlockables/{unlockable_id}/redeem
  → Redeem points for cosmetic
  Response: { ok, total_points, unlockable }

POST /users/{name}/unlockables/{unlockable_id}/equip
  → Set cosmetic as active
  Response: { ok, equipped_cosmetic }
```

### 6.3 Challenge Endpoints

```
POST /users/{name}/challenges/create
  Body: { challengee_name, level_id }
  → Create challenge, send notification
  Response: { challenge_id, status: "pending" }

POST /users/{name}/challenges/{challenge_id}/accept
  → Accept challenge
  Response: { challenge_id, status: "accepted" }

POST /users/{name}/challenges/{challenge_id}/complete
  Body: { accuracy_percentage }
  → Complete challenge, determine winner
  Response: { winner, points_earned, ... }
```

### 6.4 Streak Endpoint

```
GET /users/{name}/streak/
  → Get current streak + history
  Response: { current_streak, last_login, history: [...] }

POST /users/{name}/streak/revive
  → Pay 50 points to revive broken streak
  Response: { ok, current_streak, total_points }
```

---

## 7. Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Progression model | Level-based (linear) | Clear goals, easy to understand for P1-P4 |
| Study modes | Mixed (MCQ, typing, speech) | Variety prevents boredom, engages different skills |
| Reward frequency | Per-question + per-level + streak | Duolingo model: multiple feedback loops |
| Cosmetics | Free unlocks (no real money) | Safe for kids, no monetization concerns |
| Backend validation | Server-side (all logic) | Cheat prevention, device sync reliability |
| Platform priority | Flutter app first, web second | Mobile is primary for this age group |
| Social features | Leaderboard + challenges (no chat) | Encourages competition, prevents toxicity |
| Parent integration | Optional activity view (future) | Transparency, teacher feedback loop |

---

## 8. User Flows (Happy Paths)

### 8.1 Day 1: First Time

1. Open app → onboarding (name, age, school)
2. Home screen: "Welcome! Start Level 1"
3. Tap Level 1 → Study screen
4. Complete 8 words (mix of modes)
5. Level complete → Chest opens → +10 pts + Blue Cat avatar
6. Streak: "1 day 🔥"
7. Return to home, see cosmetics in profile

### 8.2 Day 5: Streak Bonus Kicks In

1. Open app → "5-day streak! 2x points active!"
2. Complete any level (points doubled)
3. Earn streak badge achievement
4. Motivated to keep going

### 8.3 Day 10: Challenge Friends

1. Home shows "You're on a 10-day streak!"
2. Leaderboard shows friends with lower scores
3. Tap "Challenge Sarah" → invite sent
4. Sarah accepts → both do same level
5. Your accuracy: 95%, Sarah: 88% → You win
6. +20 bonus points, show off on leaderboard

---

## 9. Success Metrics

- **Engagement:** DAU (daily active users), average session length
- **Retention:** % of users returning after Day 1, Day 7, Day 30
- **Progression:** % completing Level 5+, average levels per user
- **Monetization:** (Future) cosmetic redemption rate, parent purchase rate
- **Learning outcome:** (with teachers) spelling test score improvement

---

## 10. Future Enhancements

- **AI features:** Speech recognition (verify pronunciation), OCR (real-world signs)
- **Parent dashboard:** Progress tracking, custom word lists, activity reports
- **Classroom integration:** Teacher-curated levels, class leaderboards, assignment tracking
- **Advanced cosmetics:** Animated effects, profile customization
- **Offline mode:** download levels, sync when online
- **Multiplayer races:** Real-time duels (not turn-based challenges)

---

## 11. Scope & Constraints

**In Scope (MVP):**
- Level progression (10 levels, ~50 words each)
- Mixed study modes (MCQ, typing, speech with TTS)
- Reward loop (points, stars, cosmetics)
- Streak system
- Leaderboard + friend challenges
- Flutter app + web fallback

**Out of Scope (Phase 2):**
- Parent dashboard
- Teacher classroom mode
- Offline mode
- Real-time multiplayer
- Monetization / in-app purchases
- Advanced analytics

---

## 12. Technical Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Speech recognition unreliable | Kids frustrated if it fails | Fallback to typing/MCQ, user can skip |
| Server load (multiplayer sync) | Challenge system delays | Use optimistic UI updates, queue-based validation |
| Data sync (app offline) | User progress lost | Offline queue, retry on reconnect |
| Cheating (local state manipulation) | Leaderboard integrity | Server validates ALL logic, no client-side progression |

---

## 13. Accessibility & Safety

**For kids:**
- Large tap targets (min 44x44px)
- High contrast text
- No dark flashing (no seizure risk)
- No stranger contact (leaderboard names only, no chat)
- Parental controls optional (mute notifications, time limits)

**For parents/teachers:**
- Optional activity view (show progress to parents)
- Word list visibility (see what child is learning)
- No personal data collection (no email, phone, location)
- No ads or external links

---

## 14. Timeline & Team Estimate

| Phase | Deliverable | Effort | Timeline |
|-------|-------------|--------|----------|
| 1 | Backend schema + core APIs | 2 weeks | Weeks 1-2 |
| 2 | Flutter app (home, levels, study) | 3 weeks | Weeks 2-4 |
| 3 | Rewards + leaderboard | 2 weeks | Weeks 4-5 |
| 4 | Testing + refinement | 1 week | Week 6 |
| **Total** | **MVP** | **~8 weeks** | **6 weeks parallel** |

---

## End of Design Document

**Status:** Ready for implementation planning  
**Next Step:** Invoke writing-plans skill to create detailed implementation roadmap

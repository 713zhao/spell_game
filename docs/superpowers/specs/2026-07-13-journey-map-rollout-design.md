# Journey Map Rollout: Chinese Kingdom, Shared Widget, Rewards, Parent Lock

## Context

`english_castle_screen.dart` already implements the Duolingo-style winding
journey map (circular per-lesson nodes, star ratings, dashed trail, milestone
treasure chests every 5 lessons, "Unlock Anyway" dialog for locked lessons)
feeding into `lesson_overview_screen.dart` ("Start Adventure" gate before
gameplay). This was built for the English Kingdom only. This spec finishes
the rollout:

1. Chinese Kingdom gets the same journey-map experience.
2. The journey-map UI is extracted into a shared, reusable widget instead of
   being duplicated per kingdom.
3. Lesson Overview shows a concrete coin reward, not just the word "Coins".
4. The existing (unwired) "Parent Mode" setting gains a real effect: it
   disables the "Unlock Anyway" skip option.
5. The now-bypassed flat word-grid screens are deleted.

## 1. Shared `JourneyPath` widget

New files:
- `lib/models/stage_data.dart` — moves `StageData` (stageNumber, title,
  progress, stars, isLocked) out of `english_castle_screen.dart` so both
  kingdom screens can share it.
- `lib/widgets/journey_path.dart` — moves `_JourneyPath`, `_LessonNode`,
  `_MilestoneNode`, `_StarRow`, `_TrailPainter`, the `_NodeState` enum, the
  `_stateFor` derivation, and the locked-lesson dialog out of
  `english_castle_screen.dart` into a public `JourneyPath` widget.

`JourneyPath` constructor parameters:
- `stages: List<StageData>`
- `kingdomEmoji: String`, `kingdomLabel: String` (banner at top of the path)
- `gradientColors: List<Color>` (background wash + milestone accents already
  derived from `DuolingoColors`)
- `allowSkipLock: bool` — when false, the locked-lesson dialog shows only an
  "OK" button (no "Unlock Anyway"); when true, behaves as today.
- `onSelectLesson: void Function(int stageNumber)` — called when a tappable
  node (completed/current/available, or a locked node the user chose to
  unlock) is activated. The screen supplies navigation to
  `/lesson-overview`.

`english_castle_screen.dart` becomes a thin wrapper: keeps its own
`stages` mock list and pulse controller, renders header + `JourneyPath` +
bottom nav, no path-rendering logic of its own.

## 2. Chinese Kingdom journey map

`chinese_kingdom_screen.dart` is rewritten to the same shape as English
Kingdom: single scrolling `JourneyPath`, no intermediate
Forest/River/Mountain section-select screen. 30 `StageData` entries,
titled `Forest 1`..`Forest 10`, `River 1`..`River 10`, `Mountain 1`..
`Mountain 10` (nickname prefix by range, matching the request to keep the
nature theming as a per-lesson label rather than a separate structural
level). Progress ported from the current mock: stages 1-7 completed
(carries the existing 7/10 Forest progress), stage 8 current, 9-10
available, 11-30 locked. Milestone chest every 5 stages, same as English.
Uses `DuolingoColors.chineseKingdomGradient` and the 🐉 emoji for the
banner.

Tapping a node navigates to `/lesson-overview` with the stage number as
argument, same as English Kingdom.

## 3. Lesson Overview rewards + kingdom theming

`lesson_overview_screen.dart` gains:
- `coins = wordCount * 2` (parallels the existing `maxXp = wordCount * 10`),
  rendered in the existing `_RewardChip` in place of the static "Coins"
  label: `'$coins Coins'`.
- A `kingdom` parameter (`emoji`, `label`, `gradientColors`) so the header
  card reflects English vs. Chinese instead of being hardcoded to
  `englishKingdomGradient` / 🏰. Both journey screens pass their own
  kingdom's theme when navigating to `/lesson-overview`; default stays
  English if no kingdom is passed (keeps other existing callers working
  unchanged).

## 4. Parent Mode disables skip-lock

`profile.dart` already persists a `parent_mode` bool via
`SharedPreferences` with a switch in Settings, currently unread anywhere
else. Both kingdom screens read this flag once at `initState`
(`SharedPreferences.getInstance()...getBool('parent_mode') ?? false`) and
pass `allowSkipLock: !parentMode` into `JourneyPath`. No new settings UI is
added — the existing toggle becomes functional.

## 5. Retire flat word-grid screens

Delete `english_level_screen.dart` and `chinese_lesson_screen.dart` along
with the `/english-level` and `/chinese-lesson` routes and imports in
`main.dart`. Nothing else references these routes once Chinese Kingdom is
switched to `/lesson-overview`.

## Out of scope

- No backend/persistence changes for stage progress (still mock data).
- No new parental-control UI beyond wiring the existing switch.
- No changes to the actual gameplay/study screen.

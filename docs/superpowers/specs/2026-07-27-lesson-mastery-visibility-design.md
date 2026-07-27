# Lesson Mastery Visibility

**Date:** 2026-07-27
**Status:** Approved
**App:** FlutterSpell_Game (frontend) + SpellBackend (backend)

## Problem

Two related issues surfaced while investigating "how many times do I need to redo a lesson before the next unlocks":

1. **The unlock rule is invisible.** A lesson's mastery is `average(min(word.repetitions, 5) / 5)` across all its words (`SpellBackend/src/services/lesson_manager.py:228-242`). The backend currently unlocks the next lesson at `mastery_pct >= 0.8` (line 244), but nothing in the UI shows this percentage, the 80% threshold, or which specific words are dragging it down — only star icons (0-3, also derived from the same percentage) are shown. Users have no way to tell why a lesson feels "not quite done."
2. **A latent threshold mismatch.** The World Map node's checkmark is computed client-side in `FlutterSpell_Game/lib/models/stage_data.dart` using `progress >= 1.0` (100% mastery) — a stricter bar than the backend's 80% unlock threshold. So a lesson can already be server-side "completed" (next lesson unlocked) while its own map node still shows as in-progress, with no checkmark.

## Decisions

- **Unlock threshold changes from 80% to 100%.** Every word in a lesson must reach `repetitions >= 5` (5 correct answers in a row for that word — any wrong answer resets that word's own counter to 0, per the existing SM-2 scheduler in `scheduler.py`) before the next lesson unlocks. This also resolves the map/backend mismatch outright: the client's existing `progress >= 1.0` checkmark logic already matches a 100% backend threshold, so no client-side checkmark logic needs to change — only the backend threshold.
- **Stars realign to the new threshold:** 3⭐ only at 100% (was 80%) — so 3 stars now always means "fully mastered, next lesson unlocked." 2⭐ stays at ≥50%, 1⭐ stays at >0%.
- **Mastery becomes visible in two places:**
  1. A progress ring around each lesson's node on the World Map, showing the percentage.
  2. A mastery bar on the Lesson Overview screen (word count / time / rewards screen shown before starting), reading like "Mastery: 73% · 100% needed to unlock 第二课."
- **Tap-to-expand per-word detail** on the Lesson Overview screen: tapping the mastery bar reveals a small chip grid, one chip per word, colored by state (green = mastered / 5 reps, yellow = in progress / 1-4 reps, grey = not started or just reset to 0).
- **A short in-UI explanation of the reset rule**, via a small (i) info icon next to the mastery bar: "Each word needs 5 correct answers in a row — a mistake resets that word to 0."

Mockups for the map ring and the combined Lesson Overview layout were reviewed and approved via the visual brainstorming companion (session `4129-1785146584`, not committed — ephemeral mockups, not spec).

## Architecture

### Backend change (small)

`SpellBackend/src/services/lesson_manager.py`, `list_lessons_for_user`:
- Line 244: `if mastery_pct >= 0.8:` → `if mastery_pct >= 1.0:` (completion/unlock threshold).
- Lines 252-256: the `stars` ternary's `3 if mastery_pct >= 0.8` condition → `3 if mastery_pct >= 1.0` (the `2 if >= 0.5` and `1 if > 0` tiers are unchanged).

No response-shape changes, no new fields, no new endpoint. `mastery_pct` itself was already returned in the `/lessons/{user_name}` response and already consumed by the Flutter `LessonSummary` model (`FlutterSpell_Game/lib/models/game_models.dart:168`) — the frontend already has the number it needs for both the ring and the overview bar without any API change.

### Frontend: per-word detail reuses the existing deck endpoint — no new backend endpoint

This was the main open question during design: does showing a per-word chip grid require a new backend endpoint? No. `GET /users/{name}/deck?tag=<comma-separated lesson tags>&limit=<n>` (`SpellBackend/src/routes/study.py:22-23`, `DeckBuilder.build_daily_deck`) already:
- Accepts the lesson's own tags (`LessonSummary.tags`, already in hand on the Lesson Overview screen).
- Returns every word matching those tags regardless of spaced-repetition due-date (confirmed in `deck_builder.py`: due-date only affects bucket ordering, not inclusion, per the existing `b7e7e83` fix) — as long as `limit` is at least the lesson's word count. `LessonSummary.wordCount` is already known, so the frontend can safely pass `limit: lesson.wordCount` and get the complete set, not just words "due today."
- Includes each word's `text` and `state.repetitions` already (`deck_builder.py:82-87` etc.), exactly what the chip grid needs.

So: tapping "show word-by-word progress" on the Lesson Overview screen triggers a normal `ApiClient.getDeckCards(tags: lesson.tags, limit: lesson.wordCount)` call (same method `study.dart` already uses to build its exercise queue, called here for display only — this call does not start a study session), and the chip grid renders directly from the returned `List<DeckCard>` (`word.text` + `repetitions`, bucketed into the three color tiers: `>= 5` green, `1-4` yellow, `0` grey).

### Frontend: World Map node ring

`FlutterSpell_Game/lib/widgets/journey_path.dart`'s `_LessonNode` (lines 315-390ish) currently renders a solid-fill circle keyed off a `NodeState` enum (completed/current/available/locked), with no numeric progress shown. Add a thin circular progress ring (e.g. `CustomPaint` arc or a wrapping `Stack` with a ring drawn behind the existing circle) driven by the lesson's `masteryPct` (already flowing into this widget's `NodeState` derivation via `stage_data.dart`), with the percentage as small text either inside or below the node depending on space. Exact widget composition is an implementation detail for the plan, not fixed here — the constraint is: reuse the existing `masteryPct` value already computed for `NodeState`/stars, don't fetch anything new for this piece.

### Frontend: Lesson Overview screen additions

`lesson_overview_screen.dart` currently shows word count / estimated time / rewards, with stars already rendered from `LessonSummary.stars`. Add, directly using data already on the `LessonSummary` passed into this screen (no new fetch needed for the bar itself):
- A labeled progress bar: `"Mastery: {masteryPct * 100}%"` + a bar fill + `"100% needed to unlock {nextLessonName}"` (or a generic "the next lesson" if the next lesson's name isn't readily available in this screen's data — implementation detail for the plan).
- A small (i) icon next to the bar; tapping/pressing it shows the fixed explanation text (a dialog, tooltip, or inline expandable text — implementation detail for the plan) : *"Each word needs 5 correct answers in a row — a mistake resets that word to 0."*
- A "Show word-by-word progress ▾" toggle that, on first tap, fires the `getDeckCards` call described above and renders the resulting chip grid inline; collapses back on second tap without re-fetching (cache the result for the lifetime of this screen instance).

## Data Flow Summary

- **Ring + bar (percentage only):** zero new network calls — `masteryPct` already arrives via the existing `/lessons/{user}?subject=` call that populates the World Map and feeds into the Lesson Overview screen's navigation args.
- **Per-word chip grid:** one on-demand `GET /users/{name}/deck?tag=...&limit=...` call, fired only when the user taps to expand — not fetched eagerly for every lesson on screen load.

## Error Handling

- If the on-demand `getDeckCards` call for the chip grid fails: show a small inline "Couldn't load word details" message in place of the grid; the mastery bar/percentage (already-known data) stays visible and unaffected.
- If `masteryPct` is `0.0` (word never studied / lesson never attempted): ring shows empty/0%, bar shows "Mastery: 0%", no chip grid content differs from any other state (all words would show grey).

## Out of Scope

- Any change to the SM-2 scheduling algorithm itself (reset-to-0-on-wrong-answer behavior is explained, not changed).
- A new backend endpoint — explicitly avoided per the data-flow analysis above.
- Retroactively recalculating/migrating existing users' lesson `status`/`stars` — the threshold change applies going forward; a lesson previously shown as "completed" under the 80% rule will, on next fetch, be reassessed against the new 100% rule using the same underlying `ReviewState` data (no stored `status` field to migrate — it's computed fresh every request).
- Changing the World Map's non-lesson nodes (Milestone/treasure-chest nodes) — ring is lesson nodes only.

## Verification Plan

- Backend: unit/behavioral check that a lesson with all words at `repetitions == 5` now shows `status: "completed"` and `stars: 3`, and one with any word below 5 does not, even if the average was previously ≥0.8.
- Frontend: `flutter analyze` + `flutter test` on the touched files; a widget test for the Lesson Overview screen's mastery bar/info-icon/expand-to-chip-grid behavior (success and failure-to-load cases), following this repo's established `FakeGameProvider`-based testing pattern.
- Manual: live build + headless-browser check (as used earlier this session) confirming the ring renders on the World Map, the bar/tooltip/chip-grid work on Lesson Overview against the real production backend, and that a lesson previously showing 3 stars under the old rule now correctly reflects the new 100% bar if it wasn't actually fully mastered.

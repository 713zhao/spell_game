# Lesson Checkpoints

**Date:** 2026-08-03
**Status:** Approved
**App:** FlutterSpell_Game (frontend) + SpellBackend (backend)

## Problem

A lesson currently has exactly two visible states: locked and unlocked (with an in-between 0-100% mastery bar once unlocked, per `lesson-mastery-visibility`). In practice, reaching 100% mastery on a 15-20 word lesson takes about a week of daily practice, but the UI gives the user nothing to climb in the meantime beyond a single percentage number. There's no Duolingo-style sense of discrete progress within a lesson.

The fix is not a calendar-based mechanic ("must practice 7 days") — the app has no day/week/cooldown concept anywhere today, and inventing one would gate progress on time-in-app rather than actual learning. Instead, a lesson's word list is split into small, sequentially-unlocked **checkpoints**, so pacing stays entirely mastery-driven: a checkpoint clears the moment its words are mastered, whether that takes one sitting or many.

## Decisions

- **Checkpoint size: fixed 5 words.** A lesson's words, sorted ascending by `word_id`, are chunked into groups of 5 (last group gets the remainder). `word_id` ascending is used as the ordering because it's the only stable ordering available without adding a new column, and for freshly-imported lessons it matches the source word-list order (`WordManager.import_words_from_json` adds words in list order with autoincrement IDs). No new "sequence" column is introduced — see Out of Scope.
- **Checkpoint state is derived, never stored.** Exactly like lesson `status`/`stars` today (`lesson_manager.py:244-256`), a user's current checkpoint for a lesson = the first chunk where not every word has `repetitions >= 5`. Nothing new is written to the DB to track "which checkpoint am I on" — it's recomputed from `ReviewState` on every request. This avoids a second source of truth that could drift from the underlying mastery data.
- **Checkpoints gate practice, not just display.** Only the current checkpoint's ~5 words are practiceable in a study session; later checkpoints' words aren't fetched into the deck until earlier ones are cleared. The gate works by scoping which words `/deck` returns for a given checkpoint request (see Architecture) — like the rest of `/deck`/`/review` today, there's no backend ownership check preventing a client from requesting a checkpoint it hasn't reached; the client (Lesson Overview / study session) simply never asks for one.
- **Lesson-level unlock (100% mastery → next lesson) is unchanged.** Checkpoints are a sub-lesson layer; nothing about `list_lessons_for_user`'s existing 100% threshold changes.
- **Cross-session remedial priority, via a new `fail_count`.** A word that keeps resetting to 0 should resurface sooner in future sessions, not just within the session it failed in (same-session requeueing already exists client-side, see below, and is unchanged). `ReviewState` gains a `fail_count` column, incremented whenever `Scheduler.update_sm2` takes the `quality < 3` branch (never reset). `DeckBuilder` sorts each checkpoint's card pool by `fail_count` descending first, before the existing due-date/ease_factor ordering.
- **No mid-session checkpoint transitions.** If a user clears the current checkpoint's last word mid-session, the session still ends normally (existing summary screen). The newly-unlocked checkpoint's words become fetchable the next time a study session starts or the Lesson Overview screen reloads — checkpoint state is recomputed fresh on each `/lessons` or `/deck` call, so no explicit "advance" step is needed.

## Architecture

### Backend: checkpoint computation (new, small, alongside existing mastery logic)

`SpellBackend/src/services/lesson_manager.py`, `list_lessons_for_user` (`lesson_manager.py:222-270`) already gathers `word_ids` and `state_by_word` per lesson to compute `mastery_pct`. Reuse that same data to add, per lesson dict:
- `checkpoint_index` (0-based): sort `word_ids` ascending, chunk into groups of 5, find the first chunk where any word has `repetitions < 5`. If all chunks are fully mastered, `checkpoint_index` = last chunk index (matches the lesson already being at/near 100%).
- `checkpoint_count`: `ceil(word_count / 5)`.

No new query — same `state_by_word` map already built at `lesson_manager.py:236`.

### Backend: `/deck` scoping to a checkpoint

`SpellBackend/src/routes/study.py:22-37` (`get_daily_deck`) gains an optional `checkpoint: int` query param, passed through to `DeckBuilder.build_daily_deck` (`deck_builder.py:16`). When `checkpoint` is provided alongside `tag`:
1. Resolve the tag's word pool as today (`word_manager.get_words_by_user_and_tags`, `deck_builder.py:35`), but with an explicit `.order_by(SpellingWord.id)` added (`word_manager.py:74` currently has no `ORDER BY`, so result order is DB-incidental — this must be made deterministic for chunking to be stable).
2. Slice to the requested checkpoint's 5-word chunk.
3. Build cards from only that subset, using the existing overdue/new/not-due-yet bucketing (`deck_builder.py:49-69`) — but each bucket's sort key gains `fail_count` descending as the primary key, ahead of `due_date`/`ease_factor` (`deck_builder.py:68-69`).

When `checkpoint` is omitted, behavior is unchanged (existing callers unaffected).

### Backend: `fail_count` tracking

`SpellBackend/src/models/review_state.py`: add `fail_count: int = 0`.
`SpellBackend/src/services/scheduler.py`, `update_sm2` (`scheduler.py:22-24`): in the `quality < 3` branch, add `state.fail_count += 1`.

### Client: Lesson Overview — checkpoint sections in the word grid

`lesson_overview_screen.dart` already fetches the lesson's full deck (`initState`, lines 85-88: `loadDeck(tags: ..., limit: lesson.wordCount)`) and renders a flat chip grid (`_buildWordDetailGrid`, lines 127-158). Change: sort `gameProvider.deckCards` by `card.word.id` ascending, chunk into groups of 5 client-side (same rule as the backend), and render each chunk as its own labeled section ("Checkpoint 1", "Checkpoint 2", ...). A chunk at index `> lesson.checkpointIndex` renders its chips in a locked/greyed style (reuse the existing grey tier color, no new color needed) instead of the mastery-tier colors, signaling "not yet practiceable" rather than "not yet mastered."
`LessonSummary` (`game_models.dart:161-198`) gains `checkpointIndex` and `checkpointCount` fields, parsed from the new `/lessons` response fields.

### Client: World Map — checkpoint indicator on lesson nodes

`journey_path.dart`'s `_LessonNode` already renders the mastery ring added in `lesson-mastery-visibility`. Add a small "checkpoint N/M" label (or N small dots) near the ring, driven by `lesson.checkpointIndex`/`checkpointCount` — no new fetch, same `/lessons` call that already populates this widget.

### Client: study session scoped to the current checkpoint

`study.dart`'s `_loadWords` (lines 158-214) calls `gameProvider.loadDeck(tags: widget.args.tags)` with no `limit`, defaulting to 10 (`api_client.dart:93`) and pulling from anywhere in the lesson's due words. Change: `StudySessionArgs` (`lesson_overview_screen.dart:50-64`) gains a `checkpoint` field, populated from `lesson.checkpointIndex` when the Start Adventure button builds it (`lesson_overview_screen.dart:413-419`). `_loadWords` passes this through to `loadDeck`/`getDeckCards` as the new `checkpoint` param, and drops the `limit` down to something checkpoint-sized (e.g. don't pass a limit at all — a checkpoint is already only 5 words, well under the current default of 10). The existing same-session wrong-answer requeue (`study.dart:532-536`, push to back of local `_queue`) is unchanged — that's a different, already-working mechanism from the new cross-session `fail_count` priority.

## Data Flow Summary

- **Checkpoint index/count on World Map + Lesson Overview:** zero new network calls — computed server-side from data already gathered for `mastery_pct`, added to the existing `/lessons/{user}?subject=` response.
- **Checkpoint-scoped word grid on Lesson Overview:** same existing `getDeckCards(tags, limit: wordCount)` call, unchanged — grouping into checkpoint sections is purely a client-side rendering change over data already being fetched.
- **Checkpoint-scoped study session:** existing `getDeckCards` call gains one new query param (`checkpoint`); no separate endpoint.

## Error Handling

- If `/lessons` doesn't return `checkpoint_index`/`checkpoint_count` (e.g. mid-rollout version skew), client defaults `checkpointIndex` to 0 and `checkpointCount` to `(wordCount / 5).ceil()` — degrades to "checkpoint 1 of N, nothing locked yet" rather than crashing.
- If a `/deck?checkpoint=N` request is made for a checkpoint the user hasn't reached yet (e.g. stale client state), the backend still returns that chunk's words rather than erroring — the checkpoint gate is enforced by the *client not requesting* a locked checkpoint (via `StudySessionArgs`/Lesson Overview only ever offering the current one), not by a backend 403. This matches the existing trust model (`/deck` and `/review` have no auth/ownership checks beyond username today).
- Lessons with `word_count == 0` (shouldn't occur given existing `if word_ids:` guard at `lesson_manager.py:229`) keep `checkpoint_count = 0`, no section rendered.

## Out of Scope

- A real "authored order" column for words (e.g. an explicit `sequence` field) — ascending `word_id` is used as a proxy. If a lesson is edited/re-imported such that word IDs no longer reflect intended teaching order, checkpoint chunking would follow ID order rather than the edited order; fixing that would require a schema change and CMS/import tooling changes not requested here.
- Any change to the per-word mastery bar itself (5-correct-in-a-row, reset-to-0-on-miss) — unchanged, only which words are *offered* for practice at a time changes.
- Mid-session checkpoint-cleared celebration/transition UI — session end behavior is unchanged; the "you unlocked checkpoint 2!" moment (if wanted) is a follow-up, not part of this change.
- Retroactive backfill of `fail_count` for existing `ReviewState` rows — new column defaults to 0; historical failures before this change aren't counted, only failures going forward.
- Changing `/lessons`' existing 100%-mastery next-lesson unlock threshold or star tiers.

## Verification Plan

- Backend: unit tests for checkpoint chunking (word counts 0, 1, 5, 6, 18 → correct chunk boundaries and `checkpoint_count`), checkpoint-index derivation (first non-fully-mastered chunk), and `fail_count` incrementing only on `quality < 3`.
- Backend: `/deck?checkpoint=N` returns only that chunk's word IDs, ordered by `fail_count` desc within the existing overdue/new/not-due tiers.
- Frontend: `flutter analyze` + `flutter test`; widget test for Lesson Overview's checkpoint-sectioned grid (locked chunks greyed, current/completed chunks showing real mastery colors); confirm `StudySessionArgs`/`study.dart` only ever requests the current checkpoint's words.
- Manual: live build against the real backend — clear a 5-word checkpoint, confirm the next one unlocks on next session/screen load without any explicit "advance" action, and confirm a word that fails repeatedly surfaces earlier in a later session.

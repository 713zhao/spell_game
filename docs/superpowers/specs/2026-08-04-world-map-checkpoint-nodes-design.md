# World Map Checkpoint Nodes

**Date:** 2026-08-04
**Status:** Approved
**App:** FlutterSpell_Game (frontend only)

## Problem

The [lesson-checkpoints](2026-08-03-lesson-checkpoints-design.md) feature made checkpoint progress derivable and gate-able end to end, but its World Map treatment (`journey_path.dart`) only added a small "Checkpoint N/M" text caption under the existing single lesson node. Visually this is barely noticeable — a screenshot review showed a lesson at "Checkpoint 1/3" rendered as one circle with a caption, with the dashed trail running straight to the next lesson's single circle with no visible intermediate steps. This doesn't deliver on the original goal (visible, Duolingo-style progress between lessons): a user can't see checkpoint progress at a glance, only by reading text.

The fix, confirmed via visual mockups reviewed in the brainstorming companion: make each checkpoint a full-size path node, exactly like today's lesson nodes, chained one after another — the same treatment Duolingo itself uses (a "unit" is just a run of same-sized nodes on the path, not one node with a caption).

## Decisions

- **Each checkpoint becomes its own full-size path node**, styled identically to today's lesson nodes (locked/current/completed/available, same colors, same lock/fire/check icons). A lesson with `checkpointCount` checkpoints contributes that many consecutive nodes to the path instead of one. Legacy/mock `StageData` with no checkpoint info (`checkpointCount <= 1`, e.g. `chinese_stages.dart`'s test fixtures) still renders as exactly one node per lesson — today's behavior is a special case of the new logic, not a separate code path.
- **No per-node progress ring.** Today's `CircularProgressIndicator` ring (driven by lesson-wide `mastery_pct`) is dropped from World Map nodes entirely. Duolingo's own nodes are locked/current/done, not fine-grained percentage rings, and once a lesson is checkpoint-node-chained there's no single "this node's progress" percentage to show anyway (checkpoints before the current one are simply done; the current one is simply current). The existing mastery percentage/bar stays on the Lesson Overview screen, which remains the detailed view.
- **Title, spell date, and star row appear once per lesson**, anchored to the *middle* checkpoint node of that lesson's cluster (index `(checkpointCount - 1) ~/ 2`), not repeated on every node and not attached to whichever node happens to be current. Other nodes in the same cluster render bare (icon + state color only).
- **The treasure-chest milestone now fires every 5 checkpoint nodes**, counted across the whole flattened path, not every 5 lessons. This keeps chest cadence roughly steady regardless of how many words a given lesson has, at the cost of changing today's "every 5th lesson" cadence.
- **Checkpoint-level node state, derived the same way today's lesson-level state already is** — just at finer granularity:
  - A unit (one checkpoint-within-a-lesson) is **locked** if the whole lesson is locked (`stage.isLocked`), or if it's a checkpoint the user hasn't reached yet (`checkpointIndexInLesson > stage.checkpointIndex`) within an otherwise-unlocked lesson.
  - A unit is **completed** if the whole lesson is fully mastered (`stage.progress >= 1.0`), or it's an earlier checkpoint than the current one (`checkpointIndexInLesson < stage.checkpointIndex`).
  - The first unit that's neither locked nor completed is **current**; any later not-locked, not-completed unit is **available** (mirrors today's replay-earlier-unlocked-lesson semantics, now at checkpoint granularity).
- **Tap handling splits by lock *reason*, not just lock state:**
  - Tapping a node locked because its *lesson* is locked shows today's existing "This lesson is designed to build on previous skills... Unlock anyway?" dialog, unchanged.
  - Tapping a node locked because it's a *checkpoint not yet reached* (lesson itself is unlocked) shows a lightweight, non-blocking message ("Clear checkpoint N first!") and does nothing else — no dialog, no navigation. There's no "skip a checkpoint" feature; this just tells the user why the node looks locked.
  - Tapping any non-locked node (current/completed/available) — regardless of which checkpoint it visually represents — calls `onSelectLesson(stage.stageNumber)` exactly as today. Lesson Overview always starts the session at the lesson's real current checkpoint (from fresh `LessonSummary` data), not whichever node was tapped, so no new information needs to flow from "which node was tapped" into navigation — the existing single-argument callback (`void Function(int stageNumber)`) is unchanged.
- **Path layout mechanics are unchanged.** The zig-zag x-position pattern, row spacing, dashed trail painter, and milestone widget already operate per path-item index; flattening lessons into more items just makes the existing loop run longer. No new positioning logic is needed, but the visual path does get noticeably longer/windier (a kingdom with 20 lessons averaging 4 checkpoints each goes from ~20 nodes to ~80) — this is the intended tradeoff for visible progress, not a bug to guard against.

Three layout directions (stepping-stone dots above the node, a segmented progress ring, and this full-node-chain approach) and the two follow-up choices above (label placement, milestone cadence) were reviewed via the brainstorming visual companion and approved.

## Architecture

### `FlutterSpell_Game/lib/models/stage_data.dart` — flattening and state derivation move here

`deriveNodeState(List<StageData> stages, int index)` (lesson-granularity, currently used by `journey_path.dart` at two call sites) is retired — its logic is superseded by the new flattening/state logic below, computed once and attached to each path item rather than re-derived by the caller per-render.

`PathItem`/`LessonItem`/`MilestoneItem` are reshaped:

```dart
class LessonItem extends PathItem {
  final int stageIndex;       // index into the original `stages` list
  final int checkpointIndex;  // 0-based position within this lesson's cluster (always 0 when checkpointCount <= 1)
  final NodeState state;      // precomputed: locked | current | completed | available
  final bool isLabelAnchor;   // true only for the middle node of this lesson's cluster
  LessonItem({
    required this.stageIndex,
    required this.checkpointIndex,
    required this.state,
    required this.isLabelAnchor,
  });
}
```

`buildPathItems(List<StageData> stages)` keeps its existing name and signature (so `journey_path.dart`'s single call site, `buildPathItems(widget.stages)`, doesn't change), but internally:
1. For each stage, computes `unitCount = stage.checkpointCount <= 1 ? 1 : stage.checkpointCount` and builds `unitCount` `LessonItem`s (using the locked/completed/current/available rules from Decisions above), with `isLabelAnchor` set on index `(unitCount - 1) ~/ 2`.
2. Flattens all lessons' units into one list, in stage order.
3. Walks the flattened list inserting a `MilestoneItem` after every 5th unit (same `unlocked` rule as today — the preceding unit's `state == NodeState.completed` — just evaluated at the new granularity).

Also add `MilestoneItem`'s constructor is unchanged. `NodeState` enum is unchanged (still `completed | current | available | locked`).

### `FlutterSpell_Game/lib/widgets/journey_path.dart`

- `_handleNodeTap` takes a `LessonItem` (not a raw index). Branches:
  - `item.state == NodeState.locked && widget.stages[item.stageIndex].isLocked` → today's `_showUnlockDialog(item.stageIndex)` (parameter renamed/rebased from the old path-item index to the stage index it now explicitly carries).
  - `item.state == NodeState.locked` (lesson unlocked, checkpoint not reached) → `ScaffoldMessenger.of(context).showSnackBar(...)` with a message naming the checkpoint to clear first (`widget.stages[item.stageIndex].checkpointIndex + 1`, the lesson's real current checkpoint, 1-based for display).
  - otherwise → `widget.onSelectLesson(widget.stages[item.stageIndex].stageNumber)`, unchanged.
- `_buildItemWidgets` reads `item.state` directly (no more calling a derive function). `_LessonNode` drops its `progress` parameter and the `CircularProgressIndicator` ring entirely — every non-locked node keeps its existing pulse-glow (current state) and icon, just without the ring wrapping it. The star-row/title/date `Column` only renders `if (item.isLabelAnchor)`.
- `_showUnlockDialog` takes a stage index directly (already effectively did; just formalizing that it's `stageIndex`, not "whatever index the path item happened to have").
- `_StarRow`, `_MilestoneNode`, `_TrailPainter` are unchanged.

### Kingdom screens

`english_castle_screen.dart` / `chinese_kingdom_screen.dart` need no changes — they already pass `checkpointIndex`/`checkpointCount` into `StageData` from the prior feature.

## Data Flow Summary

No new network calls, no backend changes. This is a pure client-side rendering/interaction rework of the World Map, consuming `StageData` fields (`checkpointIndex`, `checkpointCount`, `progress`, `isLocked`, `stars`) that already exist and are already populated from `/lessons`.

## Error Handling

- A lesson with `checkpointCount == 0` (shouldn't occur per the backend's existing guard for zero-word lessons, but defensively handled) renders as 1 node via `max(1, checkpointCount)`, same as legacy stages — never zero nodes, which would silently drop a lesson from the path.
- If `stage.checkpointIndex` is ever out of range for `stage.checkpointCount` (shouldn't happen given how the backend derives it, but not guaranteed by the type system), the locked/completed comparisons degrade gracefully: an index beyond `checkpointCount` just means every unit in that lesson evaluates as "not yet reached" (locked) except none being marked current from this lesson, which simply means the lesson silently has no current node — a display quirk, not a crash. Not worth defensive clamping given the same risk already existed (and was deliberately accepted, with a clamp at the backend/query layer) for the equivalent case in the `/deck` endpoint.

## Out of Scope

- Any change to `english_castle_screen.dart`/`chinese_kingdom_screen.dart` beyond what already exists (no changes needed at all, per above).
- A "skip this checkpoint" feature — the not-yet-reached-checkpoint toast is informational only.
- Per-checkpoint progress rings or partial-mastery indicators on individual nodes (explicitly dropped, see Decisions).
- Changing the treasure-chest reward/unlock mechanics themselves (`_MilestoneNode`, `_handleMilestoneTap`) — only how often a chest item appears in the flattened sequence changes, not what it does when tapped.

## Verification Plan

- `flutter analyze` + `flutter test` on touched files.
- Unit tests in `stage_data_test.dart` replacing the retired `deriveNodeState` group: flattening produces `max(1, checkpointCount)` units per lesson; checkpoint-level locked/current/completed/available derivation matches the rules in Decisions (including the "lesson fully mastered → every checkpoint in it is completed" case, and the "lesson locked → every checkpoint in it is locked" case); label-anchor index selection for a few `checkpointCount` values (1, 2, 3, 4, 5); milestone insertion every 5 flattened units (not every 5 lessons).
- Widget tests in `journey_path_test.dart`: existing tests (which use legacy 1-checkpoint-per-lesson fixtures) should continue passing unchanged, proving the flattening degrades correctly to today's behavior. New tests: a lesson with multiple checkpoints renders that many nodes; tapping a not-yet-reached checkpoint shows the toast and does not navigate; tapping a locked lesson's node still shows the existing unlock dialog; the label/star row appears only once per lesson cluster, on the correct node.
- Manual: live build, confirm a multi-checkpoint lesson visually shows a chain of full-size nodes on the World Map matching the reviewed mockup, confirm the toast on a not-yet-reached checkpoint, confirm chest cadence.

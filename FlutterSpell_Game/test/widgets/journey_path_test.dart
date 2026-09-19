import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/journey_path.dart';

List<StageData> _collapsed() => const [
  StageData(
    stageNumber: 1,
    title: 'Stage 1',
    progress: 1.0,
    stars: 3,
    isLocked: false,
    isCompleted: true,
    checkpointCount: 3,
  ),
  StageData(
    stageNumber: 2,
    title: 'Stage 2',
    progress: 0.0,
    stars: 0,
    isLocked: true,
    checkpointCount: 3,
  ),
];

// The current lesson: [passed] flags per checkpoint, review not passed.
StageData _current({
  List<bool> passed = const [true, false, false],
  int reviewDue = 0,
  String title = 'Week 1',
  int stars = 1,
  String? spellDate,
  Set<int> unlocked = const {},
}) => StageData(
  stageNumber: 1,
  title: title,
  progress: 0.4,
  stars: stars,
  isLocked: false,
  spellDate: spellDate,
  checkpointCount: passed.length,
  checkpointPassed: passed,
  reviewDueCount: reviewDue,
  unlockedNodes: unlocked,
);

class _Taps {
  (int, int?)? selected;
  (int, int)? unlocked;
}

Future<_Taps> _pump(
  WidgetTester tester, {
  bool allowSkipLock = true,
  List<StageData>? stages,
}) async {
  final taps = _Taps();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: JourneyPath(
            stages: stages ?? _collapsed(),
            kingdomEmoji: '🏰',
            kingdomLabel: 'Castle',
            gradientColors: const [Color(0xFFE6F5FF), Color(0xFFCCE6FF)],
            allowSkipLock: allowSkipLock,
            onSelectNode: (stage, index) => taps.selected = (stage, index),
            onUnlockConfirmed: (stage, index) => taps.unlocked = (stage, index),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return taps;
}

// NOTE: don't use pumpAndSettle() in these tests - JourneyPath's pulse
// AnimationController repeats indefinitely (for the "current" node glow), so
// it would never settle. Pump a bounded duration instead, long enough for a
// dialog's open/close transition.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('tapping a completed lesson node selects the whole lesson', (
    tester,
  ) async {
    final taps = await _pump(tester);

    await _tap(tester, find.byIcon(Icons.check));

    expect(taps.selected, (1, null));
  });

  testWidgets(
    'tapping a locked lesson offers Unlock Anyway, which unlocks its first point',
    (tester) async {
      final taps = await _pump(tester);

      await _tap(tester, find.byIcon(Icons.lock));
      expect(find.text('🔒 This lesson is locked'), findsOneWidget);
      expect(find.text('UNLOCK ANYWAY'), findsOneWidget);

      await _tap(tester, find.text('UNLOCK ANYWAY'));

      expect(taps.unlocked, (2, 0));
      expect(taps.selected, (2, 0));
    },
  );

  testWidgets('with allowSkipLock false a locked node has no skip option', (
    tester,
  ) async {
    final taps = await _pump(tester, allowSkipLock: false);

    await _tap(tester, find.byIcon(Icons.lock));

    expect(find.text('UNLOCK ANYWAY'), findsNothing);
    expect(find.text('OK'), findsOneWidget);

    await _tap(tester, find.text('OK'));

    expect(taps.selected, isNull);
    expect(taps.unlocked, isNull);
  });

  testWidgets('the current lesson shows a node per point plus a review node', (
    tester,
  ) async {
    await _pump(tester, stages: [_current()]);

    // point 1 done, point 2 current, point 3 and the review still locked.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNWidgets(2));
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('the review label shows how many words are due', (tester) async {
    await _pump(tester, stages: [_current(reviewDue: 4)]);

    expect(find.text('Review · 4 due'), findsOneWidget);
  });

  testWidgets('tapping the current point selects it', (tester) async {
    final taps = await _pump(tester, stages: [_current()]);

    await _tap(tester, find.text('🔥'));

    expect(taps.selected, (1, 1));
  });

  testWidgets(
    'tapping a future point asks to confirm, then unlocks only that point',
    (tester) async {
      final taps = await _pump(tester, stages: [_current()]);

      // The first lock icon is point 3 (the review node comes after it).
      await _tap(tester, find.byIcon(Icons.lock).first);
      expect(find.text('🔒 This point is locked'), findsOneWidget);
      expect(find.textContaining('point 2'), findsOneWidget);

      await _tap(tester, find.text('UNLOCK ANYWAY'));

      expect(taps.unlocked, (1, 2));
      expect(taps.selected, (1, 2));
    },
  );

  testWidgets('cancelling the confirm leaves the future point locked', (
    tester,
  ) async {
    final taps = await _pump(tester, stages: [_current()]);

    await _tap(tester, find.byIcon(Icons.lock).first);
    await _tap(tester, find.text('CANCEL'));

    expect(taps.selected, isNull);
    expect(taps.unlocked, isNull);
  });

  testWidgets('a locked review node can be unlocked ahead too', (tester) async {
    final taps = await _pump(tester, stages: [_current()]);

    await _tap(tester, find.byIcon(Icons.lock).last);
    expect(find.text('🔒 Review is locked'), findsOneWidget);

    await _tap(tester, find.text('UNLOCK ANYWAY'));

    expect(taps.unlocked, (1, reviewNodeIndex));
    expect(taps.selected, (1, reviewNodeIndex));
  });

  testWidgets('a point the user already unlocked opens without a prompt', (
    tester,
  ) async {
    final taps = await _pump(
      tester,
      stages: [
        _current(unlocked: {2}),
      ],
    );

    await _tap(tester, find.byIcon(Icons.play_arrow));

    expect(find.text('UNLOCK ANYWAY'), findsNothing);
    expect(taps.selected, (1, 2));
  });

  testWidgets(
    'title, date and stars appear once per lesson, not once per point',
    (tester) async {
      await _pump(tester, stages: [_current(spellDate: '七月十四日')]);

      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('七月十四日'), findsOneWidget);
    },
  );

  testWidgets('the current lesson keeps its label bright', (tester) async {
    await _pump(
      tester,
      stages: [
        _current(passed: [false, false, false], stars: 2),
      ],
    );

    final titleStyle = tester.widget<Text>(find.text('Week 1')).style!;
    expect(titleStyle.color, DuolingoColors.darkText);
    expect(titleStyle.fontWeight, FontWeight.bold);

    final stars = tester.widgetList<Text>(find.text('⭐')).toList();
    expect(stars, hasLength(2));
    for (final star in stars) {
      expect(star.style?.color, isNot(Colors.grey));
    }
  });

  testWidgets('a locked lesson shows a dimmed label and no progress ring', (
    tester,
  ) async {
    await _pump(tester);

    final title = tester.widget<Text>(find.text('Stage 2')).style!;
    expect(title.color, DuolingoColors.bodyText.withOpacity(0.5));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

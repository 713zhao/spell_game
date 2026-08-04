import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/journey_path.dart';

List<StageData> _stages() => [
      StageData(stageNumber: 1, title: 'Stage 1', progress: 1.0, stars: 3, isLocked: false),
      StageData(stageNumber: 2, title: 'Stage 2', progress: 0.0, stars: 0, isLocked: true),
    ];

Future<void> _pump(
  WidgetTester tester,
  void Function(int) onSelect, {
  bool allowSkipLock = true,
  List<StageData>? stages,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: JourneyPath(
          stages: stages ?? _stages(),
          kingdomEmoji: '🏰',
          kingdomLabel: 'Castle',
          gradientColors: const [Color(0xFFE6F5FF), Color(0xFFCCE6FF)],
          allowSkipLock: allowSkipLock,
          onSelectLesson: onSelect,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('tapping a completed lesson node calls onSelectLesson',
      (tester) async {
    int? selected;
    await _pump(tester, (n) => selected = n);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(selected, 1);
  });

  testWidgets(
      'tapping a locked node with allowSkipLock true offers Unlock Anyway',
      (tester) async {
    int? selected;
    await _pump(tester, (n) => selected = n, allowSkipLock: true);

    await tester.tap(find.byIcon(Icons.lock));
    // NOTE: don't use pumpAndSettle() here — JourneyPath's pulse
    // AnimationController repeats indefinitely (for the "current" node glow)
    // even when unused by this test's stages, so pumpAndSettle would never
    // detect settling and would time out. Pump a bounded duration instead,
    // long enough for the dialog's open transition to finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('UNLOCK ANYWAY'), findsOneWidget);

    await tester.tap(find.text('UNLOCK ANYWAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, 2);
  });

  testWidgets(
      'tapping a locked node with allowSkipLock false has no skip option',
      (tester) async {
    int? selected;
    await _pump(tester, (n) => selected = n, allowSkipLock: false);

    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('UNLOCK ANYWAY'), findsNothing);
    expect(find.text('OK'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, isNull);
  });

  testWidgets(
      'a multi-checkpoint lesson renders one node per checkpoint with distinct states',
      (tester) async {
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Week 1',
        progress: 0.4,
        stars: 1,
        isLocked: false,
        checkpointIndex: 1,
        checkpointCount: 3,
      ),
    ];
    await _pump(tester, (_) {}, stages: stages);

    // checkpoint 0 done (check), checkpoint 1 current (fire), checkpoint 2
    // not yet reached (lock) - three distinct full-size nodes, not one node
    // with a caption.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets(
      'tapping a not-yet-reached checkpoint shows a hint instead of navigating',
      (tester) async {
    int? selected;
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Week 1',
        progress: 0.4,
        stars: 1,
        isLocked: false,
        checkpointIndex: 1,
        checkpointCount: 3,
      ),
    ];
    await _pump(tester, (n) => selected = n, stages: stages);

    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();

    expect(find.text('Clear checkpoint 2 first!'), findsOneWidget);
    expect(selected, isNull);
  });

  testWidgets(
      'tapping a checkpoint node in a fully locked lesson still offers Unlock Anyway',
      (tester) async {
    int? selected;
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Week 1',
        progress: 0.0,
        stars: 0,
        isLocked: true,
        checkpointIndex: 1,
        checkpointCount: 3,
      ),
    ];
    await _pump(tester, (n) => selected = n, stages: stages);

    // All three checkpoint nodes render locked; tapping any of them is a
    // whole-lesson lock, not a "checkpoint not reached" hint.
    expect(find.byIcon(Icons.lock), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.lock).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('UNLOCK ANYWAY'), findsOneWidget);
    expect(find.textContaining('Clear checkpoint'), findsNothing);

    await tester.tap(find.text('UNLOCK ANYWAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, 1);
  });

  testWidgets(
      'title, date, and star row appear once per lesson, not once per checkpoint',
      (tester) async {
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Week 1',
        progress: 0.4,
        stars: 1,
        isLocked: false,
        spellDate: '七月十四日',
        checkpointIndex: 1,
        checkpointCount: 3,
      ),
    ];
    await _pump(tester, (_) {}, stages: stages);

    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text('七月十四日'), findsOneWidget);
  });
}

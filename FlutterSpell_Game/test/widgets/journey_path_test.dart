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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: JourneyPath(
          stages: _stages(),
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

  testWidgets('a partially-mastered current node shows a progress ring matching its progress',
      (tester) async {
    final stages = [
      StageData(stageNumber: 1, title: 'Stage 1', progress: 0.6, stars: 1, isLocked: false),
      StageData(stageNumber: 2, title: 'Stage 2', progress: 0.0, stars: 0, isLocked: true),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyPath(
            stages: stages,
            kingdomEmoji: '🏰',
            kingdomLabel: 'Castle',
            gradientColors: const [Color(0xFFE6F5FF), Color(0xFFCCE6FF)],
            allowSkipLock: true,
            onSelectLesson: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 0.6);
  });

  testWidgets('a locked node shows no progress ring', (tester) async {
    final stages = [
      StageData(stageNumber: 1, title: 'Stage 1', progress: 1.0, stars: 3, isLocked: false),
      StageData(stageNumber: 2, title: 'Stage 2', progress: 0.0, stars: 0, isLocked: true),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyPath(
            stages: stages,
            kingdomEmoji: '🏰',
            kingdomLabel: 'Castle',
            gradientColors: const [Color(0xFFE6F5FF), Color(0xFFCCE6FF)],
            allowSkipLock: true,
            onSelectLesson: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Only the completed node (stage 1) should have a ring; the locked
    // node (stage 2) must not.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

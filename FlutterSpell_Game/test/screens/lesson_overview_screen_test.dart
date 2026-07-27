import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/main.dart' show gameProvider;
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/screens/lesson_overview_screen.dart';

LessonSummary _lesson({required double masteryPct, required int wordCount}) {
  return LessonSummary(
    lessonKey: 'Week1',
    displayName: 'Week 1',
    labelType: 'TEACHER',
    tags: const ['T::P1::EN::Week1'],
    skills: const [],
    wordCount: wordCount,
    masteryPct: masteryPct,
    stars: masteryPct >= 1.0 ? 3 : (masteryPct >= 0.5 ? 2 : (masteryPct > 0 ? 1 : 0)),
    status: masteryPct >= 1.0 ? 'completed' : 'current',
  );
}

Widget _screen(LessonSummary lesson) {
  // AccountAvatarButton (in the app bar) reads GameProvider via
  // context.watch<GameProvider>() - a separate lookup mechanism from the
  // global `gameProvider` singleton the screen itself reads directly. So
  // this still needs a real Provider ancestor wrapping the same singleton,
  // or AccountAvatarButton throws ProviderNotFoundException during build.
  return ChangeNotifierProvider<GameProvider>.value(
    value: gameProvider,
    child: MaterialApp(
      home: LessonOverviewScreen(
        args: LessonOverviewArgs(lesson: lesson, subject: 'EN'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // lesson_overview_screen.dart reads the global `gameProvider` singleton
    // directly rather than via Provider injection - reset its consumed
    // fields before each test so state doesn't leak between tests.
    gameProvider.deckCards = [];
    gameProvider.errorMessage = null;
  });

  testWidgets('shows the mastery percentage and the 100% unlock hint',
      (tester) async {
    // The default 800x600 test surface is too short for this screen's full
    // column of cards (stage header + info row + mastery + rewards +
    // button) and triggers spurious RenderFlex overflow exceptions that
    // fail the test even when the actual assertions below would pass. Use
    // a taller surface, matching the pattern in profile_screen_test.dart.
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(_screen(_lesson(masteryPct: 0.73, wordCount: 12)));
    await tester.pump();

    expect(find.textContaining('73%'), findsOneWidget);
    expect(find.textContaining('100%'), findsOneWidget);
  });

  testWidgets('tapping the info icon explains the reset rule', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(_screen(_lesson(masteryPct: 0.5, wordCount: 4)));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('a mistake resets that word to 0'),
      findsOneWidget,
    );
  });
}

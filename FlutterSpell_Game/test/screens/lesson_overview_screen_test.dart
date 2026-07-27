import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/main.dart' show gameProvider;
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/screens/lesson_overview_screen.dart';

/// Reads the background color of the nearest chip [Container] wrapping the
/// given word text - used to lock down _masteryChipColor's tier mapping
/// without depending on _MasteryChip, which is private to
/// lesson_overview_screen.dart's library.
Color _chipColorFor(WidgetTester tester, String word) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(word), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration).color!;
}

LessonSummary _lesson({required double masteryPct, required int wordCount}) {
  return LessonSummary(
    lessonKey: 'Week1',
    displayName: 'Week 1',
    labelType: 'TEACHER',
    tags: const ['T::P1::EN::Week1'],
    skills: const [],
    wordCount: wordCount,
    masteryPct: masteryPct,
    stars: masteryPct >= 1.0
        ? 3
        : (masteryPct >= 0.5 ? 2 : (masteryPct > 0 ? 1 : 0)),
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
    gameProvider.isLoggedIn = false;
  });

  testWidgets('shows the mastery percentage and the 100% unlock hint', (
    tester,
  ) async {
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

  testWidgets(
    'word detail is hidden until expanded, then shows mastery-colored chips',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_screen(_lesson(masteryPct: 0.4, wordCount: 3)));
      await tester.pump();

      // GameProvider.loadDeck (called from initState) now synchronously
      // clears deckCards before its awaited network fetch, so a fresh deck
      // must be seeded (and listeners notified to trigger a rebuild) after
      // the screen has mounted, not before pumpWidget - otherwise the
      // screen's own mount-time loadDeck call would immediately wipe it.
      gameProvider.deckCards = [
        DeckCard(
          word: Word(id: 1, text: 'apple', language: 'english'),
          repetitions: 5,
          status: 'review',
        ),
        DeckCard(
          word: Word(id: 2, text: 'banana', language: 'english'),
          repetitions: 2,
          status: 'learning',
        ),
        DeckCard(
          word: Word(id: 3, text: 'cherry', language: 'english'),
          repetitions: 0,
          status: 'new',
        ),
      ];
      gameProvider.notifyListeners();
      await tester.pump();

      expect(find.text('apple'), findsNothing);

      await tester.tap(find.textContaining('word-by-word'));
      await tester.pump();

      expect(find.text('apple'), findsOneWidget);
      expect(find.text('banana'), findsOneWidget);
      expect(find.text('cherry'), findsOneWidget);

      // Lock down the mastery-tier -> chip-color mapping so a future
      // off-by-one in _masteryChipColor's thresholds fails a test, not just
      // a visual review. apple=5 reps (mastered), banana=2 reps (in
      // progress), cherry=0 reps (not started).
      expect(_chipColorFor(tester, 'apple'), DuolingoColors.primaryGreen);
      expect(_chipColorFor(tester, 'banana'), DuolingoColors.rewardYellow);
      expect(
        _chipColorFor(tester, 'cherry'),
        DuolingoColors.secondaryButtonGray,
      );
    },
  );

  testWidgets('collapsing word detail hides the chips again', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(_screen(_lesson(masteryPct: 1.0, wordCount: 1)));
    await tester.pump();

    // See the note in the previous test: seed deckCards after mount so the
    // screen's own loadDeck call (which now clears deckCards eagerly)
    // doesn't wipe it out first.
    gameProvider.deckCards = [
      DeckCard(
        word: Word(id: 1, text: 'apple', language: 'english'),
        repetitions: 5,
        status: 'review',
      ),
    ];
    gameProvider.notifyListeners();
    await tester.pump();

    await tester.tap(find.textContaining('word-by-word'));
    await tester.pump();
    expect(find.text('apple'), findsOneWidget);

    await tester.tap(find.textContaining('word-by-word'));
    await tester.pump();
    expect(find.text('apple'), findsNothing);
  });

  testWidgets(
    "shows an error message when the deck fetch failed instead of chips",
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_screen(_lesson(masteryPct: 0.4, wordCount: 3)));
      await tester.pump();

      // Simulate loadDeck's fetch failing: deckCards stays empty (its catch
      // branch never touches deckCards) but errorMessage is set. The grid
      // should distinguish this from "still loading" and say so instead of
      // showing "Loading word details..." forever.
      gameProvider.errorMessage = 'Network error';
      gameProvider.notifyListeners();
      await tester.pump();

      await tester.tap(find.textContaining('word-by-word'));
      await tester.pump();

      expect(find.textContaining("Couldn't load word details"), findsOneWidget);
      expect(find.textContaining('Loading word details'), findsNothing);
    },
  );
}

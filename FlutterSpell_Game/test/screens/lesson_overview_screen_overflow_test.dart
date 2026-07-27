import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/main.dart' show gameProvider;
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/screens/lesson_overview_screen.dart';

// Throwaway empirical regression check for the small-screen overflow fix in
// commit 8b9a2c1. Independently re-measures the Start Adventure button's
// render box at small device sizes to confirm it is fully on-screen and that
// no overflow exception is thrown during layout - written fresh rather than
// trusting the implementer's own reported numbers.
LessonSummary _lesson() {
  return LessonSummary(
    lessonKey: 'Week1',
    displayName: 'Week 1',
    labelType: 'TEACHER',
    tags: const ['T::P1::EN::Week1'],
    skills: const [],
    wordCount: 12,
    masteryPct: 0.73,
    stars: 2,
    status: 'current',
  );
}

Widget _screen() {
  return ChangeNotifierProvider<GameProvider>.value(
    value: gameProvider,
    child: MaterialApp(
      home: LessonOverviewScreen(
        args: LessonOverviewArgs(lesson: _lesson(), subject: 'EN'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    gameProvider.deckCards = [];
    gameProvider.errorMessage = null;
    gameProvider.isLoggedIn = false;
  });

  for (final size in [
    const Size(375, 667), // iPhone SE
    const Size(360, 640), // small Android
    const Size(360, 740), // previously-fine size class
  ]) {
    testWidgets(
      'Start Adventure button stays within screen bounds at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        addTearDown(tester.view.reset);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(_screen());
        await tester.pump();

        // A pre-existing, out-of-scope horizontal overflow in the Rewards
        // row (3 chips too wide at ~360dp width) fires here independently of
        // the vertical layout under test - tolerate *that* specific error,
        // but fail on anything else (in particular any vertical/"bottom"
        // RenderFlex overflow, which is what this fix targets).
        final exception = tester.takeException();
        if (exception != null) {
          expect(
            exception.toString(),
            allOf(contains('RenderFlex overflowed'), contains('right')),
            reason:
                'Unexpected exception (expected none, or only the known '
                'pre-existing horizontal Rewards-row overflow): $exception',
          );
        }

        final buttonFinder = find.text('START ADVENTURE  🚀');
        expect(buttonFinder, findsOneWidget);

        final rect = tester.getRect(buttonFinder);
        // Report the actual measured numbers for visibility in test output.
        // ignore: avoid_print
        print(
          '[${size.width.toInt()}x${size.height.toInt()}] '
          'Start button rect: top=${rect.top.toStringAsFixed(1)} '
          'bottom=${rect.bottom.toStringAsFixed(1)} / screen height=${size.height}',
        );

        expect(
          rect.bottom,
          lessThanOrEqualTo(size.height),
          reason:
              'Start Adventure button bottom edge (${rect.bottom}) exceeds '
              'screen height (${size.height}) at $size',
        );
        expect(
          rect.top,
          greaterThanOrEqualTo(0),
          reason: 'Start Adventure button top edge is off the top of the screen',
        );
      },
    );
  }
}

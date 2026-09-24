import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/moe_word_models.dart';
import 'package:spell_game/widgets/moe_flip_card.dart';

void main() {
  final character = MoeCharacter(
    id: 1,
    text: '人',
    pinyin: 'rén',
    meaning: 'person',
    writeRequired: true,
    practicedCount: 3,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    VoidCallback? onPlayAudio,
    VoidCallback? onPracticeWriting,
    bool isDifficult = false,
    VoidCallback? onToggleDifficult,
    bool showRatingButtons = false,
    void Function(int quality)? onRate,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoeFlipCard(
            character: character,
            onPlayAudio: onPlayAudio,
            onPracticeWriting: onPracticeWriting,
            isDifficult: isDifficult,
            onToggleDifficult: onToggleDifficult,
            showRatingButtons: showRatingButtons,
            onRate: onRate,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the character on the front, not the back details', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.text('人'), findsOneWidget);
    expect(find.text('rén'), findsNothing);
    expect(find.text('person'), findsNothing);
    expect(find.text('Practiced 3 times'), findsNothing);
  });

  testWidgets('tapping the card flips it to reveal pinyin/meaning/badge', (
    tester,
  ) async {
    await pumpCard(tester);

    await tester.tap(find.byType(MoeFlipCard));
    await tester.pumpAndSettle();

    expect(find.text('rén'), findsOneWidget);
    expect(find.text('person'), findsOneWidget);
    expect(find.text('Practiced 3 times'), findsOneWidget);
    expect(find.text('Practice writing ✍️'), findsOneWidget);
  });

  testWidgets('tapping again flips back to the front', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.byType(MoeFlipCard));
    await tester.pumpAndSettle();
    expect(find.text('rén'), findsOneWidget);

    await tester.tap(find.byType(MoeFlipCard));
    await tester.pumpAndSettle();
    expect(find.text('rén'), findsNothing);
  });

  testWidgets('the audio button on the front triggers onPlayAudio', (
    tester,
  ) async {
    var played = 0;
    await pumpCard(tester, onPlayAudio: () => played++);

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();

    expect(played, 1);
  });

  testWidgets('the practice writing button on the back triggers callback', (
    tester,
  ) async {
    var practiced = 0;
    await pumpCard(tester, onPracticeWriting: () => practiced++);

    await tester.tap(find.byType(MoeFlipCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice writing ✍️'));
    await tester.pump();

    expect(practiced, 1);
  });

  testWidgets(
    'shows an outline star when not difficult, filled when difficult',
    (tester) async {
      await pumpCard(tester, isDifficult: false);
      expect(find.text('☆'), findsOneWidget);
      expect(find.text('⭐'), findsNothing);

      await pumpCard(tester, isDifficult: true);
      expect(find.text('⭐'), findsOneWidget);
      expect(find.text('☆'), findsNothing);
    },
  );

  testWidgets(
    'tapping the star triggers onToggleDifficult without flipping the card',
    (tester) async {
      var toggled = 0;
      await pumpCard(tester, onToggleDifficult: () => toggled++);

      await tester.tap(find.text('☆'));
      await tester.pump();

      expect(toggled, 1);
      // The card should still be showing the front (not flipped).
      expect(find.text('人'), findsOneWidget);
      expect(find.text('rén'), findsNothing);
    },
  );

  testWidgets(
    'rating buttons are hidden by default (browse mode)',
    (tester) async {
      await pumpCard(tester);

      await tester.tap(find.byType(MoeFlipCard));
      await tester.pumpAndSettle();

      expect(find.text('Again'), findsNothing);
      expect(find.text('Hard'), findsNothing);
      expect(find.text('Easy'), findsNothing);
    },
  );

  testWidgets(
    'rating buttons render on the back when showRatingButtons is true',
    (tester) async {
      await pumpCard(tester, showRatingButtons: true, onRate: (_) {});

      await tester.tap(find.byType(MoeFlipCard));
      await tester.pumpAndSettle();

      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping each rating button fires onRate with the correct SM-2 quality',
    (tester) async {
      final qualities = <int>[];
      await pumpCard(
        tester,
        showRatingButtons: true,
        onRate: (q) => qualities.add(q),
      );

      await tester.tap(find.byType(MoeFlipCard));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Again'));
      await tester.tap(find.text('Hard'));
      await tester.tap(find.text('Easy'));
      await tester.pump();

      expect(qualities, [0, 3, 5]);
    },
  );
}

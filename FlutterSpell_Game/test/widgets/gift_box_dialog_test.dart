import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/utils/handwriting_gift.dart';
import 'package:spell_game/widgets/gift_box_dialog.dart';

void main() {
  const gift = HandwriteGift(
    emoji: '💎',
    label: 'Rare gem!',
    coins: 15,
    xp: 10,
  );

  Future<void> openDialog(WidgetTester tester, VoidCallback onClaim) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => GiftBoxDialog(gift: gift, onClaim: onClaim),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
  }

  testWidgets('shows a closed box until tapped, then the reward', (
    tester,
  ) async {
    await openDialog(tester, () {});
    expect(find.text('🎁'), findsOneWidget);
    expect(find.text('Tap to open!'), findsOneWidget);
    expect(find.text('AWESOME!'), findsNothing);

    await tester.tap(find.text('🎁'));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('💎'), findsOneWidget);
    expect(find.text('+15 💰'), findsOneWidget);
    expect(find.text('+10 ⚡ XP'), findsOneWidget);
    expect(find.text('AWESOME!'), findsOneWidget);
    // Let the coin-burst overlay finish so no timers are left pending.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('AWESOME closes the dialog and reports the claim', (
    tester,
  ) async {
    var claimed = 0;
    await openDialog(tester, () => claimed++);
    await tester.tap(find.text('🎁'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('AWESOME!'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(claimed, 1);
    expect(find.byType(GiftBoxDialog), findsNothing);
  });
}

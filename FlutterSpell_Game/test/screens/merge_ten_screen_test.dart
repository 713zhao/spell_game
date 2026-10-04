import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/screens/merge_ten_screen.dart';
import 'package:spell_game/providers/game_provider.dart';

class _StubProvider extends ChangeNotifier implements GameProvider {
  @override
  bool get playtimeLocked => false;
  @override
  Future<void> loadPlaytimeStatus() async {}
  @override
  Future<bool> sendPlaytimeHeartbeat(int seconds) async => false;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('move left then drop lands a tile', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => _StubProvider(),
        child: const MaterialApp(home: MergeTenScreen()),
      ),
    );
    expect(find.text('Merge Ten'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.arrow_left));
      await tester.pump();
      await tester.tap(find.text('Drop'));
      // Fall animation plus match/gravity waves must finish on their own.
      await tester.pump(const Duration(seconds: 10));
    }
    expect(find.text('Score'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

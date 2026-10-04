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
  testWidgets('tapping a column drops a tile', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => _StubProvider(),
        child: const MaterialApp(home: MergeTenScreen()),
      ),
    );
    expect(find.text('Merge Ten'), findsOneWidget);
    final before = find.byType(FittedBox).evaluate().length;
    await tester.tapAt(tester.getTopLeft(find.byType(AspectRatio)) + const Offset(20, 50));
    await tester.pump();
    expect(find.byType(FittedBox).evaluate().length, greaterThan(before));
    await tester.pump(const Duration(seconds: 3));
  });
}

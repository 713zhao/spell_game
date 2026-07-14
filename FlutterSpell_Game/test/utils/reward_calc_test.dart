import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/utils/reward_calc.dart';

void main() {
  test('scales xp and coins with word count', () {
    final rewards = computeLessonRewards(20);
    expect(rewards.xp, 200);
    expect(rewards.coins, 40);
  });

  test('zero words gives zero rewards', () {
    final rewards = computeLessonRewards(0);
    expect(rewards.xp, 0);
    expect(rewards.coins, 0);
  });
}

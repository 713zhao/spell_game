import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/data/chinese_stages.dart';

void main() {
  test('builds 30 stages titled by group nickname', () {
    final stages = buildChineseStages();

    expect(stages.length, 30);
    expect(stages.first.title, 'Forest 1');
    expect(stages[9].title, 'Forest 10');
    expect(stages[10].title, 'River 1');
    expect(stages[19].title, 'River 10');
    expect(stages[20].title, 'Mountain 1');
    expect(stages.last.title, 'Mountain 10');
  });

  test('first 7 stages completed, 8-10 unlocked in progress, 11+ locked', () {
    final stages = buildChineseStages();

    expect(stages[6].progress, 1.0); // stage 7
    expect(stages[6].isLocked, isFalse);
    expect(stages[7].isLocked, isFalse); // stage 8, current
    expect(stages[7].progress, 0.0);
    expect(stages[9].isLocked, isFalse); // stage 10, available
    expect(stages[10].isLocked, isTrue); // stage 11, locked
  });

  test('stars are earned only for completed stages', () {
    final stages = buildChineseStages();

    expect(stages[6].stars, 3); // stage 7, completed
    expect(stages[7].stars, 0); // stage 8, not started
  });
}

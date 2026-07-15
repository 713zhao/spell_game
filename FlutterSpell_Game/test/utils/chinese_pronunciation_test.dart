import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/utils/chinese_pronunciation.dart';

void main() {
  group('rateChineseReading', () {
    test('exact character match scores 3 stars', () {
      expect(rateChineseReading('是', '是'), 3);
    });

    test('a homophone (same pinyin and tone) scores 3 stars', () {
      // 是 and 事 are both "shi4".
      expect(rateChineseReading('是', '事'), 3);
    });

    test('same base sound but different tone scores 2 stars', () {
      // 是 is "shi4", 十 is "shi2" - same pinyin, different tone.
      expect(rateChineseReading('是', '十'), 2);
    });

    test('a completely different sound scores 1 star', () {
      // 是 is "shi4", 我 is "wo3" - no overlap at all.
      expect(rateChineseReading('是', '我'), 1);
    });

    test('null transcript scores 1 star', () {
      expect(rateChineseReading('是', null), 1);
    });

    test('empty transcript scores 1 star', () {
      expect(rateChineseReading('是', '   '), 1);
    });

    test('picks the best tier across a multi-character transcript', () {
      // '我事' contains 我 (no match) and 事 (homophone) - best tier wins.
      expect(rateChineseReading('是', '我事'), 3);
    });
  });
}

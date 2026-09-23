import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/utils/handwriting_gift.dart';
import 'package:spell_game/utils/handwriting_plan.dart';

void main() {
  group('cjkChars', () {
    test('drops punctuation, latin letters and spaces', () {
      expect(cjkChars('我们必须，靠自己。'), ['我', '们', '必', '须', '靠', '自', '己']);
      expect(cjkChars('娃娃(Wa wa)'), ['娃', '娃']);
    });
  });

  group('pickKeyChars', () {
    test('a short word is handwritten in full', () {
      expect(pickKeyChars(cjkChars('螃蟹米粉'), {}), ['螃', '蟹', '米', '粉']);
    });

    test('a sentence keeps the most-stroke characters in sentence order', () {
      final chars = cjkChars('我们必须靠自己的力量捍卫新加坡');
      final picked = pickKeyChars(chars, {
        '我': 7,
        '们': 5,
        '必': 5,
        '须': 9,
        '靠': 15,
        '自': 6,
        '己': 3,
        '的': 8,
        '力': 2,
        '量': 12,
        '捍': 10,
        '卫': 3,
        '新': 13,
        '加': 5,
        '坡': 8,
      });
      expect(picked, ['靠', '量', '新']);
    });

    test('a repeated character is only asked once', () {
      final picked = pickKeyChars(cjkChars('大大大大大小小'), {'大': 3, '小': 3});
      expect(picked, ['大', '小']);
    });

    test('with no stroke data the first characters are used', () {
      expect(pickKeyChars(cjkChars('我们必须靠自己'), {}), ['我', '们', '必']);
    });
  });

  group('typedMatchesTarget', () {
    test('ignores punctuation and spacing', () {
      expect(typedMatchesTarget('他爱看书 却不爱写字', '他爱看书,却不爱写字。'), isTrue);
    });

    test('rejects a wrong or missing character', () {
      expect(typedMatchesTarget('他爱看书却不爱写', '他爱看书,却不爱写字。'), isFalse);
      expect(typedMatchesTarget('', '他爱看书'), isFalse);
    });
  });

  group('handwrite gift', () {
    test('is due after every successful handwriting, never at zero', () {
      expect(handwriteGiftDue(0), isFalse);
      expect([
        for (var i = 1; i <= 4; i++) handwriteGiftDue(i),
      ], everyElement(isTrue));
    });

    test('every roll pays out something', () {
      final random = Random(1);
      for (var i = 0; i < 200; i++) {
        final gift = rollHandwriteGift(random);
        expect(gift.coins + gift.xp, greaterThan(0));
      }
    });
  });
}

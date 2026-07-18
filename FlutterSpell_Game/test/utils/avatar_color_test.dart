import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/utils/avatar_color.dart';

void main() {
  group('avatarColorFor', () {
    test('the same name always returns the same color', () {
      expect(avatarColorFor('ERIC'), avatarColorFor('ERIC'));
    });

    test('different names can return different colors', () {
      // Not guaranteed for every possible pair, but true for this one -
      // if the palette or hash algorithm ever changes, pick a new pair
      // that differs.
      expect(avatarColorFor('ERIC') == avatarColorFor('HELLEN'), isFalse);
    });

    test('is case-insensitive - the same name in different case matches',
        () {
      expect(avatarColorFor('eric'), avatarColorFor('ERIC'));
    });

    test('an empty name does not throw', () {
      expect(() => avatarColorFor(''), returnsNormally);
    });
  });
}

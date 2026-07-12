import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/design_system/shadows.dart';

void main() {
  test('DuolingoShadows has all shadow definitions', () {
    expect(DuolingoShadows.cardShadow, isNotNull);
    expect(DuolingoShadows.cardShadow.length, equals(1));
    expect(DuolingoShadows.cardHoverShadow, isNotNull);
    expect(DuolingoShadows.cardHoverShadow.length, equals(1));
    expect(DuolingoShadows.primaryButtonShadow, isNotNull);
    expect(DuolingoShadows.primaryButtonShadow.length, equals(1));
  });
}

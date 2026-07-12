import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/design_system/spacing.dart';

void main() {
  test('DuolingoSpacing has all constants', () {
    expect(DuolingoSpacing.xs, equals(4));
    expect(DuolingoSpacing.sm, equals(8));
    expect(DuolingoSpacing.md, equals(12));
    expect(DuolingoSpacing.lg, equals(16));
    expect(DuolingoSpacing.xl, equals(20));
    expect(DuolingoSpacing.xxl, equals(24));
    expect(DuolingoSpacing.radiusButton, equals(16));
    expect(DuolingoSpacing.radiusCard, equals(20));
    expect(DuolingoSpacing.radiusDialog, equals(24));
    expect(DuolingoSpacing.radiusAvatar, equals(30));
    expect(DuolingoSpacing.minTouchTarget, greaterThanOrEqualTo(48));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/design_system/colors.dart';

void main() {
  test('DuolingoColors has all required colors', () {
    expect(DuolingoColors.primaryGreen, isNotNull);
    expect(DuolingoColors.streakOrange, isNotNull);
    expect(DuolingoColors.rewardYellow, isNotNull);
    expect(DuolingoColors.informationBlue, isNotNull);
    expect(DuolingoColors.mistakeRed, isNotNull);
    expect(DuolingoColors.specialPurple, isNotNull);
    expect(DuolingoColors.primaryGreen.value, equals(0xFF58CC02));
  });
}

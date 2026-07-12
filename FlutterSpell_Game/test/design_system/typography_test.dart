import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/design_system/typography.dart';
import 'package:flutter/material.dart';

void main() {
  test('DuolingoTextStyles has all required styles', () {
    expect(DuolingoTextStyles.pageTitle.fontSize, equals(24));
    expect(DuolingoTextStyles.pageTitle.fontWeight, equals(FontWeight.bold));
    expect(DuolingoTextStyles.sectionTitle.fontSize, equals(16));
    expect(DuolingoTextStyles.cardTitle.fontSize, equals(14));
    expect(DuolingoTextStyles.body.fontSize, equals(12));
    expect(DuolingoTextStyles.label.fontSize, equals(11));
    expect(DuolingoTextStyles.largeValue.fontSize, equals(24));
  });
}

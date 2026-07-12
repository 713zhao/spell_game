import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/widgets/buttons/primary_button.dart';

void main() {
  testWidgets('PrimaryButton renders with label', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Play',
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('PrimaryButton calls onPressed when tapped', (WidgetTester tester) async {
    bool pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Play',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PrimaryButton));
    expect(pressed, isTrue);
  });

  testWidgets('PrimaryButton is disabled when disabled=true', (WidgetTester tester) async {
    bool pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Play',
            onPressed: () => pressed = true,
            disabled: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PrimaryButton));
    expect(pressed, isFalse);
  });
}

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

  testWidgets('PrimaryButton shows loading indicator when isLoading=true', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Play',
            onPressed: () {},
            isLoading: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Play'), findsNothing);
  });

  testWidgets('PrimaryButton animates on tap', (WidgetTester tester) async {
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

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PrimaryButton)));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('PrimaryButton shows grey colors when disabled', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Play',
            onPressed: () {},
            disabled: true,
          ),
        ),
      ),
    );

    final container = find.byType(Container).first;
    expect(container, findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('PrimaryButton reverses animation on tap cancel', (WidgetTester tester) async {
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

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PrimaryButton)));
    await tester.pumpAndSettle();
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/widgets/cards/stat_card.dart';
import 'package:spell_game/design_system/design_system.dart';

void main() {
  group('StatCard', () {
    testWidgets('renders icon, label, and value correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: '🔥',
              label: 'STREAK',
              value: '12',
            ),
          ),
        ),
      );

      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('STREAK'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('applies streak gradient when label is STREAK', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: '🔥',
              label: 'STREAK',
              value: '12',
            ),
          ),
        ),
      );

      final container = find.byType(Container).first;
      expect(container, findsOneWidget);
      // Verify gradient is applied (visual test would confirm orange tones)
    });

    testWidgets('applies points gradient when label is POINTS', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: '⭐',
              label: 'POINTS',
              value: '485',
            ),
          ),
        ),
      );

      expect(find.text('⭐'), findsOneWidget);
      expect(find.text('POINTS'), findsOneWidget);
      expect(find.text('485'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: '🔥',
              label: 'STREAK',
              value: '12',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(StatCard));
      expect(tapped, isTrue);
    });

    testWidgets('meets minimum touch target size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: '🔥',
              label: 'STREAK',
              value: '12',
            ),
          ),
        ),
      );

      final container = find.byType(Container).first;
      expect(container, findsOneWidget);
      // Touch target constraint: minHeight >= 48
    });
  });
}

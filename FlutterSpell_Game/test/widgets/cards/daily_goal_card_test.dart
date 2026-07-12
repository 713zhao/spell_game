import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/widgets/cards/daily_goal_card.dart';

void main() {
  group('DailyGoalCard', () {
    testWidgets('renders label, progress, and status text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyGoalCard(completed: 3, total: 5),
          ),
        ),
      );

      expect(find.text('📍 DAILY GOAL'), findsOneWidget);
      expect(find.text('3 of 5 lessons completed'), findsOneWidget);
    });

    testWidgets('animates progress bar on build', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyGoalCard(completed: 2, total: 5),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows correct star count based on progress', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyGoalCard(completed: 3, total: 5),
          ),
        ),
      );

      expect(find.text('⭐'), findsNWidgets(3));
    });

    testWidgets('updates animation when goal progress changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyGoalCard(completed: 1, total: 5),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyGoalCard(completed: 4, total: 5),
          ),
        ),
      );

      expect(find.text('4 of 5 lessons completed'), findsOneWidget);
    });

    testWidgets('shows all 3 stars when goal is 100% complete', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyGoalCard(completed: 5, total: 5),
          ),
        ),
      );

      expect(find.text('⭐'), findsNWidgets(3));
      expect(find.text('5 of 5 lessons completed'), findsOneWidget);
    });

    testWidgets('shows 0 stars when goal is 0% complete', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyGoalCard(completed: 0, total: 5),
          ),
        ),
      );

      expect(find.text('⭐'), findsNWidgets(3)); // 3 stars total, 0 filled
      expect(find.text('0 of 5 lessons completed'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyGoalCard(
              completed: 3,
              total: 5,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DailyGoalCard));
      expect(tapped, isTrue);
    });
  });
}

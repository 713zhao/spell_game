import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/widgets/cards/level_card.dart';

void main() {
  group('LevelCard', () {
    testWidgets('renders all level info', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCard(
              icon: '🔤',
              name: 'Level 1: Vowels',
              difficulty: 'Easy',
              wordCount: 8,
              starsEarned: 2,
            ),
          ),
        ),
      );

      expect(find.text('🔤'), findsOneWidget);
      expect(find.text('Level 1: Vowels'), findsOneWidget);
      expect(find.text('Easy • 8 words'), findsOneWidget);
    });

    testWidgets('shows correct star count', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCard(
              icon: '🔤',
              name: 'Level 1',
              difficulty: 'Easy',
              wordCount: 8,
              starsEarned: 3,
            ),
          ),
        ),
      );

      expect(find.text('⭐'), findsNWidgets(3));
    });

    testWidgets('shows Play button for available levels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCard(
              icon: '🔤',
              name: 'Level 1',
              difficulty: 'Easy',
              wordCount: 8,
              starsEarned: 0,
            ),
          ),
        ),
      );

      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('shows Review button for completed levels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCard(
              icon: '🔤',
              name: 'Level 1',
              difficulty: 'Easy',
              wordCount: 8,
              starsEarned: 3,
              isCompleted: true,
            ),
          ),
        ),
      );

      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('shows Unlock button for locked levels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCard(
              icon: '🔒',
              name: 'Level 4',
              difficulty: 'Medium',
              wordCount: 15,
              starsEarned: 0,
              isLocked: true,
            ),
          ),
        ),
      );

      expect(find.text('Unlock'), findsOneWidget);
    });

    testWidgets('locked level has reduced opacity', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCard(
              icon: '🔒',
              name: 'Level 4',
              difficulty: 'Medium',
              wordCount: 15,
              starsEarned: 0,
              isLocked: true,
            ),
          ),
        ),
      );

      expect(find.byType(Opacity), findsOneWidget);
    });

    testWidgets('calls onPlayTap when Play button tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCard(
              icon: '🔤',
              name: 'Level 1',
              difficulty: 'Easy',
              wordCount: 8,
              starsEarned: 0,
              onPlayTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Play'));
      expect(tapped, isTrue);
    });
  });
}

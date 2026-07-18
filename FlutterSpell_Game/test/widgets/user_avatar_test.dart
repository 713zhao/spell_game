import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/widgets/user_avatar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the uppercase first letter when no cosmetic is set',
      (tester) async {
    await tester.pumpWidget(wrap(const UserAvatar(name: 'eric')));

    expect(find.text('E'), findsOneWidget);
  });

  testWidgets('shows the cosmetic emoji instead of the letter when provided',
      (tester) async {
    await tester.pumpWidget(
      wrap(const UserAvatar(name: 'ERIC', cosmeticEmoji: '🦄')),
    );

    expect(find.text('🦄'), findsOneWidget);
    expect(find.text('E'), findsNothing);
  });

  testWidgets('shows a fallback "?" for an empty name', (tester) async {
    await tester.pumpWidget(wrap(const UserAvatar(name: '')));

    expect(find.text('?'), findsOneWidget);
  });
}

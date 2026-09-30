import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/services/parent_mode.dart';
import 'package:spell_game/widgets/app_bottom_nav.dart';

void main() {
  testWidgets('menu switches immediately when parent mode toggles',
      (tester) async {
    ParentMode.enabled.value = false;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(bottomNavigationBar: AppBottomNav(current: '/profile')),
    ));
    expect(find.text('Backpack'), findsOneWidget);
    expect(find.text('Add Words'), findsNothing);

    ParentMode.enabled.value = true;
    await tester.pump();
    expect(find.text('Add Words'), findsOneWidget);
    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Backpack'), findsNothing);
  });
}

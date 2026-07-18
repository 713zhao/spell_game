import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/screens/signup_screen.dart';
import '../support/fake_game_provider.dart';

void main() {
  Widget wrap(GameProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<GameProvider>.value(
        value: provider,
        child: const SignupScreen(),
      ),
      routes: {
        '/home': (context) => const Scaffold(body: Text('Home Screen')),
      },
    );
  }

  testWidgets('successful signup navigates to /home', (tester) async {
    final provider = FakeGameProvider();
    provider.signupResult = true;

    await tester.pumpWidget(wrap(provider));
    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'NEWKID');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(provider.signupCalled, true);
    expect(provider.lastSignupName, 'NEWKID');
    expect(find.text('Home Screen'), findsOneWidget);
  });

  testWidgets('duplicate username shows inline error and does not navigate',
      (tester) async {
    final provider = FakeGameProvider();
    provider.signupResult = false;

    await tester.pumpWidget(wrap(provider));
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ERIC');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('That username is already taken'), findsOneWidget);
    expect(find.text('Home Screen'), findsNothing);
  });

  testWidgets('empty username shows validation error without calling signup',
      (tester) async {
    final provider = FakeGameProvider();

    await tester.pumpWidget(wrap(provider));
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    expect(find.text('Enter a username'), findsOneWidget);
    expect(provider.signupCalled, false);
  });
}

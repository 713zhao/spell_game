import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/screens/login_screen.dart';
import '../support/fake_game_provider.dart';

void main() {
  Widget wrap(GameProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<GameProvider>.value(
        value: provider,
        child: const LoginScreen(),
      ),
      routes: {
        '/home': (context) => const Scaffold(body: Text('Home Screen')),
        '/signup': (context) => const Scaffold(body: Text('Signup Screen')),
      },
    );
  }

  testWidgets('shows quick-pick chips for recent users', (tester) async {
    final provider = FakeGameProvider();
    provider.recentUsers = ['ERIC', 'HELLEN'];

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    expect(find.text('ERIC'), findsOneWidget);
    expect(find.text('HELLEN'), findsOneWidget);
  });

  testWidgets('manual entry toggle shows username and password fields',
      (tester) async {
    final provider = FakeGameProvider();
    provider.recentUsers = ['ERIC'];

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('Not you? Use a different username'));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
  });

  testWidgets('New here? Sign Up navigates to /signup', (tester) async {
    final provider = FakeGameProvider();

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('New here? Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Signup Screen'), findsOneWidget);
  });

  testWidgets('correct login navigates to /home', (tester) async {
    final provider = FakeGameProvider();
    provider.loginResult = true;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ERIC');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), '123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Home Screen'), findsOneWidget);
  });

  testWidgets('wrong password shows inline error and does not navigate',
      (tester) async {
    final provider = FakeGameProvider();
    provider.loginResult = false;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ERIC');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect username or password'), findsOneWidget);
    expect(find.text('Home Screen'), findsNothing);
  });
}

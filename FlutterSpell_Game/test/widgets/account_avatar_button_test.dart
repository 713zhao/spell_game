import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import '../support/fake_game_provider.dart';

void main() {
  Widget wrap(GameProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<GameProvider>.value(
        value: provider,
        child: Scaffold(
          appBar: AppBar(actions: const [AccountAvatarButton()]),
        ),
      ),
      routes: {
        '/login': (context) => const Scaffold(body: Text('Login Screen')),
        '/profile': (context) => const Scaffold(body: Text('Profile Screen')),
      },
    );
  }

  testWidgets('logged out shows a sign-in icon that opens /login',
      (tester) async {
    final provider = FakeGameProvider();
    provider.isLoggedIn = false;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('Login Screen'), findsOneWidget);
  });

  testWidgets('logged in shows the username initial', (tester) async {
    final provider = FakeGameProvider();
    provider.init('ERIC');
    provider.isLoggedIn = true;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    expect(find.text('E'), findsOneWidget);
  });

  testWidgets(
      'tapping the logged-in avatar shows View Profile and Switch User',
      (tester) async {
    final provider = FakeGameProvider();
    provider.init('ERIC');
    provider.isLoggedIn = true;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('E'));
    await tester.pumpAndSettle();

    expect(find.text('View Profile'), findsOneWidget);
    expect(find.text('Switch User'), findsOneWidget);
  });

  testWidgets('Switch User logs out and navigates to /login', (tester) async {
    final provider = FakeGameProvider();
    provider.init('ERIC');
    provider.isLoggedIn = true;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('E'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch User'));
    await tester.pumpAndSettle();

    expect(provider.loggedOutCalled, true);
    expect(find.text('Login Screen'), findsOneWidget);
  });
}

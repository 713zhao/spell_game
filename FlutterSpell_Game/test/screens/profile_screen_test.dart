import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/screens/profile.dart';
import '../support/fake_game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget(GameProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<GameProvider>.value(
        value: provider,
        child: const ProfileScreen(),
      ),
    );
  }

  group('ProfileScreen Profile Details card', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows em-dashes when profile has not loaded yet',
        (tester) async {
      final provider = FakeGameProvider();
      provider.userProfile = null;

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Profile Details'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(5)); // age, grade, school, email, phone
    });

    testWidgets('shows profile values when loaded', (tester) async {
      final provider = FakeGameProvider();
      provider.userProfile = {
        'age': 6,
        'grade': 'P1',
        'school': 'SJIJ',
        'email': '',
        'phone': '87654321',
      };

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('6'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('SJIJ'), findsOneWidget);
      expect(find.text('87654321'), findsOneWidget);
      expect(find.text('—'), findsOneWidget); // empty email
    });

    testWidgets('loads the profile when the screen opens', (tester) async {
      final provider = FakeGameProvider();

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      expect(provider.loadUserProfileCalled, true);
    });

    testWidgets('Edit is blocked with a message when Parent Mode is off',
        (tester) async {
      SharedPreferences.setMockInitialValues({'parent_mode': false});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Edit'));
      await tester.pump();

      expect(
        find.text('Enable Parent Mode in Settings to edit profile details.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Edit opens the form when Parent Mode is on', (tester) async {
      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Edit'));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Age'), findsOneWidget);
    });
  });
}

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

    testWidgets('Cancel discards changes and returns to read-only view',
        (tester) async {
      // The full edit form (7 fields + password section + buttons) doesn't
      // fit in the default 800x600 test surface, and scrolling interacts
      // awkwardly with the floating SliverAppBar. Use a taller surface so
      // the Cancel button is directly hit-testable without scrolling.
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Age'), '99');
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('6'), findsOneWidget); // original value still shown
      expect(provider.updateProfileCalled, false);
    });

    testWidgets('non-numeric age shows an inline error and does not save',
        (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Age'), 'abc');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Age must be a number'), findsOneWidget);
      expect(provider.updateProfileCalled, false);
    });

    testWidgets('mismatched passwords show an inline error and do not save',
        (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'New Password'), 'abc123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'different');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Passwords must match and not be empty'), findsOneWidget);
      expect(provider.updateProfileCalled, false);
    });

    testWidgets('valid edit saves only non-empty fields and shows success',
        (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1', 'school': '', 'email': '', 'phone': ''};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Age'), '7');
      await tester.enterText(find.widgetWithText(TextField, 'School'), 'SJIJ');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();

      expect(provider.updateProfileCalled, true);
      expect(provider.lastUpdateProfileData, {'age': 7, 'grade': 'P1', 'school': 'SJIJ'});
      expect(find.text('Profile updated successfully!'), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // back to read-only
      expect(find.text('7'), findsOneWidget); // updated value now shown
      expect(find.text('SJIJ'), findsOneWidget);
    });

    testWidgets('failed save keeps the form open and shows an error',
        (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};
      provider.updateProfileResult = false;

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Age'), '7');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TextField), findsWidgets); // still editing
      expect(find.textContaining('Failed to update profile'), findsOneWidget);
      // Entered text isn't rendered as a Text descendant, so check the
      // controller directly rather than find.text/widgetWithText.
      final ageField = tester.widget<TextField>(find.widgetWithText(TextField, 'Age'));
      expect(ageField.controller!.text, '7'); // input preserved
    });
  });
}

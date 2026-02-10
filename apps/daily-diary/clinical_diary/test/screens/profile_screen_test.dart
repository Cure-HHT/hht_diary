// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00076: Participation Status Badge

import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  group('ProfileScreen', () {
    Widget buildProfileScreen({
      bool isEnrolledInTrial = false,
      bool isDisconnected = false,
      String enrollmentStatus = 'none',
      String? enrollmentCode,
      DateTime? enrollmentDateTime,
      String? siteName,
      String? sitePhoneNumber,
    }) {
      return wrapWithMaterialApp(
        ProfileScreen(
          onBack: () {},
          onStartClinicalTrialEnrollment: () {},
          onShowSettings: () {},
          onShareWithCureHHT: () {},
          onStopSharingWithCureHHT: () {},
          isEnrolledInTrial: isEnrolledInTrial,
          isDisconnected: isDisconnected,
          enrollmentStatus: enrollmentStatus,
          isSharingWithCureHHT: false,
          userName: 'Test User',
          onUpdateUserName: (_) {},
          enrollmentCode: enrollmentCode,
          enrollmentDateTime: enrollmentDateTime,
          siteName: siteName,
          sitePhoneNumber: sitePhoneNumber,
        ),
      );
    }

    group('Basic UI', () {
      testWidgets('displays Profile title', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.text('Profile'), findsOneWidget);
      });

      testWidgets('displays back button', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('displays Accessibility & Preferences button', (
        tester,
      ) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.text('Accessibility & Preferences'), findsOneWidget);
      });
    });

    group('Participation Status Badge - Not Participating', () {
      testWidgets('does not show status badge when not enrolled', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildProfileScreen(isEnrolledInTrial: false, isDisconnected: false),
        );
        await tester.pumpAndSettle();

        // Should not show participation status badge elements
        expect(find.text('Active'), findsNothing);
        expect(find.text('Disconnected'), findsNothing);
        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      });

      testWidgets('shows Enroll in Clinical Trial button when not enrolled', (
        tester,
      ) async {
        await tester.pumpWidget(buildProfileScreen(isEnrolledInTrial: false));
        await tester.pumpAndSettle();

        expect(find.text('Enroll in Clinical Trial'), findsOneWidget);
      });
    });

    group('Participation Status Badge - Active', () {
      testWidgets('shows Active status when enrolled and not disconnected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildProfileScreen(
            isEnrolledInTrial: true,
            isDisconnected: false,
            enrollmentStatus: 'active',
            enrollmentCode: 'TEST1234',
            enrollmentDateTime: DateTime(2026, 1, 15),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Active'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('shows active status message when enrolled', (tester) async {
        await tester.pumpWidget(
          buildProfileScreen(
            isEnrolledInTrial: true,
            isDisconnected: false,
            enrollmentStatus: 'active',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('actively participating'), findsOneWidget);
      });

      testWidgets('shows linking code when enrolled', (tester) async {
        await tester.pumpWidget(
          buildProfileScreen(
            isEnrolledInTrial: true,
            isDisconnected: false,
            enrollmentStatus: 'active',
            enrollmentCode: 'TEST1234',
          ),
        );
        await tester.pumpAndSettle();

        // Code is formatted as XXXXX-XXX (dash after 5 chars)
        // The code appears in both status badge and enrollment card
        expect(find.textContaining('TEST1-234'), findsWidgets);
        // Verify the localized "Linking Code:" label is shown
        expect(find.textContaining('Linking Code'), findsOneWidget);
      });

      testWidgets('shows joined date when enrolled', (tester) async {
        await tester.pumpWidget(
          buildProfileScreen(
            isEnrolledInTrial: true,
            isDisconnected: false,
            enrollmentStatus: 'active',
            enrollmentCode: 'TEST1234',
            enrollmentDateTime: DateTime(2026, 1, 15, 10, 30),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Joined'), findsOneWidget);
      });

      testWidgets('does not show Enter New Linking Code button when active', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildProfileScreen(
            isEnrolledInTrial: true,
            isDisconnected: false,
            enrollmentStatus: 'active',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Enter New Linking Code'), findsNothing);
      });
    });

    group('Participation Status Badge - Disconnected', () {
      testWidgets('shows Disconnected status when disconnected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildProfileScreen(
            isEnrolledInTrial: true,
            isDisconnected: true,
            enrollmentStatus: 'active',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Disconnected'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      });

      testWidgets('shows disconnected status message', (tester) async {
        await tester.pumpWidget(
          buildProfileScreen(isEnrolledInTrial: true, isDisconnected: true),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('disconnected'), findsOneWidget);
      });

      testWidgets('shows Enter New Linking Code button when disconnected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildProfileScreen(isEnrolledInTrial: true, isDisconnected: true),
        );
        await tester.pumpAndSettle();

        expect(find.text('Enter New Linking Code'), findsOneWidget);
      });

      testWidgets('shows site contact info when disconnected with site name', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildProfileScreen(
            isEnrolledInTrial: true,
            isDisconnected: true,
            siteName: 'Test Clinic',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Test Clinic'), findsOneWidget);
      });

      testWidgets('Enter New Linking Code button is tappable', (tester) async {
        var buttonTapped = false;

        await tester.pumpWidget(
          wrapWithMaterialApp(
            ProfileScreen(
              onBack: () {},
              onStartClinicalTrialEnrollment: () {
                buttonTapped = true;
              },
              onShowSettings: () {},
              onShareWithCureHHT: () {},
              onStopSharingWithCureHHT: () {},
              isEnrolledInTrial: true,
              isDisconnected: true,
              enrollmentStatus: 'active',
              isSharingWithCureHHT: false,
              userName: 'Test User',
              onUpdateUserName: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Enter New Linking Code'));
        await tester.pumpAndSettle();

        expect(buttonTapped, isTrue);
      });
    });

    group('Navigation', () {
      testWidgets('back button calls onBack', (tester) async {
        var backCalled = false;

        await tester.pumpWidget(
          wrapWithMaterialApp(
            ProfileScreen(
              onBack: () {
                backCalled = true;
              },
              onStartClinicalTrialEnrollment: () {},
              onShowSettings: () {},
              onShareWithCureHHT: () {},
              onStopSharingWithCureHHT: () {},
              isEnrolledInTrial: false,
              isDisconnected: false,
              enrollmentStatus: 'none',
              isSharingWithCureHHT: false,
              userName: 'Test User',
              onUpdateUserName: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(backCalled, isTrue);
      });

      testWidgets('Accessibility & Preferences button calls onShowSettings', (
        tester,
      ) async {
        var settingsCalled = false;

        await tester.pumpWidget(
          wrapWithMaterialApp(
            ProfileScreen(
              onBack: () {},
              onStartClinicalTrialEnrollment: () {},
              onShowSettings: () {
                settingsCalled = true;
              },
              onShareWithCureHHT: () {},
              onStopSharingWithCureHHT: () {},
              isEnrolledInTrial: false,
              isDisconnected: false,
              enrollmentStatus: 'none',
              isSharingWithCureHHT: false,
              userName: 'Test User',
              onUpdateUserName: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Accessibility & Preferences'));
        await tester.pumpAndSettle();

        expect(settingsCalled, isTrue);
      });
    });

    group('Status Badge Styling', () {
      testWidgets('active status has green background', (tester) async {
        await tester.pumpWidget(
          buildProfileScreen(
            isEnrolledInTrial: true,
            isDisconnected: false,
            enrollmentStatus: 'active',
          ),
        );
        await tester.pumpAndSettle();

        // Find the Card widget that contains the status badge
        final cardFinder = find.ancestor(
          of: find.text('Active'),
          matching: find.byType(Card),
        );
        expect(cardFinder, findsOneWidget);

        final card = tester.widget<Card>(cardFinder);
        // Green shade 50 should be used for active state
        expect(card.color, equals(Colors.green.shade50));
      });

      testWidgets('disconnected status has orange background', (tester) async {
        await tester.pumpWidget(
          buildProfileScreen(isEnrolledInTrial: true, isDisconnected: true),
        );
        await tester.pumpAndSettle();

        final cardFinder = find.ancestor(
          of: find.text('Disconnected'),
          matching: find.byType(Card),
        );
        expect(cardFinder, findsOneWidget);

        final card = tester.widget<Card>(cardFinder);
        expect(card.color, equals(Colors.orange.shade50));
      });
    });

    group('Sponsor Icon', () {
      testWidgets('shows sponsor icon placeholder in active state', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildProfileScreen(
            isEnrolledInTrial: true,
            isDisconnected: false,
            enrollmentStatus: 'active',
          ),
        );
        await tester.pumpAndSettle();

        // Science icon is shown in the status badge (may appear multiple times in the tree)
        expect(find.byIcon(Icons.science), findsWidgets);
      });

      testWidgets('shows sponsor icon placeholder in disconnected state', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildProfileScreen(isEnrolledInTrial: true, isDisconnected: true),
        );
        await tester.pumpAndSettle();

        // Science icon is shown in the status badge (may appear multiple times in the tree)
        expect(find.byIcon(Icons.science), findsWidgets);
      });
    });
  });
}

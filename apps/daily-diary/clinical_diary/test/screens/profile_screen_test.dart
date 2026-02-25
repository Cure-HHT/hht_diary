// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00076: Participation Status Badge

import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail_image_network/mocktail_image_network.dart';

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
      String? sponsorLogo,
    }) {
      return wrapWithMaterialApp(
        ProfileScreen(
          onBack: () {},
          onStartClinicalTrialEnrollment: () {},
          onShowSettings: () {},
          sponsorLogo: sponsorLogo,
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

        expect(find.byIcon(Icons.check), findsOneWidget);
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

        expect(find.textContaining("You've joined the study"), findsOneWidget);
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
        await tester.scrollUntilVisible(
          find.text('Enter New Linking Code'),
          300,
        );
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
          of: find.text("You've joined the study"),
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
          of: find.text(
            'You have been disconnected from the clinical trial. Please contact your study site or enter a new linking code.',
          ),
          matching: find.byType(Card),
        );
        expect(cardFinder, findsOneWidget);

        final card = tester.widget<Card>(cardFinder);
        expect(card.color, equals(Colors.orange.shade50));
      });
    });

    group('Sponsor Icon', () {
      testWidgets(
        'shows network sponsor logo when sponsorLogo is provided in active state',
        (tester) async {
          await mockNetworkImages(() async {
            await tester.pumpWidget(
              buildProfileScreen(
                isEnrolledInTrial: true,
                isDisconnected: false,
                sponsorLogo: 'assets/sponsor-content/status_badge.png',
              ),
            );

            await tester.pumpAndSettle();

            expect(find.byType(Image), findsWidgets);

            final image = tester.widget<Image>(find.byType(Image).first);
            expect(image.image, isA<NetworkImage>());
          });
        },
      );

      testWidgets(
        'shows generic sponsor logo when sponsorLogo is null in active state',
        (tester) async {
          await tester.pumpWidget(
            buildProfileScreen(
              isEnrolledInTrial: true,
              isDisconnected: false,
              sponsorLogo: null,
            ),
          );

          await tester.pumpAndSettle();

          final imageFinder = find.byType(Image);
          expect(imageFinder, findsWidgets);

          final image = tester.widget<Image>(imageFinder.first);
          expect(image.image, isA<AssetImage>());

          final assetImage = image.image as AssetImage;
          expect(
            assetImage.assetName,
            'assets/images/generic_company_logo.png',
          );
        },
      );

      testWidgets(
        'shows network sponsor logo when sponsorLogo is provided in disconnected state',
        (tester) async {
          await mockNetworkImages(() async {
            await tester.pumpWidget(
              buildProfileScreen(
                isEnrolledInTrial: true,
                isDisconnected: true,
                sponsorLogo: 'assets/sponsor-content/status_badge.png',
              ),
            );

            await tester.pumpAndSettle();

            expect(find.byType(Image), findsWidgets);

            final image = tester.widget<Image>(find.byType(Image).first);
            expect(image.image, isA<NetworkImage>());
          });
        },
      );

      testWidgets(
        'shows generic sponsor logo when sponsorLogo is null in disconnected state',
        (tester) async {
          await tester.pumpWidget(
            buildProfileScreen(
              isEnrolledInTrial: true,
              isDisconnected: true,
              sponsorLogo: null,
            ),
          );

          await tester.pumpAndSettle();

          final imageFinder = find.byType(Image);
          expect(imageFinder, findsWidgets);

          final image = tester.widget<Image>(imageFinder.first);
          expect(image.image, isA<AssetImage>());

          final assetImage = image.image as AssetImage;
          expect(
            assetImage.assetName,
            'assets/images/generic_company_logo.png',
          );
        },
      );
    });
  });
}

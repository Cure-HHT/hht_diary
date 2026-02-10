// Widgetbook for Clinical Diary App
// Run with: flutter run -t widgetbook/main.dart
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00076: Participation Status Badge

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [
        WidgetbookFolder(
          name: 'Screens',
          children: [
            WidgetbookFolder(
              name: 'Profile',
              children: [
                WidgetbookComponent(
                  name: 'Participation Status Badge',
                  useCases: [
                    WidgetbookUseCase(
                      name: 'Active State',
                      builder: _buildActiveState,
                    ),
                    WidgetbookUseCase(
                      name: 'Disconnected State',
                      builder: _buildDisconnectedState,
                    ),
                    WidgetbookUseCase(
                      name: 'Not Participating',
                      builder: _buildNotParticipatingState,
                    ),
                    WidgetbookUseCase(
                      name: 'Interactive',
                      builder: _buildInteractiveState,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      addons: [
        // Material theme addon for Flutter Material themes
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(
              name: 'Light',
              data: ThemeData.light(useMaterial3: true),
            ),
            WidgetbookTheme(
              name: 'Dark',
              data: ThemeData.dark(useMaterial3: true),
            ),
          ],
        ),
        // Locale addon
        LocalizationAddon(
          locales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
        // Text scale addon for accessibility testing
        TextScaleAddon(min: 1.0, max: 2.0),
      ],
    );
  }
}

// Active state - enrolled and connected
Widget _buildActiveState(BuildContext context) {
  return ProfileScreen(
    onBack: () {},
    onStartClinicalTrialEnrollment: () {},
    onShowSettings: () {},
    onShareWithCureHHT: () {},
    onStopSharingWithCureHHT: () {},
    isEnrolledInTrial: true,
    isDisconnected: false,
    enrollmentStatus: 'active',
    isSharingWithCureHHT: false,
    userName: 'John Doe',
    onUpdateUserName: (_) {},
    enrollmentCode: 'CA12345678',
    enrollmentDateTime: DateTime(2026, 1, 15, 10, 30),
    siteName: 'University Hospital Clinical Research Center',
    sitePhoneNumber: '+1 (555) 123-4567',
  );
}

// Disconnected state - was enrolled but disconnected by site
Widget _buildDisconnectedState(BuildContext context) {
  return ProfileScreen(
    onBack: () {},
    onStartClinicalTrialEnrollment: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigate to enrollment screen')),
      );
    },
    onShowSettings: () {},
    onShareWithCureHHT: () {},
    onStopSharingWithCureHHT: () {},
    isEnrolledInTrial: true,
    isDisconnected: true,
    enrollmentStatus: 'active',
    isSharingWithCureHHT: false,
    userName: 'Jane Smith',
    onUpdateUserName: (_) {},
    enrollmentCode: 'CA87654321',
    enrollmentDateTime: DateTime(2025, 11, 20, 14, 45),
    siteName: 'City Medical Center',
    sitePhoneNumber: '+1 (555) 987-6543',
  );
}

// Not participating state - not enrolled in any trial
Widget _buildNotParticipatingState(BuildContext context) {
  return ProfileScreen(
    onBack: () {},
    onStartClinicalTrialEnrollment: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigate to enrollment screen')),
      );
    },
    onShowSettings: () {},
    onShareWithCureHHT: () {},
    onStopSharingWithCureHHT: () {},
    isEnrolledInTrial: false,
    isDisconnected: false,
    enrollmentStatus: 'none',
    isSharingWithCureHHT: false,
    userName: 'New User',
    onUpdateUserName: (_) {},
  );
}

// Interactive state with knobs
Widget _buildInteractiveState(BuildContext context) {
  final isEnrolled = context.knobs.boolean(
    label: 'Is Enrolled',
    initialValue: true,
  );

  final isDisconnected = context.knobs.boolean(
    label: 'Is Disconnected',
    initialValue: false,
  );

  final userName = context.knobs.string(
    label: 'User Name',
    initialValue: 'Demo User',
  );

  final siteName = context.knobs.stringOrNull(
    label: 'Site Name',
    initialValue: 'Research Hospital',
  );

  final enrollmentCode = context.knobs.stringOrNull(
    label: 'Enrollment Code',
    initialValue: 'CA12345678',
  );

  return ProfileScreen(
    onBack: () {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Back pressed')));
    },
    onStartClinicalTrialEnrollment: () {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Navigate to enrollment')));
    },
    onShowSettings: () {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Navigate to settings')));
    },
    onShareWithCureHHT: () {},
    onStopSharingWithCureHHT: () {},
    isEnrolledInTrial: isEnrolled,
    isDisconnected: isDisconnected,
    enrollmentStatus: isEnrolled ? 'active' : 'none',
    isSharingWithCureHHT: false,
    userName: userName,
    onUpdateUserName: (_) {},
    enrollmentCode: isEnrolled ? enrollmentCode : null,
    enrollmentDateTime: isEnrolled ? DateTime(2026, 1, 15) : null,
    siteName: siteName,
    sitePhoneNumber: '+1 (555) 123-4567',
  );
}

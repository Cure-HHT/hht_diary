// StudySettingsScreen is a pure snapshot renderer: sections in, pixels
// out, onRetry from the error state. Values arrive pre-formatted —
// including the "Not yet implemented" placeholders, which must be
// visually distinct from real values.
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

const _sections = [
  StudySettingsSectionView(
    title: 'Authentication and Sessions',
    description:
        'Controls login sessions, password expiration, and two-factor '
        'authentication timing.',
    rows: [
      StudySettingRowView(
        label: 'Sponsor Portal Session Idle Timeout',
        value: '10 minutes',
      ),
      StudySettingRowView(
        label: 'Password Expiry Interval',
        value: 'Not yet implemented',
        implemented: false,
      ),
    ],
  ),
  StudySettingsSectionView(
    title: 'Rate Limiting',
    description: 'Controls login and linking code attempt limits.',
    rows: [
      StudySettingRowView(
        label: 'Two-Factor Code Attempt Limit',
        value: '5 attempts',
      ),
    ],
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  List<StudySettingsSectionView> sections = _sections,
  bool isLoading = false,
  String? errorMessage,
  VoidCallback? onRetry,
  bool showVariableNames = false,
}) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(font: AppFontFamily.inter),
      home: Scaffold(
        body: StudySettingsScreen(
          sections: sections,
          isLoading: isLoading,
          errorMessage: errorMessage,
          onRetry: onRetry ?? () {},
          showVariableNames: showVariableNames,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('renders title, subtitle and the view-only banner', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Study Settings'), findsOneWidget);
    expect(
      find.text('View current configuration settings for this study.'),
      findsOneWidget,
    );
    expect(find.text('These settings are view only.'), findsOneWidget);
  });

  testWidgets('renders every section with headers and rows', (tester) async {
    await _pump(tester);
    expect(find.text('Authentication and Sessions'), findsOneWidget);
    expect(find.text('Rate Limiting'), findsOneWidget);
    // One Parameter/Current Value header pair per section.
    expect(find.text('Parameter'), findsNWidgets(2));
    expect(find.text('Current Value'), findsNWidgets(2));
    expect(find.text('Sponsor Portal Session Idle Timeout'), findsOneWidget);
    expect(find.text('10 minutes'), findsOneWidget);
  });

  testWidgets('unimplemented rows render the placeholder in italic', (
    tester,
  ) async {
    await _pump(tester);
    final text = tester.widget<Text>(find.text('Not yet implemented'));
    expect(text.style?.fontStyle, FontStyle.italic);
    // Real values are not italic.
    final real = tester.widget<Text>(find.text('10 minutes'));
    expect(real.style?.fontStyle, isNull);
  });

  testWidgets('error state shows message + Retry wired to onRetry', (
    tester,
  ) async {
    var retries = 0;
    await _pump(tester, errorMessage: 'HTTP 500', onRetry: () => retries++);
    expect(find.text("Couldn't load study settings."), findsOneWidget);
    expect(find.text('HTTP 500'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('loading overlay renders while fetching', (tester) async {
    await _pump(tester, sections: const [], isLoading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('carries the Playwright handles', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsIdentifier('settings-screen'), findsOneWidget);
    expect(find.bySemanticsIdentifier('settings-banner'), findsOneWidget);
    handle.dispose();
  });

  group('SystemOperator variable-name affordance', () {
    const sysOpSections = [
      StudySettingsSectionView(
        title: 'Diary Entry Rules',
        description: 'desc',
        rows: [
          StudySettingRowView(
            label: 'Lock Threshold',
            value: '48 hours',
            variableName: 'clinical.lockThresholdHours',
          ),
          StudySettingRowView(
            label: 'Password Expiry Interval',
            value: 'Not yet implemented',
            implemented: false,
          ),
        ],
      ),
    ];

    testWidgets('hidden for regular viewers (default)', (tester) async {
      await _pump(tester, sections: sysOpSections);
      expect(find.byTooltip('clinical.lockThresholdHours'), findsNothing);
    });

    testWidgets('shown for operators; click copies the identifier', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _pump(tester, sections: sysOpSections, showVariableNames: true);
      expect(find.byTooltip('clinical.lockThresholdHours'), findsOneWidget);

      await tester.tap(find.text('Lock Threshold'));
      await tester.pump();
      expect(copied, ['clinical.lockThresholdHours']);
      expect(
        find.text('Copied clinical.lockThresholdHours'),
        findsOneWidget,
        reason: 'snackbar confirms the copy',
      );
      // Rows with no backing variable get no affordance even for operators.
      expect(find.byTooltip('Not yet implemented'), findsNothing);
    });
  });
}

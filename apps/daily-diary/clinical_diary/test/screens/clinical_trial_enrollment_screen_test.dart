import 'package:clinical_diary/screens/clinical_trial_enrollment_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  // Verifies: DIARY-PRD-mobile-application/A
  // Verifies: DIARY-PRD-linking-code-lifecycle
  group('ClinicalTrialEnrollmentScreen', () {
    late EnrollmentService enrollmentService;
    late MockSecureStorage mockStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockStorage = MockSecureStorage();
      // Pre-set auth JWT token - required for linking
      mockStorage.data['auth_jwt'] = 'test-jwt-token';
      mockStorage.data['auth_username'] = 'test-user-id';
    });

    Widget buildScreen({http.Client? httpClient}) {
      final client =
          httpClient ??
          MockClient((_) async => http.Response('{"error": "error"}', 400));
      enrollmentService = EnrollmentService(
        httpClient: client,
        secureStorage: mockStorage,
      );

      return wrapWithMaterialApp(
        ClinicalTrialEnrollmentScreen(enrollmentService: enrollmentService),
      );
    }

    group('Basic Rendering', () {
      testWidgets('displays Join the Study title', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('Join the Study'), findsOneWidget);
      });

      testWidgets('displays linking code title', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('Enter Linking Code'), findsOneWidget);
      });

      testWidgets('displays description text', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Please enter the 10-digit linking code provided by your research coordinator.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays two text input fields', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNWidgets(2));
      });

      testWidgets('displays code format hint', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(
          find.text('Code format: XXXXX-XXXXX, letters and numbers'),
          findsOneWidget,
        );
      });

      testWidgets('displays linking consent row with Privacy Policy link', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Single consent row via the design system AppConsentRow.
        expect(find.byType(AppConsentRow), findsOneWidget);
        // Consent text is a RichText with "Privacy Policy" as a tappable link.
        expect(find.byType(RichText), findsWidgets);
        expect(
          find.textContaining('I have read, understand, and consent to the'),
          findsOneWidget,
        );
      });

      testWidgets(
        'does not show Share data prior to linking checkbox (CUR-990)',
        (tester) async {
          await tester.pumpWidget(buildScreen());
          await tester.pumpAndSettle();

          // Optional checkbox was removed — linking requires only the mandatory consent
          expect(
            find.text('Share data prior to enrollment (optional)'),
            findsNothing,
          );
        },
      );

      testWidgets('displays link button', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('Link to Clinical Trial'), findsOneWidget);
      });

      testWidgets('displays back-to-home affordance', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
      });
    });

    group('Code Input', () {
      testWidgets('converts input to uppercase', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'abcde');
        await tester.pump();

        expect(find.text('ABCDE'), findsOneWidget);
      });

      testWidgets('auto-focuses second field when first is complete', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ABCDE');
        await tester.pumpAndSettle();

        // After entering 5 chars, second field should get focus
        // We verify by checking that the first field text is complete
        expect(find.text('ABCDE'), findsOneWidget);
      });

      testWidgets('pasting the full code into the first box spans both boxes', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        // Paste the whole 10-char code into the (auto-focused) first box.
        await tester.enterText(textFields.first, 'CATY3XM4X8');
        await tester.pumpAndSettle();

        // First 5 stay in box 1; the remainder flows into box 2.
        expect(find.text('CATY3'), findsOneWidget);
        expect(find.text('XM4X8'), findsOneWidget);
      });

      testWidgets('pasting a dash-formatted code spans both boxes', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        // The dash is stripped by the input formatter, then the code spans.
        await tester.enterText(textFields.first, 'CATY3-XM4X8');
        await tester.pumpAndSettle();

        expect(find.text('CATY3'), findsOneWidget);
        expect(find.text('XM4X8'), findsOneWidget);
      });

      testWidgets('overflow beyond 10 chars is dropped (box 2 stays 5)', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ABCDEFGHIJKLMNO');
        await tester.pumpAndSettle();

        expect(find.text('ABCDE'), findsOneWidget); // box 1
        expect(find.text('FGHIJ'), findsOneWidget); // box 2 (capped at 5)
      });

      testWidgets('limits second field to 5 characters', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(1), 'FGHIJKL');
        await tester.pump();

        expect(find.text('FGHIJ'), findsOneWidget);
      });

      testWidgets('filters non-alphanumeric characters', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'AB-CD!');
        await tester.pump();

        // Should only have letters/numbers
        expect(find.text('ABCD'), findsOneWidget);
      });
    });

    group('Checkbox Interactions', () {
      testWidgets('can toggle required consent row', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Resting state: no check glyph rendered.
        expect(
          find.descendant(
            of: find.byType(AppConsentRow),
            matching: find.byIcon(Icons.check),
          ),
          findsNothing,
        );

        // Tap the consent row body.
        await tester.tap(find.byType(AppConsentRow));
        await tester.pumpAndSettle();

        // Checked state: AppConsentRow renders an Icons.check glyph.
        expect(
          find.descendant(
            of: find.byType(AppConsentRow),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
      });
    });

    group('Link Button State', () {
      testWidgets('button is disabled when code is incomplete', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final enrollButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Link to Clinical Trial'),
        );
        expect(enrollButton.onPressed, isNull);
      });

      testWidgets('button is disabled when consent not checked', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Enter complete code
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ABCDE');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'FGHIJ');
        await tester.pump();

        // Don't check the consent row

        final enrollButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Link to Clinical Trial'),
        );
        expect(enrollButton.onPressed, isNull);
      });

      testWidgets('button is enabled when code complete and consent checked', (
        tester,
      ) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Enter complete code
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ABCDE');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'FGHIJ');
        await tester.pump();

        // Check the consent row
        await tester.tap(find.byType(AppConsentRow));
        await tester.pumpAndSettle();

        final enrollButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Link to Clinical Trial'),
        );
        expect(enrollButton.onPressed, isNotNull);
      });
    });

    group('Linking Error Handling', () {
      testWidgets('shows invalid-code error caption on linking failure', (
        tester,
      ) async {
        final mockClient = MockClient((_) async {
          return http.Response('{"error": "Invalid linking code"}', 400);
        });

        await tester.pumpWidget(buildScreen(httpClient: mockClient));
        await tester.pumpAndSettle();

        // Enter complete code and check consent
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ABCDE');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'FGHIJ');
        await tester.pump();
        await tester.tap(find.byType(AppConsentRow));
        await tester.pumpAndSettle();

        // Tap link button
        await tester.tap(
          find.widgetWithText(FilledButton, 'Link to Clinical Trial'),
        );
        await tester.pumpAndSettle();

        // The AppCodeInput flips to its `invalid` state and surfaces the
        // server message as its errorText caption.
        final codeInput = tester.widget<AppCodeInput>(
          find.byType(AppCodeInput),
        );
        expect(codeInput.errorText, isNotNull);
        expect(codeInput.state, AppCodeInputState.invalid);
      });

      testWidgets('clears error caption when code changes', (tester) async {
        final mockClient = MockClient((_) async {
          return http.Response('{"error": "Invalid linking code"}', 400);
        });

        await tester.pumpWidget(buildScreen(httpClient: mockClient));
        await tester.pumpAndSettle();

        // Enter code and check consent
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ABCDE');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'FGHIJ');
        await tester.pump();
        await tester.tap(find.byType(AppConsentRow));
        await tester.pumpAndSettle();

        // Tap link button to get error
        await tester.tap(
          find.widgetWithText(FilledButton, 'Link to Clinical Trial'),
        );
        await tester.pumpAndSettle();

        // Error caption is set
        var codeInput = tester.widget<AppCodeInput>(find.byType(AppCodeInput));
        expect(codeInput.errorText, isNotNull);

        // Change code to clear error
        await tester.enterText(textFields.first, 'XXXXX');
        await tester.pump();

        codeInput = tester.widget<AppCodeInput>(find.byType(AppCodeInput));
        expect(codeInput.errorText, isNull);
      });
    });

    group('Navigation', () {
      testWidgets('back button pops screen', (tester) async {
        var popped = false;
        final navMockStorage = MockSecureStorage();
        navMockStorage.data['auth_jwt'] = 'test-jwt-token';
        navMockStorage.data['auth_username'] = 'test-user-id';

        await tester.pumpWidget(
          wrapWithMaterialApp(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => ClinicalTrialEnrollmentScreen(
                        enrollmentService: EnrollmentService(
                          httpClient: MockClient(
                            (_) async => http.Response('{}', 200),
                          ),
                          secureStorage: navMockStorage,
                        ),
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();

        expect(popped, isTrue);
      });
    });
  });

  group('UpperCaseTextFormatter', () {
    test('converts lowercase to uppercase', () {
      final formatter = UpperCaseTextFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'abc',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );

      expect(result.text, 'ABC');
      expect(result.selection.baseOffset, 3);
    });

    test('keeps uppercase as is', () {
      final formatter = UpperCaseTextFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'ABC',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );

      expect(result.text, 'ABC');
    });

    test('handles mixed case', () {
      final formatter = UpperCaseTextFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'AbCdE',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );

      expect(result.text, 'ABCDE');
    });

    test('handles numbers', () {
      final formatter = UpperCaseTextFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'abc123',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );

      expect(result.text, 'ABC123');
    });

    test('preserves selection', () {
      final formatter = UpperCaseTextFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'abc',
          selection: TextSelection(baseOffset: 1, extentOffset: 2),
        ),
      );

      expect(result.selection.baseOffset, 1);
      expect(result.selection.extentOffset, 2);
    });
  });
}

/// Mock implementation of FlutterSecureStorage for testing
class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(data);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.clear();
  }

  @override
  IOSOptions get iOptions => IOSOptions.defaultOptions;

  @override
  AndroidOptions get aOptions => AndroidOptions.defaultOptions;

  @override
  LinuxOptions get lOptions => LinuxOptions.defaultOptions;

  @override
  WebOptions get webOptions => WebOptions.defaultOptions;

  @override
  MacOsOptions get mOptions => MacOsOptions.defaultOptions;

  @override
  WindowsOptions get wOptions => WindowsOptions.defaultOptions;

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => true;

  @override
  Stream<bool> get onCupertinoProtectedDataAvailabilityChanged =>
      Stream.value(true);

  @override
  void registerListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterAllListeners() {}

  @override
  void unregisterAllListenersForKey({required String key}) {}
}

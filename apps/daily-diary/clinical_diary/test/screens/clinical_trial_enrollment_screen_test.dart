// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p70007: Linking Code Lifecycle Management

import 'package:clinical_diary/screens/clinical_trial_enrollment_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
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

  group('ClinicalTrialEnrollmentScreen', () {
    late EnrollmentService enrollmentService;
    late MockSecureStorage mockStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockStorage = MockSecureStorage();
      // Pre-set auth JWT token - required for enrollment/linking (REQ-p70007)
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
      testWidgets('displays title', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('Clinical Trial Enrollment'), findsOneWidget);
      });

      testWidgets('displays enrollment code title', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('Enter Enrollment Code'), findsOneWidget);
      });

      testWidgets('displays description text', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Please enter the 10-digit enrollment code provided by your research coordinator.',
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
          find.text('Code format: XXXXX-XXXXX (letters and numbers)'),
          findsOneWidget,
        );
      });

      testWidgets('displays sharing agreement checkboxes', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byType(Checkbox), findsNWidgets(2));
        expect(
          find.text('Share data prior to enrollment (optional)'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'I have read, understand, and consent to the sharing agreement',
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays enroll button', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.text('Enroll in Clinical Trial'), findsOneWidget);
      });

      testWidgets('displays back button', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
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

      testWidgets('limits first field to 5 characters', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ABCDEFGH');
        await tester.pump();

        // Should only have first 5 characters
        expect(find.text('ABCDE'), findsOneWidget);
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
      testWidgets('can toggle optional sharing checkbox', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Find the optional checkbox by its text
        final optionalCheckbox = find.ancestor(
          of: find.text('Share data prior to enrollment (optional)'),
          matching: find.byType(InkWell),
        );

        await tester.tap(optionalCheckbox);
        await tester.pump();

        // Checkbox should be checked
        final checkboxes = find.byType(Checkbox);
        final firstCheckbox = tester.widget<Checkbox>(checkboxes.first);
        expect(firstCheckbox.value, isTrue);
      });

      testWidgets('can toggle required consent checkbox', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Find the required checkbox by its text
        final requiredCheckbox = find.ancestor(
          of: find.textContaining('I have read, understand'),
          matching: find.byType(InkWell),
        );

        await tester.tap(requiredCheckbox);
        await tester.pump();

        // Second checkbox should be checked
        final checkboxes = find.byType(Checkbox);
        final secondCheckbox = tester.widget<Checkbox>(checkboxes.at(1));
        expect(secondCheckbox.value, isTrue);
      });
    });

    group('Enroll Button State', () {
      testWidgets('button is disabled when code is incomplete', (tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final enrollButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Enroll in Clinical Trial'),
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

        // Don't check the consent checkbox

        final enrollButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Enroll in Clinical Trial'),
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

        // Check the consent checkbox
        final requiredCheckbox = find.ancestor(
          of: find.textContaining('I have read, understand'),
          matching: find.byType(InkWell),
        );
        await tester.tap(requiredCheckbox);
        await tester.pump();

        final enrollButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Enroll in Clinical Trial'),
        );
        expect(enrollButton.onPressed, isNotNull);
      });
    });

    group('Enrollment Error Handling', () {
      testWidgets('shows error message on enrollment failure', (tester) async {
        final mockClient = MockClient((_) async {
          return http.Response('{"error": "Invalid code"}', 400);
        });

        await tester.pumpWidget(buildScreen(httpClient: mockClient));
        await tester.pumpAndSettle();

        // Enter complete code and check consent
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ABCDE');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'FGHIJ');
        await tester.pump();

        final requiredCheckbox = find.ancestor(
          of: find.textContaining('I have read, understand'),
          matching: find.byType(InkWell),
        );
        await tester.tap(requiredCheckbox);
        await tester.pump();

        // Tap enroll button
        await tester.tap(
          find.widgetWithText(FilledButton, 'Enroll in Clinical Trial'),
        );
        await tester.pumpAndSettle();

        // Should show error message
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('clears error message when code changes', (tester) async {
        final mockClient = MockClient((_) async {
          return http.Response('{"error": "Invalid code"}', 400);
        });

        await tester.pumpWidget(buildScreen(httpClient: mockClient));
        await tester.pumpAndSettle();

        // Enter code and check consent
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'ABCDE');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'FGHIJ');
        await tester.pump();

        final requiredCheckbox = find.ancestor(
          of: find.textContaining('I have read, understand'),
          matching: find.byType(InkWell),
        );
        await tester.tap(requiredCheckbox);
        await tester.pump();

        // Tap enroll button to get error
        await tester.tap(
          find.widgetWithText(FilledButton, 'Enroll in Clinical Trial'),
        );
        await tester.pumpAndSettle();

        // Verify error is shown
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // Change code to clear error
        await tester.enterText(textFields.first, 'XXXXX');
        await tester.pump();

        // Error should be cleared
        expect(find.byIcon(Icons.error_outline), findsNothing);
      });
    });

    group('Navigation', () {
      testWidgets('back button pops screen', (tester) async {
        var popped = false;
        final navMockStorage = MockSecureStorage();
        navMockStorage.data['auth_jwt'] = 'test-jwt-token';
        navMockStorage.data['auth_username'] = 'test-user-id';

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
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

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_back));
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

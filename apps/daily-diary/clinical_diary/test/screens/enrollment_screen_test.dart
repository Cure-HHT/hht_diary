// Tests for enrollment_screen.dart
// Covers: User enrollment flow, code validation, error handling

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/enrollment_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../test_helpers/flavor_setup.dart';
import '../services/enrollment_service_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  Widget buildTestWidget({
    required EnrollmentService enrollmentService,
    required VoidCallback onEnrolled,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: EnrollmentScreen(
        enrollmentService: enrollmentService,
        onEnrolled: onEnrolled,
      ),
    );
  }

  group('EnrollmentScreen', () {
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
    });

    testWidgets('displays welcome title', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      // Check for title text
      expect(find.textContaining('Welcome'), findsOneWidget);

      service.dispose();
    });

    testWidgets('displays code input field', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      service.dispose();
    });

    testWidgets('displays get started button', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FilledButton), findsOneWidget);

      service.dispose();
    });

    testWidgets('text field limits to 8 characters', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ABCDEFGHIJKLMNOP');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text.length, 8);

      service.dispose();
    });

    testWidgets('text field converts to uppercase', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'abcdefgh');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'ABCDEFGH');

      service.dispose();
    });

    testWidgets('shows error for empty code', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      // Tap get started without entering code
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Should show error
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      service.dispose();
    });

    testWidgets('shows error for code less than 8 chars', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ABCD');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Should show error
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      service.dispose();
    });

    testWidgets('shows loading indicator during enrollment', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((request) async {
          // Delay to show loading state
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response('{"error": "Invalid"}', 400);
        }),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'CAXXXXXX');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for request to complete
      await tester.pumpAndSettle();

      service.dispose();
    });

    testWidgets('clears error when text changes', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      // Trigger error
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Type in the field
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump();

      // Error should be cleared
      expect(find.byIcon(Icons.error_outline), findsNothing);

      service.dispose();
    });

    testWidgets('calls onEnrolled on successful enrollment', (tester) async {
      var enrolledCalled = false;

      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((request) async {
          return http.Response(
            '{"success": true, "jwt": "token", "userId": "user", "patientId": "p1", "siteId": "s1"}',
            200,
          );
        }),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () => enrolledCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'CAXXXXXX');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(enrolledCalled, true);

      service.dispose();
    });

    testWidgets('shows error message on enrollment failure', (tester) async {
      final service = EnrollmentService(
        secureStorage: mockStorage,
        httpClient: MockClient((request) async {
          return http.Response('{"error": "Code expired"}', 410);
        }),
      );

      await tester.pumpWidget(
        buildTestWidget(
          enrollmentService: service,
          onEnrolled: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'CAXXXXXX');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Should show error icon
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      service.dispose();
    });
  });

  group('UpperCaseTextFormatter', () {
    test('converts lowercase to uppercase', () {
      final formatter = UpperCaseTextFormatter();
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 3),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'ABC');
    });

    test('preserves selection position', () {
      final formatter = UpperCaseTextFormatter();
      const oldValue = TextEditingValue(text: 'AB');
      const newValue = TextEditingValue(
        text: 'ABc',
        selection: TextSelection.collapsed(offset: 3),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.selection.baseOffset, 3);
    });

    test('handles mixed case', () {
      final formatter = UpperCaseTextFormatter();
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(
        text: 'AbCdEf',
        selection: TextSelection.collapsed(offset: 6),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'ABCDEF');
    });
  });
}

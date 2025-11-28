// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/widgets/enrollment_success_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnrollmentSuccessDialog', () {
    testWidgets('displays processing state initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnrollmentSuccessDialog(),
          ),
        ),
      );

      // Should show processing indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Processing...'), findsOneWidget);

      // Complete the timer to avoid pending timer errors
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('transitions to success state after delay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnrollmentSuccessDialog(),
          ),
        ),
      );

      // Initially shows processing
      expect(find.text('Processing...'), findsOneWidget);

      // Wait for transition (1 second)
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should now show success
      expect(find.text('Success!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows checkmark icon in success state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnrollmentSuccessDialog(),
          ),
        ),
      );

      // Wait for transition
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('hides progress indicator in success state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnrollmentSuccessDialog(),
          ),
        ),
      );

      // Wait for transition
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays enrollment confirmed message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnrollmentSuccessDialog(),
          ),
        ),
      );

      // Wait for transition
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Enrollment Confirmed'), findsOneWidget);
    });

    testWidgets('is contained in a Card widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnrollmentSuccessDialog(),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);

      // Complete the timer to avoid pending timer errors
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });
  });
}

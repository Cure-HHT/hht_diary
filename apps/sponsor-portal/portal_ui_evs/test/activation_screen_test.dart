// Verifies: DIARY-PRD-user-account-activation-workflow/H (client page)
//
// ActivationScreen on the design-kit auth card (Figma: Activate Your
// Account): the password rule is stated AND gated client-side (mirroring
// the server's authoritative check), Verify stays disabled until both
// fields satisfy it, and the code-validation / success / invalid-link
// states render on the same card.
import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_ui_evs/src/activation_screen.dart';

http.Client _server({bool codeValid = true, bool activateOk = true}) =>
    MockClient((req) async {
      if (req.method == 'GET') {
        return http.Response(
          jsonEncode(
            codeValid
                ? {'valid': true, 'maskedEmail': 'e***@r***.local'}
                : {'valid': false, 'message': 'This link is no longer valid.'},
          ),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(
          activateOk
              ? {'ok': true}
              : {'ok': false, 'message': 'Activation failed.'},
        ),
        activateOk ? 200 : 400,
        headers: const {'content-type': 'application/json'},
      );
    });

Future<void> _pump(
  WidgetTester tester, {
  http.Client? client,
  VoidCallback? onBackToLogin,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(font: AppFontFamily.inter),
      home: ActivationScreen(
        serverUrl: 'http://portal.test',
        code: 'AB-CD',
        httpClient: client ?? _server(),
        onBackToLogin: onBackToLogin,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

bool _verifyEnabled(WidgetTester tester) {
  final btn = tester.widget<FilledButton>(
    find.ancestor(of: find.text('Verify'), matching: find.byType(FilledButton)),
  );
  return btn.onPressed != null;
}

void main() {
  testWidgets('valid code renders the Figma card: title, rule subtitle, '
      'both fields, Verify, Back to Login', (tester) async {
    await _pump(tester);
    expect(find.text('Activate your account'), findsOneWidget);
    expect(
      find.text('Your password must be at least 8 characters long'),
      findsOneWidget,
    );
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm Your Password'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(find.text('Back to Login'), findsOneWidget);
    expect(_verifyEnabled(tester), isFalse);
  });

  testWidgets('short password shows the inline rule and keeps Verify '
      'disabled', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'pw12345');
    await tester.enterText(find.byType(TextFormField).at(1), 'pw12345');
    await tester.pump();
    expect(find.text('At least 8 characters.'), findsOneWidget);
    expect(_verifyEnabled(tester), isFalse);
  });

  testWidgets('mismatched confirmation shows the inline error and keeps '
      'Verify disabled', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'pw123456');
    await tester.enterText(find.byType(TextFormField).at(1), 'pw123457');
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(_verifyEnabled(tester), isFalse);
  });

  testWidgets('compliant matching passwords enable Verify; success shows '
      'the activated banner', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'pw123456');
    await tester.enterText(find.byType(TextFormField).at(1), 'pw123456');
    await tester.pump();
    expect(_verifyEnabled(tester), isTrue);
    await tester.tap(find.text('Verify'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('Account activated — you can now sign in.'),
      findsOneWidget,
    );
    expect(
      find.text('Verify'),
      findsNothing,
      reason: 'the form collapses once activated',
    );
  });

  testWidgets('invalid code: error banner, no form, Back to Login fires', (
    tester,
  ) async {
    var backs = 0;
    await _pump(
      tester,
      client: _server(codeValid: false),
      onBackToLogin: () => backs++,
    );
    expect(find.text('This link is no longer valid.'), findsOneWidget);
    expect(find.text('New Password'), findsNothing);
    await tester.tap(find.text('Back to Login'));
    await tester.pump();
    expect(backs, 1);
  });
}

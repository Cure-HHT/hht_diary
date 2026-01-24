// IMPLEMENTS REQUIREMENTS:
//   REQ-p00044: Password Reset
//   REQ-d00031: Identity Platform Integration

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/pages/forgot_password_page.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService() : super(firebaseAuth: MockFirebaseAuth());

  bool _shouldSucceed = true;
  String? _errorMessage;

  void setSuccess(bool success, {String? error}) {
    _shouldSucceed = success;
    _errorMessage = error;
  }

  @override
  String? get error => _errorMessage;

  @override
  Future<bool> requestPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (!_shouldSucceed) {
      _errorMessage ??= 'Failed to send password reset email';
    }
    return _shouldSucceed;
  }
}

void main() {
  late FakeAuthService fakeAuthService;

  setUp(() {
    fakeAuthService = FakeAuthService();
  });

  Widget createTestWidget(AuthService authService, Widget child) {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: child,
      ),
    );
  }

  group('ForgotPasswordPage', () {
    testWidgets('renders email input and submit button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(fakeAuthService, const ForgotPasswordPage()),
      );

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });

    testWidgets('validates empty email', (tester) async {
      await tester.pumpWidget(
        createTestWidget(fakeAuthService, const ForgotPasswordPage()),
      );

      // Tap submit without entering email
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('validates invalid email format', (tester) async {
      await tester.pumpWidget(
        createTestWidget(fakeAuthService, const ForgotPasswordPage()),
      );

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField), 'invalid-email');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows success view after submitting valid email', (
      tester,
    ) async {
      fakeAuthService.setSuccess(true);

      await tester.pumpWidget(
        createTestWidget(fakeAuthService, const ForgotPasswordPage()),
      );

      // Enter valid email
      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      // Verify success view
      expect(find.text('Check Your Email'), findsOneWidget);
      expect(
        find.textContaining('If an account exists with that email'),
        findsOneWidget,
      );
      expect(find.text('Back to Login'), findsOneWidget);
    });

    testWidgets('shows error message on failure', (tester) async {
      fakeAuthService.setSuccess(
        false,
        error: 'Failed to send password reset email',
      );

      await tester.pumpWidget(
        createTestWidget(fakeAuthService, const ForgotPasswordPage()),
      );

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to send password reset email'), findsOneWidget);
    });

    testWidgets('trims whitespace from email', (tester) async {
      fakeAuthService.setSuccess(true);

      await tester.pumpWidget(
        createTestWidget(fakeAuthService, const ForgotPasswordPage()),
      );

      // Enter email with whitespace - should trim to 'test@example.com'
      await tester.enterText(
        find.byType(TextFormField),
        '  test@example.com  ',
      );
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      // Success view should appear
      expect(find.text('Check Your Email'), findsOneWidget);
    });
  });
}

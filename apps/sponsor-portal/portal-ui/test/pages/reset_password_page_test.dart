// IMPLEMENTS REQUIREMENTS:
//   REQ-p00044: Password Reset
//   REQ-p00071: Password Complexity
//   REQ-d00031: Identity Platform Integration

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/pages/reset_password_page.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService() : super(firebaseAuth: MockFirebaseAuth());

  String? _verifyCodeResult;
  bool _confirmResetSuccess = true;
  String? _errorMessage;
  Exception? _verifyException;
  Exception? _confirmException;

  void setVerifyCodeResult(String? email) {
    _verifyCodeResult = email;
    _verifyException = null;
  }

  void setVerifyException(Exception exception) {
    _verifyException = exception;
  }

  void setConfirmResetResult(bool success, {String? error}) {
    _confirmResetSuccess = success;
    _errorMessage = error;
    _confirmException = null;
  }

  void setConfirmException(Exception exception) {
    _confirmException = exception;
  }

  @override
  String? get error => _errorMessage;

  @override
  Future<String?> verifyPasswordResetCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (_verifyException != null) throw _verifyException!;
    return _verifyCodeResult;
  }

  @override
  Future<bool> confirmPasswordReset(String code, String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (_confirmException != null) throw _confirmException!;
    if (!_confirmResetSuccess) {
      _errorMessage ??= 'The link may have expired';
    }
    return _confirmResetSuccess;
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

  group('ResetPasswordPage', () {
    const testOobCode = 'test-oob-code-12345';
    const testEmail = 'test@example.com';

    testWidgets('shows error when oobCode is missing', (tester) async {
      await tester.pumpWidget(
        createTestWidget(fakeAuthService, const ResetPasswordPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invalid Reset Link'), findsOneWidget);
      expect(find.text('Invalid or missing reset code'), findsOneWidget);
    });

    testWidgets('verifies reset code on initialization', (tester) async {
      fakeAuthService.setVerifyCodeResult(testEmail);

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );

      // Should show loading initially
      expect(find.text('Verifying reset link...'), findsOneWidget);

      await tester.pumpAndSettle();

      // Should show form after verification
      expect(find.text('Create New Password'), findsOneWidget);
      expect(find.text('for $testEmail'), findsOneWidget);
    });

    testWidgets('shows error when code verification fails', (tester) async {
      fakeAuthService.setVerifyCodeResult(null);

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invalid Reset Link'), findsOneWidget);
      expect(
        find.textContaining('This password reset link is invalid'),
        findsOneWidget,
      );
    });

    testWidgets('renders password form after successful verification', (
      tester,
    ) async {
      fakeAuthService.setVerifyCodeResult(testEmail);

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create New Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });

    testWidgets('validates password is required', (tester) async {
      fakeAuthService.setVerifyCodeResult(testEmail);

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit without entering password
      // Ensure button is visible before tapping
      await tester.ensureVisible(find.text('Reset Password'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets('validates password minimum length (8 chars)', (tester) async {
      fakeAuthService.setVerifyCodeResult(testEmail);

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      final passwordFields = find.byType(TextFormField);
      await tester.enterText(passwordFields.first, 'short');

      // Ensure button is visible before tapping
      await tester.ensureVisible(find.text('Reset Password'));
      await tester.pumpAndSettle();

      // Ensure button is visible before tapping
      await tester.ensureVisible(find.text('Reset Password'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('validates password maximum length (64 chars)', (tester) async {
      fakeAuthService.setVerifyCodeResult(testEmail);

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      final passwordFields = find.byType(TextFormField);
      final longPassword = 'a' * 65;
      await tester.enterText(passwordFields.first, longPassword);
      // Ensure button is visible before tapping
      await tester.ensureVisible(find.text('Reset Password'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be less than 64 characters'),
        findsOneWidget,
      );
    });

    testWidgets('validates passwords match', (tester) async {
      fakeAuthService.setVerifyCodeResult(testEmail);

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      final passwordFields = find.byType(TextFormField);
      await tester.enterText(passwordFields.first, 'password123');
      await tester.enterText(passwordFields.last, 'different123');
      // Ensure button is visible before tapping
      await tester.ensureVisible(find.text('Reset Password'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('submits password reset successfully', (tester) async {
      fakeAuthService.setVerifyCodeResult(testEmail);
      fakeAuthService.setConfirmResetResult(true);

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      final passwordFields = find.byType(TextFormField);
      await tester.enterText(passwordFields.first, 'newpassword123');
      await tester.enterText(passwordFields.last, 'newpassword123');
      // Ensure button is visible before tapping
      await tester.ensureVisible(find.text('Reset Password'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      // Should show success view
      expect(find.text('Password Reset Complete'), findsOneWidget);
      expect(
        find.textContaining('Your password has been successfully reset'),
        findsOneWidget,
      );
      expect(find.text('Go to Login Now'), findsOneWidget);
    });

    testWidgets('shows error on password reset failure', (tester) async {
      fakeAuthService.setVerifyCodeResult(testEmail);
      fakeAuthService.setConfirmResetResult(
        false,
        error: 'The link may have expired',
      );

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      final passwordFields = find.byType(TextFormField);
      await tester.enterText(passwordFields.first, 'newpassword123');
      await tester.enterText(passwordFields.last, 'newpassword123');
      // Ensure button is visible before tapping
      await tester.ensureVisible(find.text('Reset Password'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('The link may have expired'), findsOneWidget);
    });

    testWidgets('shows password requirements', (tester) async {
      fakeAuthService.setVerifyCodeResult(testEmail);

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Password Requirements:'), findsOneWidget);
      // Note: Text appears both as helper text and in requirements list
      expect(find.text('Minimum 8 characters'), findsWidgets);
      expect(find.text('Maximum 64 characters'), findsWidgets);
      expect(find.text('Any printable characters allowed'), findsWidgets);
    });

    testWidgets('handles verification exception gracefully', (tester) async {
      fakeAuthService.setVerifyException(Exception('Network error'));

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to verify reset code. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('handles reset exception gracefully', (tester) async {
      fakeAuthService.setVerifyCodeResult(testEmail);
      fakeAuthService.setConfirmException(Exception('Network error'));

      await tester.pumpWidget(
        createTestWidget(
          fakeAuthService,
          const ResetPasswordPage(oobCode: testOobCode),
        ),
      );
      await tester.pumpAndSettle();

      final passwordFields = find.byType(TextFormField);
      await tester.enterText(passwordFields.first, 'newpassword123');
      await tester.enterText(passwordFields.last, 'newpassword123');
      // Ensure button is visible before tapping
      await tester.ensureVisible(find.text('Reset Password'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      expect(
        find.text('An unexpected error occurred. Please try again.'),
        findsOneWidget,
      );
    });
  });
}

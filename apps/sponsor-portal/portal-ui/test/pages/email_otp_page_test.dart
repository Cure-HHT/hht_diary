// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// CUR-1137: Resend Code button must disable for the actual server-reported
// wait time when the OTP send is rate limited, and the error message must
// communicate that wait time to the user.

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/pages/email_otp_page.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService() : super(firebaseAuth: MockFirebaseAuth());

  EmailOtpResult? _nextSendResult;
  final String _maskedEmailOverride = 't***@example.com';

  void setNextSendResult(EmailOtpResult result) {
    _nextSendResult = result;
  }

  @override
  String? get maskedEmail => _maskedEmailOverride;

  @override
  Future<EmailOtpResult> sendEmailOtp() async {
    return _nextSendResult ??
        EmailOtpResult.success(maskedEmail: _maskedEmailOverride);
  }
}

void main() {
  late FakeAuthService fakeAuthService;

  setUp(() {
    fakeAuthService = FakeAuthService();
  });

  Widget buildTestApp(AuthService authService) {
    final router = GoRouter(
      initialLocation: '/email-otp',
      routes: [
        GoRoute(path: '/email-otp', builder: (_, __) => const EmailOtpPage()),
        // Stub destinations to keep the router happy when navigation methods
        // exist on the page (none are exercised in these tests).
        GoRoute(path: '/login', builder: (_, __) => const SizedBox()),
        GoRoute(
          path: '/common-dashboard',
          builder: (_, __) => const SizedBox(),
        ),
        GoRoute(path: '/select-role', builder: (_, __) => const SizedBox()),
      ],
    );
    return ChangeNotifierProvider<AuthService>.value(
      value: authService,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('EmailOtpPage rate-limit behaviour (CUR-1137)', () {
    testWidgets(
      'disables Resend button and shows mm:ss countdown when 429 returned',
      (tester) async {
        fakeAuthService.setNextSendResult(
          EmailOtpResult.failure(
            'Too many OTP requests. Please wait before trying again.',
            retryAfter: 780, // 13 minutes
          ),
        );

        await tester.pumpWidget(buildTestApp(fakeAuthService));
        // initState kicks off _sendOtpCode → fake returns synchronously,
        // the State applies setState in the next frame.
        await tester.pump();
        await tester.pump(Duration.zero);

        // Find the Resend button by its label prefix.
        final resendFinder = find.widgetWithText(
          TextButton,
          'Resend code in 13:00',
        );
        expect(
          resendFinder,
          findsOneWidget,
          reason:
              'Button label must format the 780-second cooldown as "13:00" '
              'so the user sees minutes:seconds, not raw seconds.',
        );

        // Button must be disabled (onPressed: null) while the cooldown runs.
        final TextButton resendButton = tester.widget<TextButton>(resendFinder);
        expect(
          resendButton.onPressed,
          isNull,
          reason: 'Resend button must be disabled during rate-limit cooldown',
        );
      },
    );

    testWidgets('error message includes human-readable wait duration on 429', (
      tester,
    ) async {
      fakeAuthService.setNextSendResult(
        EmailOtpResult.failure('Too many OTP requests.', retryAfter: 780),
      );

      await tester.pumpWidget(buildTestApp(fakeAuthService));
      await tester.pump();
      await tester.pump(Duration.zero);

      // The error message body should mention "13 minutes" so the user
      // knows how long to wait.
      expect(
        find.textContaining('13 minutes'),
        findsOneWidget,
        reason:
            'Error message must surface the wait duration so the user is '
            'not left wondering when they can retry',
      );
    });

    testWidgets(
      'short retry_after under 60s renders as "<n> s" in label and "<n> seconds" in error',
      (tester) async {
        fakeAuthService.setNextSendResult(
          EmailOtpResult.failure('Too many OTP requests.', retryAfter: 45),
        );

        await tester.pumpWidget(buildTestApp(fakeAuthService));
        await tester.pump();
        await tester.pump(Duration.zero);

        expect(
          find.widgetWithText(TextButton, 'Resend code in 45 s'),
          findsOneWidget,
        );
        expect(find.textContaining('45 seconds'), findsOneWidget);
      },
    );

    testWidgets(
      'transient failure (no retry_after) keeps optimistic cooldown active',
      (tester) async {
        fakeAuthService.setNextSendResult(
          EmailOtpResult.failure('Failed to send verification code'),
        );

        await tester.pumpWidget(buildTestApp(fakeAuthService));
        await tester.pump();
        await tester.pump(Duration.zero);

        // The optimistic 60-second cooldown started when the send was
        // dispatched. On a transient failure (no retry_after) the page
        // intentionally keeps it running so the user can't hammer the
        // button while the actual server state is unknown — see the
        // comment at email_otp_page.dart `_sendOtpCode` else-branch.
        // _formatCooldown(60) → "1:00".
        final resendFinder = find.widgetWithText(
          TextButton,
          'Resend code in 1:00',
        );
        expect(
          resendFinder,
          findsOneWidget,
          reason:
              'Optimistic 60-second cooldown must remain in effect after a '
              'transient failure to prevent retry storms.',
        );
        final TextButton resendButton = tester.widget<TextButton>(resendFinder);
        expect(
          resendButton.onPressed,
          isNull,
          reason:
              'Button must stay disabled while the optimistic cooldown runs',
        );

        // The transient error message should still be surfaced to the user.
        expect(
          find.textContaining('Failed to send verification code'),
          findsOneWidget,
        );
      },
    );
  });
}

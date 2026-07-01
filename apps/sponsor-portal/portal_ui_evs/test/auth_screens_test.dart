// Verifies: DIARY-PRD-two-factor-authentication/A+B — login form gating,
//   in-flight disable, OTP routing, and session callback.
// Verifies: DIARY-GUI-password-forgot-workflow/B+D+K+P+Q — forgot-password
//   gating + enumeration-safe confirmation, and reset min-length / mismatch.
// Verifies: DIARY-GUI-role-switching/A+B+C+D — multi-role selection step.
// Verifies: DIARY-GUI-role-switching/H — login response threads the display
//   name onto the session callback (welcome-by-name).
// Verifies: DIARY-GUI-role-switching/I — each role card renders a distinct icon.
import 'dart:async';
import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_ui_evs/src/firebase_auth_client.dart';
import 'package:portal_ui_evs/src/forgot_password_request_screen.dart';
import 'package:portal_ui_evs/src/login_screen.dart';
import 'package:portal_ui_evs/src/otp_screen.dart';
import 'package:portal_ui_evs/src/password_reset_screen.dart';
import 'package:portal_ui_evs/src/role_selection_screen.dart';

/// Controllable auth client: returns [token], errors, or hangs on [completer].
class _FakeAuth implements FirebaseAuthClient {
  _FakeAuth({this.throwError = false, this.completer, this.error});
  final bool throwError;
  final Completer<String>? completer;

  /// Specific error to throw (e.g. a FirebaseAuthException). Takes
  /// precedence over the generic [throwError].
  final Object? error;

  @override
  Future<String> signInAndGetIdToken({
    required String email,
    required String password,
  }) {
    if (completer != null) return completer!.future;
    if (error != null) return Future<String>.error(error!);
    if (throwError) return Future<String>.error(StateError('bad creds'));
    return Future<String>.value('idtok');
  }

  @override
  Future<String?> awaitPersistedIdToken() async => null;
}

class _RecordingAuth implements FirebaseAuthClient {
  String? lastEmail;
  @override
  Future<String> signInAndGetIdToken({
    required String email,
    required String password,
  }) {
    lastEmail = email;
    return Future<String>.value('idtok');
  }

  @override
  Future<String?> awaitPersistedIdToken() async => null;
}

http.Client _json(
  int status,
  Object? body, {
  void Function(http.Request)? on,
}) => MockClient((req) async {
  on?.call(req);
  return http.Response(
    body == null ? '' : jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
  );
});

Widget _host(Widget child) => MaterialApp(theme: buildAppTheme(), home: child);

/// Underlying [FilledButton] (primary AppButton) onPressed — null when disabled.
bool _primaryEnabled(WidgetTester tester, String label) {
  final btn = tester.widget<FilledButton>(
    find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
  );
  return btn.onPressed != null;
}

void main() {
  const url = 'http://portal.test';

  group('LoginScreen', () {
    testWidgets('Sign In disabled until email + password valid', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(),
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'sessionToken': 't'}),
          ),
        ),
      );
      expect(_primaryEnabled(tester, 'Sign In'), isFalse);

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      expect(_primaryEnabled(tester, 'Sign In'), isTrue);
    });

    testWidgets('invalid email renders an inline field error', (tester) async {
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(),
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'sessionToken': 't'}),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'nope');
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows spinner + disables while sign-in is in flight', (
      tester,
    ) async {
      final gate = Completer<String>();
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(completer: gate),
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'sessionToken': 't'}),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      // Button content is replaced by a spinner and the tap is disabled.
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      gate.complete('idtok');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('session token invokes onSession', (tester) async {
      String? got;
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(),
            onSession: (t, {displayName}) => got = t,
            httpClient: _json(200, {'sessionToken': 'sess-9'}),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      await tester.tap(find.text('Sign In'));
      // Don't pumpAndSettle: on success the button spinner keeps animating
      // (production replaces the screen on onSession). Pump fixed frames.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(got, 'sess-9');
    });

    // Verifies: DIARY-GUI-role-switching/H
    testWidgets('login response threads the display name to onSession', (
      tester,
    ) async {
      String? gotName;
      var called = false;
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(),
            onSession: (_, {displayName}) {
              called = true;
              gotName = displayName;
            },
            httpClient: _json(200, {
              'sessionToken': 'sess-9',
              'displayName': 'Elvira Koliadina',
            }),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(called, isTrue);
      expect(gotName, 'Elvira Koliadina');
    });

    testWidgets('no token routes to the OTP screen', (tester) async {
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(),
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'maskedEmail': 'a***@b.org'}),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Enter verification code'), findsOneWidget);
    });

    testWidgets('returning from OTP leaves the login form re-submittable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(),
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'maskedEmail': 'a***@b.org'}),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Enter verification code'), findsOneWidget);
      // Back to Login: the form must not be stuck in the loading/disabled state.
      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();
      expect(find.text('Sponsor Portal'), findsOneWidget);
      expect(_primaryEnabled(tester, 'Sign In'), isTrue);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('failed sign-in renders an error banner', (tester) async {
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(throwError: true),
            onSession: (_, {displayName}) {},
            httpClient: _json(401, null),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBanner), findsOneWidget);
      expect(find.textContaining('Sign-in failed'), findsOneWidget);
    });

    testWidgets('unreachable auth service shows the transport message, '
        'not the credentials one', (tester) async {
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(
              error: FirebaseAuthException(code: 'network-request-failed'),
            ),
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'sessionToken': 'tok'}),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not reach the sign-in service'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Check your email and password'),
        findsNothing,
      );
    });
  });

  group('ForgotPasswordRequestScreen', () {
    testWidgets('Submit gated on a valid email', (tester) async {
      await tester.pumpWidget(
        _host(
          ForgotPasswordRequestScreen(
            serverUrl: url,
            httpClient: _json(200, {'ok': true}),
          ),
        ),
      );
      expect(_primaryEnabled(tester, 'Submit'), isFalse);
      await tester.enterText(find.byType(TextFormField).first, 'a@b.org');
      await tester.pump();
      expect(_primaryEnabled(tester, 'Submit'), isTrue);
    });

    testWidgets('advances to confirmation even when the request errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ForgotPasswordRequestScreen(
            serverUrl: url,
            httpClient: MockClient((_) async => throw Exception('boom')),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'a@b.org');
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsOneWidget);
    });
  });

  group('OtpScreen', () {
    testWidgets('Verify gated on 6 digits; success invokes onSession', (
      tester,
    ) async {
      String? got;
      await tester.pumpWidget(
        _host(
          OtpScreen(
            serverUrl: url,
            idToken: 'idtok',
            maskedEmail: 'a***@b.org',
            onSession: (t, {displayName}) => got = t,
            httpClient: _json(200, {'sessionToken': 'sess-otp'}),
          ),
        ),
      );
      expect(_primaryEnabled(tester, 'Verify'), isFalse);
      await tester.enterText(find.byType(TextFormField).first, '123456');
      await tester.pump();
      expect(_primaryEnabled(tester, 'Verify'), isTrue);
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(got, 'sess-otp');
    });

    testWidgets('Resend re-POSTs /login and shows a notice', (tester) async {
      final paths = <String>[];
      await tester.pumpWidget(
        _host(
          OtpScreen(
            serverUrl: url,
            idToken: 'idtok',
            maskedEmail: 'a***@b.org',
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {
              'ok': true,
            }, on: (r) => paths.add(r.url.path)),
          ),
        ),
      );
      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();
      expect(paths, contains('/login'));
      expect(find.textContaining('new code has been sent'), findsOneWidget);
    });

    testWidgets('Resend on a non-200 shows an error, not a success notice', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          OtpScreen(
            serverUrl: url,
            idToken: 'idtok',
            maskedEmail: 'a***@b.org',
            onSession: (_, {displayName}) {},
            httpClient: _json(401, null),
          ),
        ),
      );
      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('new code has been sent'), findsNothing);
      expect(find.textContaining("Couldn't resend"), findsOneWidget);
    });
  });

  group('PasswordResetScreen', () {
    testWidgets('valid link shows the form; short password blocks submit', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PasswordResetScreen(
            serverUrl: url,
            code: 'C1',
            httpClient: MockClient((req) async {
              if (req.method == 'GET') {
                return http.Response(jsonEncode({'valid': true}), 200);
              }
              return http.Response(jsonEncode({'ok': true}), 200);
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create new password'), findsOneWidget);

      // Too short → still disabled.
      await tester.enterText(find.byType(TextFormField).at(0), 'short');
      await tester.enterText(find.byType(TextFormField).at(1), 'short');
      await tester.pump();
      expect(_primaryEnabled(tester, 'Reset Password'), isFalse);

      // Long + matching → enabled.
      await tester.enterText(find.byType(TextFormField).at(0), 'longenough1');
      await tester.enterText(find.byType(TextFormField).at(1), 'longenough1');
      await tester.pump();
      expect(_primaryEnabled(tester, 'Reset Password'), isTrue);
    });

    testWidgets('mismatch shows an inline error on the confirm field', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PasswordResetScreen(
            serverUrl: url,
            code: 'C1',
            httpClient: MockClient(
              (req) async => http.Response(jsonEncode({'valid': true}), 200),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'longenough1');
      await tester.enterText(find.byType(TextFormField).at(1), 'different22');
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('invalid link shows the expired state', (tester) async {
      await tester.pumpWidget(
        _host(
          PasswordResetScreen(
            serverUrl: url,
            code: 'bad',
            httpClient: MockClient(
              (req) async => http.Response(jsonEncode({'valid': false}), 200),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Link expired'), findsOneWidget);
    });
  });

  group('RoleSelectionScreen', () {
    testWidgets('renders a card per role and reports the chosen role', (
      tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(
        _host(
          RoleSelectionScreen(
            userName: 'Dr. Emily Parker',
            roles: const {'Administrator', 'CRA', 'StudyCoordinator'},
            activeRole: 'Administrator',
            onRoleSelected: (r) async => chosen = r,
            onBackToLogin: () {},
          ),
        ),
      );
      expect(find.text('Welcome, Dr. Emily Parker'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);
      expect(find.text('CRA'), findsOneWidget);
      expect(find.text('Study Coordinator'), findsOneWidget);
      // Participant terminology (not "Patient").
      expect(find.textContaining('Participant management'), findsOneWidget);

      await tester.tap(find.text('CRA'));
      await tester.pumpAndSettle();
      expect(chosen, 'CRA');
    });

    // Verifies: DIARY-GUI-role-switching/I — every offered role card renders a
    //   distinct glyph; regression for the blank Study Coordinator icon
    //   (CUR-1526): the three Figma-designed roles each render an SVG icon.
    testWidgets('each role card renders its Figma SVG icon', (tester) async {
      await tester.pumpWidget(
        _host(
          RoleSelectionScreen(
            userName: 'Dr. Emily Parker',
            roles: const {'Administrator', 'CRA', 'StudyCoordinator'},
            activeRole: 'Administrator',
            onRoleSelected: (_) async {},
            onBackToLogin: () {},
          ),
        ),
      );
      // One SvgPicture per designed role — in particular Study Coordinator is
      // no longer a blank placeholder.
      expect(find.byType(SvgPicture), findsNWidgets(3));
    });

    // Verifies: DIARY-GUI-role-switching/I — a role with no Figma asset still
    //   gets a visible (MaterialIcons) glyph rather than a blank tile.
    testWidgets('a role without a Figma asset falls back to a material icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          RoleSelectionScreen(
            userName: 'Sys Op',
            roles: const {'SystemOperator', 'Administrator'},
            activeRole: 'SystemOperator',
            onRoleSelected: (_) async {},
            onBackToLogin: () {},
          ),
        ),
      );
      // Administrator -> SVG; SystemOperator -> Material settings icon.
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    // Verifies: DIARY-GUI-role-switching/H — the screen greets with whatever
    //   resolved name the shell passes; the email is the fallback when no
    //   display name was available.
    testWidgets('welcome line shows the account identifier as a fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          RoleSelectionScreen(
            userName: 'elyakolyadina48@gmail.com',
            roles: const {'Administrator', 'StudyCoordinator'},
            activeRole: 'Administrator',
            onRoleSelected: (_) async {},
            onBackToLogin: () {},
          ),
        ),
      );
      expect(find.text('Welcome, elyakolyadina48@gmail.com'), findsOneWidget);
    });
  });

  group('LoginScreen — version footer + input hygiene', () {
    testWidgets('renders the bundle version discreetly when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(),
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'sessionToken': 't'}),
            appVersion: '1.4.13+local-abc123',
          ),
        ),
      );
      expect(find.text('Version 1.4.13+local-abc123'), findsOneWidget);
    });

    testWidgets('no version footer when APP_VERSION is empty', (tester) async {
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: _FakeAuth(),
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'sessionToken': 't'}),
          ),
        ),
      );
      expect(find.textContaining('Version '), findsNothing);
    });

    testWidgets('email is trimmed before sign-in (autofill spaces must not '
        'become an opaque credential failure)', (tester) async {
      final auth = _RecordingAuth();
      await tester.pumpWidget(
        _host(
          LoginScreen(
            serverUrl: url,
            authClient: auth,
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'sessionToken': 't'}),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), ' a@b.org ');
      await tester.enterText(find.byType(TextFormField).at(1), 'pw');
      await tester.pump();
      expect(
        _primaryEnabled(tester, 'Sign In'),
        isTrue,
        reason: 'padded-but-valid email must not disable the form',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      expect(auth.lastEmail, 'a@b.org');
    });
  });

  group('OtpScreen — Figma shape', () {
    testWidgets('generic subtitle, masked placeholder, resend link above '
        'Verify', (tester) async {
      await tester.pumpWidget(
        _host(
          OtpScreen(
            serverUrl: url,
            idToken: 'idtok',
            maskedEmail: 'e***@r***.local',
            onSession: (_, {displayName}) {},
            httpClient: _json(200, {'sessionToken': 't'}),
          ),
        ),
      );
      expect(
        find.text('We sent a 6-digit code to your email.'),
        findsOneWidget,
      );
      expect(find.text('Verification Code'), findsOneWidget);

      // Resend renders as an underlined text link sitting ABOVE Verify.
      final resend = tester.widget<Text>(find.text('Resend code'));
      expect(resend.style?.decoration, TextDecoration.underline);
      expect(
        tester.getTopLeft(find.text('Resend code')).dy,
        lessThan(tester.getTopLeft(find.text('Verify')).dy),
      );
    });
  });
}

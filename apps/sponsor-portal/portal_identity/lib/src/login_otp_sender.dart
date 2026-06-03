import 'email_render.dart';
import 'email_transport.dart';

// Implements: DIARY-DEV-portal-login-second-factor/A
class LoginOtpSender {
  LoginOtpSender({required this.transport});
  final EmailTransport transport;

  Future<void> sendOtp({
    required String recipientEmail,
    required String code,
  }) {
    final email = buildOtpEmail(recipientEmail: recipientEmail, code: code);
    return transport.send(email, to: recipientEmail);
  }
}

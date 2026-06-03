import 'email_render.dart';
import 'email_transport.dart';

// Implements: DIARY-DEV-portal-activation-email-delivery/A
class ActivationEmailSender {
  ActivationEmailSender({required this.transport});
  final EmailTransport transport;

  Future<void> sendActivation({
    required String recipientEmail,
    required String activationUrl,
  }) {
    final email = buildActivationEmail(
        recipientEmail: recipientEmail, activationUrl: activationUrl);
    return transport.send(email, to: recipientEmail);
  }
}

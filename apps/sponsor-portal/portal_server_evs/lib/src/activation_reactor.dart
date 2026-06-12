import 'dart:async';
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';

import 'activation_code_store.dart';

/// Subscribes to `user_activation_code_issued`, mints a code through the
/// durable [ActivationCodeStore], and emails the verification link.
/// The portal_user aggregateId IS the recipient email.
///
/// The subscription is push-only (new appends): historical issuance events are
/// deliberately NOT replayed at boot, so a restart never auto-resends emails —
/// pending codes survive via the store's event-backed view, and Resend Invite
/// is the manual recovery path.
// Implements: DIARY-DEV-portal-activation-email-delivery/A
// Implements: DIARY-DEV-portal-activation-code-lifecycle/A
class ActivationReactor {
  ActivationReactor({
    required this.store,
    required this.emailSender,
    required this.portalUrl,
  });

  final ActivationCodeStore store;
  final ActivationEmailSender emailSender;
  final String portalUrl;

  StreamSubscription<Update<StoredEvent>>? _sub;

  /// Begin reacting to newly-appended issuance events (push-only).
  void start(EventStore eventStore) {
    _sub = eventStore
        .subscribe<StoredEvent>(
      const SubscriptionFilter(
        entryTypes: {'user_activation_code_issued'},
      ),
      const Events(),
    )
        .listen((update) {
      if (update is Delta<StoredEvent>) {
        // Fire-and-forget; handleIssued swallows its own failures (the code
        // stays valid for retry), and the catchError is a final backstop so a
        // reactor error can NEVER surface as an unhandled exception that takes
        // the server down.
        unawaited(
            handleIssued(update.value).catchError((Object e, StackTrace st) {
          stderr.writeln('ActivationReactor.handleIssued failed (continuing): '
              '$e\n$st');
        }));
      }
    }, onError: (Object e, StackTrace st) {
      stderr.writeln(
          'ActivationReactor subscription error (continuing): $e\n$st');
    });
  }

  /// Handle a single `user_activation_code_issued` event: mint a code into
  /// the store and dispatch the activation email to the aggregate owner.
  Future<void> handleIssued(StoredEvent event) async {
    final email = event.aggregateId;
    final expiresAt = DateTime.parse(event.data['expires_at']! as String);
    final code = await store.issue(email: email, expiresAt: expiresAt);
    // [portalUrl] is the portal UI origin (NOT the server). The link opens the
    // Flutter activation page, which reads ?code= from its own URL and then
    // calls the server itself. Root path so it resolves on any UI host (plain
    // static server or flutter run) without relying on SPA path fallback.
    final url = '$portalUrl/?code=$code';
    // The code is already minted (valid for retry / shown in console-email
    // mode), so a delivery failure — transient SMTP/credential errors, expired
    // ADC, etc. — is logged and swallowed. Email delivery is a side effect; it
    // must NEVER propagate as an unhandled exception that crashes the portal.
    try {
      await emailSender.sendActivation(
        recipientEmail: email,
        activationUrl: url,
      );
    } catch (e, st) {
      stderr.writeln(
        'ActivationReactor: activation email to "$email" failed; the code '
        'remains valid for retry. $e\n$st',
      );
    }
  }

  Future<void> stop() => _sub?.cancel() ?? Future<void>.value();
}

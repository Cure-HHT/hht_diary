import 'dart:async';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';

import 'activation_code_store.dart';

/// Subscribes to `user_activation_code_issued`, mints a code into the
/// ephemeral [ActivationCodeStore], and emails the verification link.
/// The portal_user aggregateId IS the recipient email.
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
        // Fire-and-forget; failures are logged, the code stays valid for retry.
        handleIssued(update.value);
      }
    });
  }

  /// Handle a single `user_activation_code_issued` event: mint a code into
  /// the store and dispatch the activation email to the aggregate owner.
  Future<void> handleIssued(StoredEvent event) async {
    final email = event.aggregateId;
    final expiresAt = DateTime.parse(event.data['expires_at']! as String);
    final code = store.issue(email: email, expiresAt: expiresAt);
    // [portalUrl] is the portal UI origin (NOT the server). The link opens the
    // Flutter activation page, which reads ?code= from its own URL and then
    // calls the server itself. Root path so it resolves on any UI host (plain
    // static server or flutter run) without relying on SPA path fallback.
    final url = '$portalUrl/?code=$code';
    await emailSender.sendActivation(recipientEmail: email, activationUrl: url);
  }

  Future<void> stop() => _sub?.cancel() ?? Future<void>.value();
}

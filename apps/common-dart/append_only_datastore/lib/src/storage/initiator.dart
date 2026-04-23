/// Polymorphic actor identity stamped on every `StoredEvent`. Replaces the
/// flat `userId: String` field with a sealed hierarchy that names the kind
/// of actor — human user, automation service, or pre-auth anonymous flow —
/// so downstream audit and filtering can reason about causation without
/// guessing.
// Implements: REQ-d00135-A — sealed Dart 3 class with three variants.
// Implements: REQ-d00135-B — JSON round-trip with type discriminator.
// Implements: REQ-d00135-F — rejects unknown discriminator / missing
// required fields with FormatException.
sealed class Initiator {
  const Initiator();

  Map<String, dynamic> toJson();

  static Initiator fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    switch (type) {
      case 'user':
        final userId = json['user_id'];
        if (userId is! String) {
          throw const FormatException(
            'Initiator(user): missing or non-string "user_id"',
          );
        }
        return UserInitiator(userId);
      case 'automation':
        final service = json['service'];
        if (service is! String) {
          throw const FormatException(
            'Initiator(automation): missing or non-string "service"',
          );
        }
        final triggering = json['triggering_event_id'];
        if (triggering != null && triggering is! String) {
          throw const FormatException(
            'Initiator(automation): "triggering_event_id" must be a String '
            'when present',
          );
        }
        return AutomationInitiator(
          service: service,
          triggeringEventId: triggering as String?,
        );
      case 'anonymous':
        final ip = json['ip_address'];
        if (ip != null && ip is! String) {
          throw const FormatException(
            'Initiator(anonymous): "ip_address" must be a String when present',
          );
        }
        return AnonymousInitiator(ipAddress: ip as String?);
      default:
        throw FormatException(
          'Initiator.fromJson: unknown discriminator "$type"; expected '
          'user | automation | anonymous',
        );
    }
  }
}

/// A human user acted; `userId` is the platform's user identifier.
class UserInitiator extends Initiator {
  const UserInitiator(this.userId);
  final String userId;

  @override
  Map<String, dynamic> toJson() => {'type': 'user', 'user_id': userId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserInitiator && userId == other.userId);

  @override
  int get hashCode => Object.hash('user', userId);

  @override
  String toString() => 'UserInitiator($userId)';
}

// Implements: REQ-d00135-D — Automation.triggeringEventId optional cascade
// audit link; null for cron / free-running / observed-external-fact triggers.
class AutomationInitiator extends Initiator {
  const AutomationInitiator({required this.service, this.triggeringEventId});
  final String service;
  final String? triggeringEventId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'automation',
    'service': service,
    'triggering_event_id': triggeringEventId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AutomationInitiator &&
          service == other.service &&
          triggeringEventId == other.triggeringEventId);

  @override
  int get hashCode => Object.hash('automation', service, triggeringEventId);

  @override
  String toString() =>
      'AutomationInitiator(service: $service, triggeringEventId: $triggeringEventId)';
}

// Implements: REQ-d00135-E — Anonymous accepts null ipAddress; used by
// pre-auth flows like the PIN-login screen.
class AnonymousInitiator extends Initiator {
  const AnonymousInitiator({required this.ipAddress});
  final String? ipAddress;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'anonymous',
    'ip_address': ipAddress,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnonymousInitiator && ipAddress == other.ipAddress);

  @override
  int get hashCode => Object.hash('anonymous', ipAddress);

  @override
  String toString() => 'AnonymousInitiator(ipAddress: $ipAddress)';
}

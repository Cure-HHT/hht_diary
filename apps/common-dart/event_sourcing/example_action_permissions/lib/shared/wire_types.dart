// lib/shared/wire_types.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00168 (Dispatcher Pipeline) — wire envelope between client and server
//   REQ-d00170 (Idempotency Contract) — idempotencyHit variant on the wire
//   REQ-d00171 (Denial Events) — denied variant exposes sanitized fields only
//
// Both client and server import this file verbatim. If the JSON shape drifts,
// the compiler catches it.

import 'package:meta/meta.dart';

@immutable
class DispatchRequest {
  const DispatchRequest({
    required this.actionName,
    required this.rawInput,
    this.idempotencyKey,
    this.userId,
  });

  factory DispatchRequest.fromJson(Map<String, Object?> json) {
    return DispatchRequest(
      actionName: json['actionName']! as String,
      rawInput: Map<String, Object?>.from(
        json['rawInput']! as Map<Object?, Object?>,
      ),
      idempotencyKey: json['idempotencyKey'] as String?,
      userId: json['userId'] as String?,
    );
  }

  final String actionName;
  final Map<String, Object?> rawInput;
  final String? idempotencyKey;
  final String? userId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'actionName': actionName,
      'rawInput': rawInput,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      if (userId != null) 'userId': userId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DispatchRequest &&
          actionName == other.actionName &&
          _mapEq(rawInput, other.rawInput) &&
          idempotencyKey == other.idempotencyKey &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(actionName, idempotencyKey, userId);
}

bool _mapEq(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

sealed class DispatchResponse {
  const DispatchResponse();

  factory DispatchResponse.fromJson(Map<String, Object?> json) {
    final kind = json['kind']! as String;
    switch (kind) {
      case 'success':
        return DispatchResponseSuccess(
          actionInvocationId: json['actionInvocationId']! as String,
          emittedEventIds: List<String>.from(
            json['emittedEventIds']! as List<Object?>,
          ),
          result: Map<String, Object?>.from(
            json['result']! as Map<Object?, Object?>,
          ),
        );
      case 'denied':
        return DispatchResponseDenied(
          denialKind: json['denialKind']! as String,
          actionInvocationId: json['actionInvocationId']! as String,
          errorClass: json['errorClass']! as String,
          errorMessageSanitized: json['errorMessageSanitized']! as String,
          permissionDenied: json['permissionDenied'] as String?,
          requestedName: json['requestedName'] as String?,
        );
      case 'idempotencyHit':
        return DispatchResponseIdempotencyHit(
          actionInvocationId: json['actionInvocationId']! as String,
          priorEventIds: List<String>.from(
            json['priorEventIds']! as List<Object?>,
          ),
          priorResult: Map<String, Object?>.from(
            json['priorResult']! as Map<Object?, Object?>,
          ),
        );
      default:
        throw FormatException('unknown DispatchResponse kind: $kind');
    }
  }

  Map<String, Object?> toJson();
}

@immutable
class DispatchResponseSuccess extends DispatchResponse {
  const DispatchResponseSuccess({
    required this.actionInvocationId,
    required this.emittedEventIds,
    required this.result,
  });

  final String actionInvocationId;
  final List<String> emittedEventIds;
  final Map<String, Object?> result;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'success',
    'actionInvocationId': actionInvocationId,
    'emittedEventIds': emittedEventIds,
    'result': result,
  };
}

@immutable
class DispatchResponseDenied extends DispatchResponse {
  const DispatchResponseDenied({
    required this.denialKind,
    required this.actionInvocationId,
    required this.errorClass,
    required this.errorMessageSanitized,
    this.permissionDenied,
    this.requestedName,
  });

  final String denialKind;
  final String actionInvocationId;
  final String errorClass;
  final String errorMessageSanitized;
  final String? permissionDenied;
  final String? requestedName;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'denied',
    'denialKind': denialKind,
    'actionInvocationId': actionInvocationId,
    'errorClass': errorClass,
    'errorMessageSanitized': errorMessageSanitized,
    if (permissionDenied != null) 'permissionDenied': permissionDenied,
    if (requestedName != null) 'requestedName': requestedName,
  };
}

@immutable
class DispatchResponseIdempotencyHit extends DispatchResponse {
  const DispatchResponseIdempotencyHit({
    required this.actionInvocationId,
    required this.priorEventIds,
    required this.priorResult,
  });

  final String actionInvocationId;
  final List<String> priorEventIds;
  final Map<String, Object?> priorResult;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'idempotencyHit',
    'actionInvocationId': actionInvocationId,
    'priorEventIds': priorEventIds,
    'priorResult': priorResult,
  };
}

// SessionStart -------------------------------------------------------------

@immutable
class SessionStartRequest {
  const SessionStartRequest({this.userId});

  factory SessionStartRequest.fromJson(Map<String, Object?> json) {
    return SessionStartRequest(userId: json['userId'] as String?);
  }

  final String? userId;

  Map<String, Object?> toJson() => <String, Object?>{
    if (userId != null) 'userId': userId,
  };
}

@immutable
class SessionStartResponse {
  const SessionStartResponse({
    required this.principalRole,
    required this.principalUserId,
    required this.principalActiveSite,
    required this.snapshotPermissions,
  });

  factory SessionStartResponse.fromJson(Map<String, Object?> json) {
    return SessionStartResponse(
      principalRole: json['principalRole']! as String,
      principalUserId: json['principalUserId'] as String?,
      principalActiveSite: json['principalActiveSite'] as String?,
      snapshotPermissions: List<String>.from(
        json['snapshotPermissions']! as List<Object?>,
      ),
    );
  }

  final String principalRole;
  final String? principalUserId;
  final String? principalActiveSite;
  final List<String> snapshotPermissions;

  Map<String, Object?> toJson() => <String, Object?>{
    'principalRole': principalRole,
    'principalUserId': principalUserId,
    'principalActiveSite': principalActiveSite,
    'snapshotPermissions': snapshotPermissions,
  };
}

// InspectSnapshot ----------------------------------------------------------

@immutable
class StoredEventSummary {
  const StoredEventSummary({
    required this.eventId,
    required this.eventType,
    required this.aggregateType,
    required this.aggregateId,
    required this.actionInvocationId,
    required this.initiatorUserId,
    required this.initiatorRole,
  });

  factory StoredEventSummary.fromJson(Map<String, Object?> json) {
    return StoredEventSummary(
      eventId: json['eventId']! as String,
      eventType: json['eventType']! as String,
      aggregateType: json['aggregateType']! as String,
      aggregateId: json['aggregateId']! as String,
      actionInvocationId: json['actionInvocationId']! as String,
      initiatorUserId: json['initiatorUserId'] as String?,
      initiatorRole: json['initiatorRole']! as String,
    );
  }

  final String eventId;
  final String eventType;
  final String aggregateType;
  final String aggregateId;
  final String actionInvocationId;
  final String? initiatorUserId;
  final String initiatorRole;

  Map<String, Object?> toJson() => <String, Object?>{
    'eventId': eventId,
    'eventType': eventType,
    'aggregateType': aggregateType,
    'aggregateId': aggregateId,
    'actionInvocationId': actionInvocationId,
    'initiatorUserId': initiatorUserId,
    'initiatorRole': initiatorRole,
  };
}

@immutable
class MatrixGrant {
  const MatrixGrant({required this.role, required this.permission});

  factory MatrixGrant.fromJson(Map<String, Object?> json) {
    return MatrixGrant(
      role: json['role']! as String,
      permission: json['permission']! as String,
    );
  }

  final String role;
  final String permission;

  Map<String, Object?> toJson() => <String, Object?>{
    'role': role,
    'permission': permission,
  };
}

@immutable
class UserDirectoryEntry {
  const UserDirectoryEntry({
    required this.userId,
    required this.role,
    required this.activeSite,
  });

  factory UserDirectoryEntry.fromJson(Map<String, Object?> json) {
    return UserDirectoryEntry(
      userId: json['userId']! as String,
      role: json['role']! as String,
      activeSite: json['activeSite'] as String?,
    );
  }

  final String userId;
  final String role;
  final String? activeSite;

  Map<String, Object?> toJson() => <String, Object?>{
    'userId': userId,
    'role': role,
    'activeSite': activeSite,
  };
}

@immutable
class IdempotencyEntrySummary {
  const IdempotencyEntrySummary({
    required this.actionName,
    required this.principalUserId,
    required this.idempotencyKey,
    required this.expiresAt,
  });

  factory IdempotencyEntrySummary.fromJson(Map<String, Object?> json) {
    return IdempotencyEntrySummary(
      actionName: json['actionName']! as String,
      principalUserId: json['principalUserId'] as String?,
      idempotencyKey: json['idempotencyKey']! as String,
      expiresAt: DateTime.parse(json['expiresAt']! as String),
    );
  }

  final String actionName;
  final String? principalUserId;
  final String idempotencyKey;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'actionName': actionName,
    'principalUserId': principalUserId,
    'idempotencyKey': idempotencyKey,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

@immutable
class DispatchTrace {
  const DispatchTrace({
    required this.actionInvocationId,
    required this.actionName,
    required this.stages,
  });

  factory DispatchTrace.fromJson(Map<String, Object?> json) {
    return DispatchTrace(
      actionInvocationId: json['actionInvocationId']! as String,
      actionName: json['actionName']! as String,
      stages: List<String>.from(json['stages']! as List<Object?>),
    );
  }

  final String actionInvocationId;
  final String actionName;
  final List<String> stages;

  Map<String, Object?> toJson() => <String, Object?>{
    'actionInvocationId': actionInvocationId,
    'actionName': actionName,
    'stages': stages,
  };
}

@immutable
class InspectSnapshot {
  const InspectSnapshot({
    required this.events,
    required this.matrixGrants,
    required this.directory,
    required this.idempotency,
    required this.lastDispatchTrace,
  });

  factory InspectSnapshot.fromJson(Map<String, Object?> json) {
    return InspectSnapshot(
      events: (json['events']! as List<Object?>)
          .map((e) => StoredEventSummary.fromJson(e! as Map<String, Object?>))
          .toList(),
      matrixGrants: (json['matrixGrants']! as List<Object?>)
          .map((e) => MatrixGrant.fromJson(e! as Map<String, Object?>))
          .toList(),
      directory: (json['directory']! as List<Object?>)
          .map((e) => UserDirectoryEntry.fromJson(e! as Map<String, Object?>))
          .toList(),
      idempotency: (json['idempotency']! as List<Object?>)
          .map(
            (e) => IdempotencyEntrySummary.fromJson(e! as Map<String, Object?>),
          )
          .toList(),
      lastDispatchTrace: json['lastDispatchTrace'] == null
          ? null
          : DispatchTrace.fromJson(
              json['lastDispatchTrace']! as Map<String, Object?>,
            ),
    );
  }

  final List<StoredEventSummary> events;
  final List<MatrixGrant> matrixGrants;
  final List<UserDirectoryEntry> directory;
  final List<IdempotencyEntrySummary> idempotency;
  final DispatchTrace? lastDispatchTrace;

  Map<String, Object?> toJson() => <String, Object?>{
    'events': events.map((e) => e.toJson()).toList(),
    'matrixGrants': matrixGrants.map((g) => g.toJson()).toList(),
    'directory': directory.map((d) => d.toJson()).toList(),
    'idempotency': idempotency.map((i) => i.toJson()).toList(),
    'lastDispatchTrace': lastDispatchTrace?.toJson(),
  };
}

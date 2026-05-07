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

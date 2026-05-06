// IMPLEMENTS REQUIREMENTS:
//   REQ-d00168 (REQ-DISPATCH): pipeline outcome variants.

import 'package:audited_actions/src/permission.dart';

/// Sealed outcome of `ActionDispatcher.dispatch(...)`. Each pipeline
/// stage's success or failure maps to a variant.
//
// Implements: REQ-d00168-B,D,E,F,G,H,K — one variant per terminal
// stage. Sealed: exhaustiveness checked at every switch site.
sealed class DispatchResult<TResult> {
  const DispatchResult();

  // Implements: REQ-d00168-K
  const factory DispatchResult.success(
    TResult result,
    List<String> emittedEventIds,
  ) = DispatchSuccess<TResult>;

  // Implements: REQ-d00168-B
  const factory DispatchResult.unknownAction(String requestedName) =
      DispatchUnknownAction<TResult>;

  // Implements: REQ-d00168-D
  const factory DispatchResult.parseDenied(Object error) =
      DispatchParseDenied<TResult>;

  // Implements: REQ-d00168-F
  const factory DispatchResult.validationDenied(Object error) =
      DispatchValidationDenied<TResult>;

  // Implements: REQ-d00168-G
  const factory DispatchResult.authorizationDenied(Permission permission) =
      DispatchAuthorizationDenied<TResult>;

  // Implements: REQ-d00168-H
  const factory DispatchResult.executionFailed(Object error) =
      DispatchExecutionFailed<TResult>;

  // Implements: REQ-d00168-E
  const factory DispatchResult.idempotencyHit(
    TResult cachedResult,
    List<String> priorEmittedEventIds,
  ) = DispatchIdempotencyHit<TResult>;
}

class DispatchSuccess<TResult> extends DispatchResult<TResult> {
  const DispatchSuccess(this.result, this.emittedEventIds);
  final TResult result;
  final List<String> emittedEventIds;
}

class DispatchUnknownAction<TResult> extends DispatchResult<TResult> {
  const DispatchUnknownAction(this.requestedName);
  final String requestedName;
}

class DispatchParseDenied<TResult> extends DispatchResult<TResult> {
  const DispatchParseDenied(this.error);
  final Object error;
}

class DispatchValidationDenied<TResult> extends DispatchResult<TResult> {
  const DispatchValidationDenied(this.error);
  final Object error;
}

class DispatchAuthorizationDenied<TResult> extends DispatchResult<TResult> {
  const DispatchAuthorizationDenied(this.permission);
  final Permission permission;
}

class DispatchExecutionFailed<TResult> extends DispatchResult<TResult> {
  const DispatchExecutionFailed(this.error);
  final Object error;
}

class DispatchIdempotencyHit<TResult> extends DispatchResult<TResult> {
  const DispatchIdempotencyHit(this.cachedResult, this.priorEmittedEventIds);
  final TResult cachedResult;
  final List<String> priorEmittedEventIds;
}

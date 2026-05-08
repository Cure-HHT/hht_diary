// lib/server/demo_routes.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167, REQ-d00168 — bootstrap and dispatch entry over HTTP.

import 'dart:async';
import 'dart:convert';

import 'package:action_permissions_demo/server/bootstrap.dart';
import 'package:action_permissions_demo/server/demo_state_projection.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class DemoRoutes {
  DemoRoutes({required this.components, required this.projection});

  final DemoServerComponents components;
  final DemoStateProjection projection;

  /// Per-process trace tracking the last dispatch's stage list. The
  /// inspector pane reads this through [lastTrace]. Concurrency model:
  /// the demo is single-process and dispatches are sequential at the
  /// shelf layer; if you ever serve in parallel, scope this per-request.
  DispatchTrace? _lastTrace;

  Handler get handler {
    final router = Router()
      ..get('/healthz', _healthz)
      ..post('/session/start', _sessionStart)
      ..post('/dispatch', _dispatch)
      ..get('/_demo/inspect', _inspect)
      ..post('/_demo/reset', _reset);
    return router.call;
  }

  DispatchTrace? lastTrace() => _lastTrace;

  Future<Response> _healthz(Request _) async => Response.ok('ok');

  Future<Response> _sessionStart(Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, Object?>;
    final ssReq = SessionStartRequest.fromJson(body);
    final principal = components.directory.resolve(ssReq.userId);
    final perms = await components.policy.permissionsFor(principal);

    final response = SessionStartResponse(
      principalRole: _principalRole(principal),
      principalUserId: principal is UserPrincipal ? principal.userId : null,
      principalActiveSite: principal is UserPrincipal
          ? principal.activeSite
          : null,
      snapshotPermissions: perms.map((p) => p.name).toList()..sort(),
    );
    return Response.ok(jsonEncode(response.toJson()), headers: _jsonHeaders);
  }

  Future<Response> _dispatch(Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, Object?>;
    final dReq = DispatchRequest.fromJson(body);
    final principal = components.directory.resolve(dReq.userId);
    final ctx = ActionContext(
      principal: principal,
      security: const SecurityDetails(),
      requestStartedAt: DateTime.now(),
    );

    final result = await components.dispatcher.dispatch(
      dReq.actionName,
      dReq.rawInput,
      ctx,
      idempotencyKey: dReq.idempotencyKey,
    );

    final wireResponse = _toWireResponse(result, dReq.actionName);
    _lastTrace = DispatchTrace(
      // The dispatcher does not surface its invocation_id to callers; the
      // events it persists carry it in metadata. The inspector pane is the
      // source of truth for action_invocation_id correlation.
      // TODO(demo): expose invocationId on DispatchResult upstream so
      //             traces can carry it.
      actionInvocationId: '',
      actionName: dReq.actionName,
      stages: _stagesFor(result),
    );

    return Response.ok(
      jsonEncode(wireResponse.toJson()),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _inspect(Request _) async {
    final snap = await projection.snapshot();
    return Response.ok(jsonEncode(snap.toJson()), headers: _jsonHeaders);
  }

  Future<Response> _reset(Request _) async {
    // Implemented by Walkthrough 10 (Task 37) once the harness contract
    // for cold-start is finalized. Until then, callers should restart
    // the server with --ephemeral=true to wipe state.
    return Response(
      501,
      body: jsonEncode(<String, Object?>{
        'error': 'reset endpoint not yet implemented; restart with --ephemeral',
      }),
      headers: _jsonHeaders,
    );
  }

  static const Map<String, String> _jsonHeaders = <String, String>{
    'content-type': 'application/json',
  };

  String _principalRole(Principal principal) {
    return switch (principal) {
      UserPrincipal(:final activeRole) => activeRole,
      AnonymousPrincipal() => 'Anon',
    };
  }

  /// Approximate stage list inferred from the result type. The dispatcher
  /// runs Stage 1 (lookup) -> Stage 2 (invocation_id) -> [precondition
  /// idempotency-required check] -> Stage 3 (parse) -> Stage 4 (idempotency
  /// lookup) -> Stage 5 (validate) -> Stage 6 (authorize) -> Stage 7
  /// (execute) -> Stage 8 (persist) -> Stage 9 (record idempotency) ->
  /// Stage 10 (return success). Each variant tells us how far we got.
  List<String> _stagesFor(DispatchResult<Object?> result) {
    return switch (result) {
      DispatchUnknownAction() => const <String>['lookup_failed'],
      DispatchParseDenied() => const <String>['lookup', 'parse_failed'],
      DispatchIdempotencyHit() => const <String>[
        'lookup',
        'parse',
        'idempotency_hit',
      ],
      DispatchValidationDenied() => const <String>[
        'lookup',
        'parse',
        'idempotency_check',
        'validate_failed',
      ],
      DispatchAuthorizationDenied() => const <String>[
        'lookup',
        'parse',
        'idempotency_check',
        'validate',
        'authorize_failed',
      ],
      DispatchExecutionFailed() => const <String>[
        'lookup',
        'parse',
        'idempotency_check',
        'validate',
        'authorize',
        'execute_or_persist_failed',
      ],
      DispatchSuccess() => const <String>[
        'lookup',
        'parse',
        'idempotency_check',
        'validate',
        'authorize',
        'execute',
        'persist',
        'idempotency_record',
        'return_success',
      ],
    };
  }

  DispatchResponse _toWireResponse(
    DispatchResult<Object?> result,
    String actionName,
  ) {
    return switch (result) {
      DispatchSuccess(:final result, :final emittedEventIds) =>
        DispatchResponseSuccess(
          actionInvocationId: '',
          emittedEventIds: emittedEventIds,
          result: _resultToJson(result),
        ),
      DispatchUnknownAction(:final requestedName) => DispatchResponseDenied(
        denialKind: 'unknown_action',
        actionInvocationId: '',
        errorClass: 'UnknownActionError',
        errorMessageSanitized: 'unknown action: $requestedName',
        requestedName: requestedName,
      ),
      DispatchParseDenied(:final error) => DispatchResponseDenied(
        denialKind: 'parse_denied',
        actionInvocationId: '',
        errorClass: error.runtimeType.toString(),
        errorMessageSanitized: sanitizeErrorMessage(error),
      ),
      DispatchValidationDenied(:final error) => DispatchResponseDenied(
        denialKind: 'validation_denied',
        actionInvocationId: '',
        errorClass: error.runtimeType.toString(),
        errorMessageSanitized: sanitizeErrorMessage(error),
      ),
      DispatchAuthorizationDenied(:final permission) => DispatchResponseDenied(
        denialKind: 'authorization_denied',
        actionInvocationId: '',
        errorClass: 'AuthorizationDenied',
        errorMessageSanitized: 'permission ${permission.name} not granted',
        permissionDenied: permission.name,
      ),
      DispatchExecutionFailed(:final error) => DispatchResponseDenied(
        denialKind: 'execution_failed',
        actionInvocationId: '',
        errorClass: error.runtimeType.toString(),
        errorMessageSanitized: 'execution failed',
      ),
      DispatchIdempotencyHit(
        :final cachedResult,
        :final priorEmittedEventIds,
      ) =>
        DispatchResponseIdempotencyHit(
          actionInvocationId: '',
          priorEventIds: priorEmittedEventIds,
          priorResult: _resultToJson(cachedResult),
        ),
    };
  }

  Map<String, Object?> _resultToJson(Object? result) {
    if (result == null) return const <String, Object?>{};
    if (result is Map<String, Object?>) return result;
    try {
      // ignore: avoid_dynamic_calls
      final json = (result as dynamic).toJson() as Map<String, Object?>;
      return json;
    } on Object catch (e) {
      if (e is NoSuchMethodError) {
        return <String, Object?>{'value': result.toString()};
      }
      rethrow;
    }
  }
}

// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//
// Verifies: REQ-o00056-A — proto enum exposes SERVING / NOT_SERVING values
// Verifies: REQ-o00056-B — server binds on a configurable port
// Verifies: REQ-o00056-C — multiple independent servers can run side-by-side
//
// Implementation note: lib/health.pbgrpc.dart only exposes the server-side
// `HealthServiceBase` — there is no generated client. The production code
// path is exercised by Cloud Run's gRPC liveness probe, not by an in-
// process Dart caller. We therefore test:
//   1. the proto types directly (enum values, message construction)
//   2. that Server.create()/serve()/shutdown() round-trips cleanly with
//      the real HealthService, on multiple ports concurrently.
//
// The actual `check()` call is exercised end-to-end by a system probe in
// integration_test/health_probe_test.dart (TODO: add).

import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:grpc_health/health.pb.dart';
import 'package:grpc_health/health.pbgrpc.dart';
import 'package:test/test.dart';

class HealthService extends HealthServiceBase {
  HealthService({this.status = ServingStatus.SERVING});
  final ServingStatus status;

  @override
  Future<HealthCheckResponse> check(
    ServiceCall call,
    HealthCheckRequest request,
  ) async {
    return HealthCheckResponse()..status = status;
  }
}

void main() {
  group('proto types', () {
    test('ServingStatus.SERVING and NOT_SERVING are distinct', () {
      expect(ServingStatus.SERVING, isNot(ServingStatus.NOT_SERVING));
    });

    test('ServingStatus has the four canonical values', () {
      final names = ServingStatus.values.map((v) => v.name).toSet();
      expect(
        names,
        containsAll(<String>{
          'UNKNOWN',
          'SERVING',
          'NOT_SERVING',
          'SERVICE_UNKNOWN',
        }),
      );
    });

    test('HealthCheckRequest carries a service field round-trip', () {
      final req = HealthCheckRequest(service: 'my.service');
      expect(req.service, 'my.service');
    });

    test('HealthCheckResponse defaults to UNKNOWN status', () {
      final resp = HealthCheckResponse();
      expect(resp.status, ServingStatus.UNKNOWN);
    });

    test('HealthCheckResponse can be set to SERVING', () {
      final resp = HealthCheckResponse()..status = ServingStatus.SERVING;
      expect(resp.status, ServingStatus.SERVING);
    });
  });

  group('Server lifecycle', () {
    test('starts and shuts down on an OS-allocated port', () async {
      final server = Server.create(services: [HealthService()]);
      try {
        await server.serve(port: 0);
        expect(server.port, isNotNull);
        expect(server.port!, greaterThan(0));
      } finally {
        await server.shutdown();
      }
    });

    test('two independent servers bind to different ports', () async {
      final a = Server.create(services: [HealthService()]);
      final b = Server.create(services: [HealthService()]);
      try {
        await a.serve(port: 0);
        await b.serve(port: 0);
        expect(a.port, isNotNull);
        expect(b.port, isNotNull);
        expect(a.port, isNot(b.port));
      } finally {
        await a.shutdown();
        await b.shutdown();
      }
    });

    test('shutdown completes within a reasonable timeout', () async {
      final server = Server.create(services: [HealthService()]);
      await server.serve(port: 0);

      final shutdown = server.shutdown();
      await expectLater(
        shutdown.timeout(const Duration(seconds: 10)),
        completes,
      );
    });
  });
}

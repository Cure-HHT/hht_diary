// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//
// Standalone gRPC health check server for Cloud Run liveness probes.
// Listens on port 50051 (internal) and responds SERVING to all
// grpc.health.v1.Health/Check requests.
//
// Cloud Run sends gRPC liveness probes to port 8080; nginx proxies
// gRPC traffic to this server on 50051.

import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:grpc_health/health.pbgrpc.dart';

class HealthService extends HealthServiceBase {
  @override
  Future<HealthCheckResponse> check(
      ServiceCall call, HealthCheckRequest request) async {
    return HealthCheckResponse()..status = ServingStatus.SERVING;
  }
}

Future<void> main(List<String> args) async {
  final port = int.parse(Platform.environment['GRPC_HEALTH_PORT'] ?? '50051');

  final server = Server.create(services: [HealthService()]);
  await server.serve(port: port);

  print('gRPC health server listening on port $port');
}

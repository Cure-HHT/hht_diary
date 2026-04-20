// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//
// Hand-written gRPC service definition for grpc.health.v1.Health.
// Based on https://github.com/grpc/grpc/blob/master/src/proto/grpc/health/v1/health.proto

// ignore_for_file: annotate_overrides, camel_case_types, constant_identifier_names
// ignore_for_file: non_constant_identifier_names, prefer_final_fields

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'health.pb.dart' as $0;

export 'health.pb.dart';

@$pb.GrpcServiceName('grpc.health.v1.Health')
abstract class HealthServiceBase extends $grpc.Service {
  $core.String get $name => 'grpc.health.v1.Health';

  HealthServiceBase() {
    $addMethod(
      $grpc.ServiceMethod<$0.HealthCheckRequest, $0.HealthCheckResponse>(
        'Check',
        check_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.HealthCheckRequest.fromBuffer(value),
        ($0.HealthCheckResponse value) => value.writeToBuffer(),
      ),
    );
  }

  $async.Future<$0.HealthCheckResponse> check_Pre(
    $grpc.ServiceCall call,
    $async.Future<$0.HealthCheckRequest> request,
  ) async {
    return check(call, await request);
  }

  $async.Future<$0.HealthCheckResponse> check(
    $grpc.ServiceCall call,
    $0.HealthCheckRequest request,
  );
}

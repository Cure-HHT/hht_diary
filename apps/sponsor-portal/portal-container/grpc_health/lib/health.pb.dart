// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//
// Hand-written protobuf messages for grpc.health.v1 Health service.
// Based on https://github.com/grpc/grpc/blob/master/src/proto/grpc/health/v1/health.proto

// ignore_for_file: annotate_overrides, camel_case_types, constant_identifier_names
// ignore_for_file: non_constant_identifier_names, prefer_final_fields

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// HealthCheckRequest message - field 1: string service
class HealthCheckRequest extends $pb.GeneratedMessage {
  factory HealthCheckRequest({$core.String? service}) {
    final result = create();
    if (service != null) result.service = service;
    return result;
  }
  HealthCheckRequest._() : super();
  factory HealthCheckRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HealthCheckRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'grpc.health.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'service')
    ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HealthCheckRequest create() => HealthCheckRequest._();
  HealthCheckRequest createEmptyInstance() => create();
  HealthCheckRequest clone() => HealthCheckRequest()..mergeFromMessage(this);
  static $pb.PbList<HealthCheckRequest> createRepeated() =>
      $pb.PbList<HealthCheckRequest>();
  @$core.pragma('dart2js:noInline')
  static HealthCheckRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HealthCheckRequest>(create);
  static HealthCheckRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get service => $_getSZ(0);
  @$pb.TagNumber(1)
  set service($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasService() => $_has(0);
  @$pb.TagNumber(1)
  void clearService() => clearField(1);
}

/// ServingStatus enum for HealthCheckResponse
class ServingStatus extends $pb.ProtobufEnum {
  static const ServingStatus UNKNOWN =
      ServingStatus._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const ServingStatus SERVING =
      ServingStatus._(1, _omitEnumNames ? '' : 'SERVING');
  static const ServingStatus NOT_SERVING =
      ServingStatus._(2, _omitEnumNames ? '' : 'NOT_SERVING');
  static const ServingStatus SERVICE_UNKNOWN =
      ServingStatus._(3, _omitEnumNames ? '' : 'SERVICE_UNKNOWN');

  static const $core.List<ServingStatus> values = <ServingStatus>[
    UNKNOWN,
    SERVING,
    NOT_SERVING,
    SERVICE_UNKNOWN,
  ];

  static final $core.Map<$core.int, ServingStatus> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static ServingStatus? valueOf($core.int value) => _byValue[value];

  const ServingStatus._($core.int v, $core.String n) : super(v, n);
}

/// HealthCheckResponse message - field 1: ServingStatus status
class HealthCheckResponse extends $pb.GeneratedMessage {
  factory HealthCheckResponse({ServingStatus? status}) {
    final result = create();
    if (status != null) result.status = status;
    return result;
  }
  HealthCheckResponse._() : super();
  factory HealthCheckResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HealthCheckResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'grpc.health.v1'),
      createEmptyInstance: create)
    ..e<ServingStatus>(1, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE,
        defaultOrMaker: ServingStatus.UNKNOWN,
        valueOf: ServingStatus.valueOf,
        enumValues: ServingStatus.values)
    ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse create() => HealthCheckResponse._();
  HealthCheckResponse createEmptyInstance() => create();
  HealthCheckResponse clone() => HealthCheckResponse()..mergeFromMessage(this);
  static $pb.PbList<HealthCheckResponse> createRepeated() =>
      $pb.PbList<HealthCheckResponse>();
  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HealthCheckResponse>(create);
  static HealthCheckResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ServingStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(ServingStatus v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => clearField(1);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');

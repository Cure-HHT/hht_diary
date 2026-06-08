// Implements: DIARY-DEV-sponsor-branding-source/E+F+G — JWT-gated serving of
//   sponsor branding asset bytes. The endpoint is NOT public: it requires the
//   patient session JWT the diary already holds (same gate as /user/state). The
//   served bytes are resolved by role from a FIXED constant role->path map AND
//   must appear in the materialized manifest, so a request role string is never
//   turned into a filesystem path: a bogus role (e.g. ../../etc/passwd) hits the
//   404 path, never a file read.
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'patient_token_validator.dart';
import 'sponsor_branding_seed.dart';

/// Build the patient-facing `GET /api/v1/sponsor/branding/asset/<role>` handler.
/// Authenticated by the participant bearer token minted at `/link`. [sponsorId]
/// defaults from the SPONSOR_ID env var.
// Implements: DIARY-DEV-sponsor-branding-source/E+F+G
Handler sponsorBrandingAssetHandler({
  required EventStore eventStore,
  String contentRoot = '/app/sponsor-content',
  String? sponsorId,
}) {
  final sid = sponsorId ?? Platform.environment['SPONSOR_ID'];
  return (Request request) async {
    // E — JWT gate (same patient token as /user/state).
    final payload = verifyPatientAuthHeader(request.headers['authorization']);
    if (payload == null) {
      return Response(401, body: 'invalid or missing patient token');
    }

    final role = request.params['role'] ?? '';

    // The branding manifest must be materialized before any asset can serve.
    final rows = await eventStore.backend.findViewRows('sponsor_branding');
    Map<String, Object?>? branding;
    for (final r in rows) {
      if (sid == null || r['sponsorId'] == sid) {
        branding = r;
        break;
      }
    }
    if (branding == null) {
      return Response(503, body: 'sponsor branding not configured');
    }

    // F+G — resolve the asset by role from the MANIFEST (never from the request
    // string directly). The role must be present both in the manifest and in
    // the fixed role->path constant; otherwise 404. A path-traversal role is
    // absent from both, so it can never reach a file read.
    final manifest = (branding['assets'] as List? ?? const [])
        .map((a) => (a as Map).cast<String, Object?>())
        .toList();
    Map<String, Object?>? asset;
    for (final a in manifest) {
      if (a['role'] == role) {
        asset = a;
        break;
      }
    }
    final localPath = sponsorBrandingAssetPaths[role];
    if (asset == null || localPath == null) {
      return Response.notFound('unknown branding asset role');
    }

    final file = File('$contentRoot/$sid/$localPath');
    if (!file.existsSync()) {
      return Response.notFound('branding asset bytes missing');
    }
    final bytes = file.readAsBytesSync();
    final contentType =
        (asset['contentType'] as String?) ?? 'application/octet-stream';
    return Response.ok(bytes, headers: {'Content-Type': contentType});
  };
}

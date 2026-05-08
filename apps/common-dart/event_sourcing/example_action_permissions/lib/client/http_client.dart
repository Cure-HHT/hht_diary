// lib/client/http_client.dart
// Thin wrapper around package:http for the client side.

import 'dart:convert';

import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:http/http.dart' as http;

class DemoHttpClient {
  DemoHttpClient({this.baseUrl = 'http://localhost:8080', http.Client? inner})
    : _http = inner ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<SessionStartResponse> sessionStart({String? userId}) async {
    final body = jsonEncode(SessionStartRequest(userId: userId).toJson());
    final r = await _http.post(
      Uri.parse('$baseUrl/session/start'),
      body: body,
      headers: const <String, String>{'content-type': 'application/json'},
    );
    if (r.statusCode != 200) {
      throw StateError('session/start ${r.statusCode}: ${r.body}');
    }
    return SessionStartResponse.fromJson(
      jsonDecode(r.body) as Map<String, Object?>,
    );
  }

  Future<DispatchResponse> dispatch(DispatchRequest req) async {
    final r = await _http.post(
      Uri.parse('$baseUrl/dispatch'),
      body: jsonEncode(req.toJson()),
      headers: const <String, String>{'content-type': 'application/json'},
    );
    if (r.statusCode != 200) {
      throw StateError('dispatch ${r.statusCode}: ${r.body}');
    }
    return DispatchResponse.fromJson(
      jsonDecode(r.body) as Map<String, Object?>,
    );
  }

  Future<InspectSnapshot> inspect() async {
    final r = await _http.get(Uri.parse('$baseUrl/_demo/inspect'));
    if (r.statusCode != 200) {
      throw StateError('inspect ${r.statusCode}: ${r.body}');
    }
    return InspectSnapshot.fromJson(jsonDecode(r.body) as Map<String, Object?>);
  }

  void close() => _http.close();
}

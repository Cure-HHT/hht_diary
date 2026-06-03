import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Fetches identity config from the server and initializes Firebase + the auth
/// emulator if an emulator host is reported. Returns true on success.
Future<bool> initFirebaseFromServer(String serverUrl) async {
  final r = await http.get(Uri.parse('$serverUrl/config/identity'));
  if (r.statusCode != 200) return false;
  final cfg = jsonDecode(r.body) as Map<String, Object?>;
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: (cfg['apiKey'] as String?) ?? 'demo-api-key',
      appId: (cfg['appId'] as String?) ?? '',
      messagingSenderId: (cfg['messagingSenderId'] as String?) ?? '',
      projectId: (cfg['projectId'] as String?) ?? 'demo-local-stack',
      authDomain: (cfg['authDomain'] as String?) ?? '',
    ),
  );
  final emulatorHost = (cfg['emulatorHost'] as String?) ?? '';
  if (emulatorHost.isNotEmpty) {
    final parts = emulatorHost.split(':');
    await FirebaseAuth.instance.useAuthEmulator(
      parts[0],
      int.tryParse(parts.length > 1 ? parts[1] : '9099') ?? 9099,
    );
  }
  return true;
}

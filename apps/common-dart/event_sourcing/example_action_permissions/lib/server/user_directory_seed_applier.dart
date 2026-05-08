// IMPLEMENTS REQUIREMENTS:
//   REQ-d00175 (YAML seed + event-emitting applier) — directory-side analogue
//   of the permissions module's EventSeedApplier. Diffs YAML against the
//   current directory; for each missing entry, calls `emit(payload)` (the
//   server uses this to write a user_provisioned event) and
//   `materializer.applyDirect(payload)` (to update the in-memory directory
//   immediately).

import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:action_permissions_demo/server/user_directory_materializer.dart';
import 'package:yaml/yaml.dart';

class UserDirectorySeedApplier {
  UserDirectorySeedApplier({
    required this.directory,
    required this.materializer,
    required this.emit,
  });

  final UserDirectory directory;
  final UserDirectoryMaterializer materializer;
  final void Function(Map<String, Object?> payload) emit;

  void applyYaml(String yamlSource) {
    final doc = loadYaml(yamlSource) as YamlMap;
    final users = doc['users'] as YamlList;
    for (final raw in users) {
      final entry = raw as YamlMap;
      final userId = entry['userId']! as String;
      final role = entry['role']! as String;
      final activeSite = entry['activeSite'] as String?;
      if (directory.contains(userId)) continue;
      final payload = <String, Object?>{
        'userId': userId,
        'role': role,
        'activeSite': activeSite,
      };
      emit(payload);
      materializer.applyDirect(payload);
    }
  }
}

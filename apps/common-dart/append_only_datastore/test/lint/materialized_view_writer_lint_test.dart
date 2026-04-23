import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repo-wide lint that enforces the `diary_entries` cache contract from
/// REQ-d00121-I.
///
/// The `diary_entries` store is a materialized view — a cache of the event
/// log. Writes must flow through `Materializer.apply` inside either the
/// disaster-recovery rebuild (`rebuildMaterializedView`) or the online write
/// path (Phase 5's `EntryService.record`). Any other production code that
/// calls `StorageBackend.upsertEntry` or `StorageBackend.clearEntries`
/// bypasses the fold and breaks the invariant that running
/// `rebuildMaterializedView` would produce the same state.
///
/// The test walks every `.dart` file under `apps/**/lib/` and flags any
/// invocation of either method in a file outside [_allowlist]. The allowlist
/// is kept in this file on purpose: adding a new legitimate writer requires
/// touching this test, which is the review choke-point.

/// Files allowed to invoke `StorageBackend.upsertEntry` or
/// `StorageBackend.clearEntries`. Paths are POSIX-style and repo-relative.
///
/// Adding an entry here is a deliberate assertion that the named file is a
/// legitimate writer of the `diary_entries` materialized view.
const Set<String> _allowlist = {
  // Abstract method declarations.
  'apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart',
  // Concrete backend implementation.
  'apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart',
  // Disaster-recovery rebuild path — folds events through Materializer.apply
  // and replaces the view atomically.
  'apps/common-dart/append_only_datastore/lib/src/materialization/rebuild.dart',
  // Online write path — EntryService.record folds each event through
  // Materializer.apply inside the same transaction as the append
  // (REQ-d00133-D, Phase 4.3 Task 16).
  'apps/common-dart/append_only_datastore/lib/src/entry_service.dart',
};

/// Mutations on the `diary_entries` store. Matched syntactically — any
/// invocation with these names counts, regardless of receiver, because there
/// is no reason any non-StorageBackend class should share these names; a
/// name collision is itself a signal worth reviewing.
final RegExp _mutationCall = RegExp(r'\b(?:upsertEntry|clearEntries)\s*\(');

void main() {
  // Verifies: REQ-d00121-I — diary_entries cache contract; only allowlisted
  // production files may invoke upsertEntry or clearEntries.
  test('REQ-d00121-I: no production file outside the allowlist writes to '
      'diary_entries via upsertEntry or clearEntries', () {
    final repoRoot = _findRepoRoot(Directory.current);
    final appsDir = Directory('${repoRoot.path}/apps');
    if (!appsDir.existsSync()) {
      fail('Expected apps/ directory at repo root ${repoRoot.path}');
    }

    final offenders = <String>[];
    for (final libDir in _findLibDirectoriesUnder(appsDir)) {
      for (final file in _dartFilesUnder(libDir)) {
        final relative = _posixRelative(file, repoRoot);
        if (_allowlist.contains(relative)) continue;
        if (_mutationCall.hasMatch(file.readAsStringSync())) {
          offenders.add(relative);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'REQ-d00121-I: the following production files invoke '
          'upsertEntry(...) or clearEntries(...) on diary_entries. '
          'Those methods mutate the materialized view cache — writes must '
          'flow through Materializer.apply (i.e., rebuildMaterializedView '
          'or EntryService.record). If a listed file is a legitimate '
          'writer, add its repo-relative path to _allowlist in this '
          'test.\nOffenders: $offenders',
    );
  });
}

Directory _findRepoRoot(Directory start) {
  var dir = start.absolute;
  while (true) {
    final gitMarker = FileSystemEntity.typeSync('${dir.path}/.git');
    if (gitMarker != FileSystemEntityType.notFound) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not locate repo root — no .git found walking up from '
        '${start.path}',
      );
    }
    dir = parent;
  }
}

Iterable<Directory> _findLibDirectoriesUnder(Directory root) sync* {
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is Directory &&
        (entity.path.endsWith('${Platform.pathSeparator}lib') ||
            entity.path.endsWith('/lib'))) {
      yield entity;
    }
  }
}

Iterable<File> _dartFilesUnder(Directory dir) sync* {
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

String _posixRelative(File file, Directory repoRoot) {
  final abs = file.absolute.path;
  final root = repoRoot.absolute.path;
  final rel = abs.startsWith(root) ? abs.substring(root.length + 1) : abs;
  return rel.replaceAll(r'\', '/');
}

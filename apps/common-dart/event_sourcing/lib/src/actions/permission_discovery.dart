// IMPLEMENTS REQUIREMENTS:
//   REQ-d00169-D: SQL migration emitter for newly-declared permissions.

/// Emit a SQL migration that seeds the `role_permission_matrix_permissions`
/// table with permissions from [declared] that are not already in [existing].
///
/// Permissions present in the DB but absent from the declared set are
/// emitted as SQL comments only — never auto-deleted.
///
/// The caller supplies permission names directly as sets, so this emitter
/// does not depend on `ActionRegistry`. A thin wrapper that derives
/// [declared] from `registry.allDeclaredPermissions` will be added once
/// `ActionRegistry` is available.
//
// Implements: REQ-d00169-D — insert new permissions; comment out orphans;
// never auto-delete.
String emitPermissionsMigrationSql({
  required Set<String> declared,
  required Set<String> existing,
}) {
  final newPerms = declared.difference(existing).toList()..sort();
  final orphanPerms = existing.difference(declared).toList()..sort();

  final buf = StringBuffer()
    ..writeln('-- actions permission discovery migration')
    ..writeln(
      '-- Declared in code: ${declared.length}, '
      'present in DB: ${existing.length}',
    )
    ..writeln();
  if (newPerms.isNotEmpty) {
    buf
      ..writeln('INSERT INTO role_permission_matrix_permissions (name, status)')
      ..writeln('VALUES');
    for (var i = 0; i < newPerms.length; i++) {
      final p = newPerms[i];
      final terminator = i == newPerms.length - 1 ? '' : ',';
      buf.writeln("  ('$p', 'unassigned')$terminator");
    }
    buf
      ..writeln('ON CONFLICT (name) DO NOTHING;')
      ..writeln();
  } else {
    buf
      ..writeln('-- No new permissions to insert.')
      ..writeln();
  }
  if (orphanPerms.isNotEmpty) {
    buf
      ..writeln('-- ORPHAN permissions (present in DB, absent from code):')
      ..writeln('-- These are NOT auto-deleted; review and remove manually:');
    for (final p in orphanPerms) {
      buf.writeln('--   $p');
    }
  }
  return buf.toString();
}

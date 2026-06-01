import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:reaction_widgets/reaction_widgets.dart';

// First reader of the sites_index materialization (portal_service
// TableProjectionSpec). Read-only reactive list, gated on view:sites_index.
// Implements: DIARY-DEV-rave-edc-ingest/A

/// One sites_index row (columns: site_id/site_name/site_number/is_active).
class _Site {
  const _Site({
    required this.id,
    required this.name,
    required this.number,
    required this.active,
  });
  final String id;
  final String name;
  final String number;
  final bool active;

  static _Site fromRow(Map<String, Object?> r) => _Site(
        id: (r['site_id'] as String?) ?? '?',
        name: (r['site_name'] as String?) ?? '?',
        number: (r['site_number'] as String?) ?? '?',
        active: (r['is_active'] as bool?) ?? true,
      );
}

class SitesScreen extends StatelessWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context) => PermissionGate(
        permission: 'view:sites_index',
        fallback: const Center(
          child: Text("You don't have permission to view sites."),
        ),
        child: ViewBuilder<_Site>(
          viewName: 'sites_index',
          mapper: _Site.fromRow,
          aggregateIdOf: (s) => s.id,
          builder: (context, state) {
            final rows = switch (state) {
              Loading<_Site>() => const <_Site>[],
              Ready<_Site>(:final rows) => rows,
              Stale<_Site>(:final lastRows) => lastRows,
            };
            if (state is Loading<_Site>) {
              return const Center(child: CircularProgressIndicator());
            }
            if (rows.isEmpty) {
              return const Center(child: Text('(no sites synced yet)'));
            }
            final sorted = <_Site>[...rows]
              ..sort((a, b) => a.number.compareTo(b.number));
            return ListView(
              children: <Widget>[
                for (final s in sorted)
                  ListTile(
                    title: Text('${s.number} · ${s.name}'),
                    subtitle: Text(s.id),
                    trailing:
                        s.active ? null : const Chip(label: Text('inactive')),
                  ),
              ],
            );
          },
        ),
      );
}

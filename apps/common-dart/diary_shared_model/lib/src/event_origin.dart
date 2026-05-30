// Implements: DIARY-DEV-shared-events-catalog/B — every shared event carries an origin tag.
import 'package:event_sourcing/event_sourcing.dart';

/// Which node originates an event. `[home: shared]` events still record where
/// they are authored, so the mobile cross-post (CUR-1371) and audit views know
/// the producer.
enum EventOrigin { portal, mobile, edge }

/// A cross-wire entry type: the substrate [EntryTypeDefinition] plus its origin.
class SharedEventType {
  const SharedEventType({required this.definition, required this.origin});

  final EntryTypeDefinition definition;
  final EventOrigin origin;

  String get id => definition.id;
}

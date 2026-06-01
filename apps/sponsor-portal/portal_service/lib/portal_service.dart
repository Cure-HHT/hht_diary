/// Portal-server enforcement core: scope registry, role seed, authorization
/// policy, and action dispatcher, wired over the event_sourcing library.
library;

export 'src/scope_classes.dart';
export 'src/role_seed.dart';
export 'src/authz.dart';
export 'src/dispatcher.dart';
export 'src/projections.dart';
export 'src/rave_sync_lockout.dart';
export 'src/rave_edc_ingester.dart';
export 'src/dev_seed_rave_client.dart';

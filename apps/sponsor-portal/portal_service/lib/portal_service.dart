/// Portal-server enforcement core: scope registry, role seed, authorization
/// policy, and action dispatcher, wired over the event_sourcing library.
library;

export 'src/scope_classes.dart';
export 'src/role_seed.dart';

// Further exports (authz, dispatcher) are added as each lands.

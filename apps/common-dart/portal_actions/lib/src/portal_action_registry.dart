// Implements: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';

import 'actions/deactivate_user_account_action.dart';

/// Build the portal's ActionRegistry. Extend as concrete actions land.
ActionRegistry buildPortalActionRegistry() {
  final registry = ActionRegistry()..register(DeactivateUserAccountAction());
  return registry;
}

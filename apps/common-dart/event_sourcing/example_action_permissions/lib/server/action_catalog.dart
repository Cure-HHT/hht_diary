// lib/server/action_catalog.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167 (ActionRegistry and Bootstrap) — collision-free registration of
//   all 7 demo actions.

import 'package:action_permissions_demo/server/actions/edit_blue_note_action.dart';
import 'package:action_permissions_demo/server/actions/edit_green_note_action.dart';
import 'package:action_permissions_demo/server/actions/press_blue_button_action.dart';
import 'package:action_permissions_demo/server/actions/press_green_button_action.dart';
import 'package:action_permissions_demo/server/actions/press_red_alarm_action.dart';
import 'package:action_permissions_demo/server/actions/provision_user_action.dart';
import 'package:action_permissions_demo/server/actions/request_help_action.dart';
import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:event_sourcing/event_sourcing.dart';

ActionRegistry buildDemoActionRegistry({required UserDirectory directory}) {
  final registry = ActionRegistry()
    ..register(RequestHelpAction())
    ..register(EditGreenNoteAction())
    ..register(EditBlueNoteAction())
    ..register(PressGreenButtonAction())
    ..register(PressBlueButtonAction())
    ..register(PressRedAlarmAction())
    ..register(ProvisionUserAction(directory: directory));
  return registry;
}

// lib/client/action_buttons_panel.dart
//
// Seven buttons mapping 1:1 to the demo's happy-path actions. Each button
// is enabled iff the snapshot grants the action's permission OR hacker
// mode is on. Hacker-only "malformed-request" affordances land in Task 27.

import 'package:action_permissions_demo/client/hacker_mode_toggle.dart';
import 'package:action_permissions_demo/client/http_client.dart';
import 'package:action_permissions_demo/client/permission_snapshot_cache.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

@immutable
class DispatchHistoryEntry {
  const DispatchHistoryEntry({
    required this.request,
    required this.response,
    required this.at,
  });

  final DispatchRequest request;
  final DispatchResponse response;
  final DateTime at;
}

typedef DispatchListener = void Function(DispatchHistoryEntry entry);

class ActionButtonsPanel extends StatelessWidget {
  const ActionButtonsPanel({
    super.key,
    required this.cache,
    required this.hackerMode,
    required this.http,
    required this.onDispatched,
  });

  final PermissionSnapshotCache cache;
  final HackerMode hackerMode;
  final DemoHttpClient http;
  final DispatchListener onDispatched;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[cache, hackerMode]),
      builder: (context, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _btn(context, 'Ask for Help', 'help.ask', _requestHelp),
            _btn(
              context,
              'Edit Green Note',
              'notes.write.green',
              _editGreenNote,
            ),
            _btn(context, 'Edit Blue Note', 'notes.write.blue', _editBlueNote),
            _btn(context, 'Press Green', 'buttons.press.green', _pressGreen),
            _btn(context, 'Press Blue', 'buttons.press.blue', _pressBlue),
            _btn(
              context,
              'Press Red Alarm',
              'buttons.press.red',
              _pressRedAlarm,
            ),
            _btn(context, 'Provision User', 'users.provision', _provisionUser),
          ],
        );
      },
    );
  }

  Widget _btn(
    BuildContext context,
    String label,
    String perm,
    Future<void> Function(BuildContext) onTap,
  ) {
    final enabled = hackerMode.enabled || cache.holds(perm);
    return ElevatedButton(
      onPressed: enabled ? () => onTap(context) : null,
      child: Text(label),
    );
  }

  Future<void> _requestHelp(BuildContext context) async {
    final message = await _prompt(context, 'Help message');
    if (message == null) return;
    await _send(
      DispatchRequest(
        actionName: 'RequestHelpAction',
        rawInput: <String, Object?>{'message': message},
        userId: cache.userId,
      ),
    );
  }

  Future<void> _editGreenNote(BuildContext context) =>
      _editNote(context, 'EditGreenNoteAction');

  Future<void> _editBlueNote(BuildContext context) =>
      _editNote(context, 'EditBlueNoteAction');

  Future<void> _editNote(BuildContext context, String actionName) async {
    final title = await _prompt(context, 'Title');
    if (title == null) return;
    if (!context.mounted) return;
    final body = await _prompt(context, 'Body');
    if (body == null) return;
    await _send(
      DispatchRequest(
        actionName: actionName,
        rawInput: <String, Object?>{
          'noteId': const Uuid().v4(),
          'title': title,
          'body': body,
        },
        idempotencyKey: const Uuid().v4(),
        userId: cache.userId,
      ),
    );
  }

  Future<void> _pressGreen(BuildContext context) async {
    await _send(
      DispatchRequest(
        actionName: 'PressGreenButtonAction',
        rawInput: const <String, Object?>{},
        userId: cache.userId,
      ),
    );
  }

  Future<void> _pressBlue(BuildContext context) async {
    await _send(
      DispatchRequest(
        actionName: 'PressBlueButtonAction',
        rawInput: const <String, Object?>{},
        userId: cache.userId,
      ),
    );
  }

  Future<void> _pressRedAlarm(BuildContext context) async {
    final reason = await _prompt(context, 'Alarm reason');
    if (reason == null) return;
    await _send(
      DispatchRequest(
        actionName: 'PressRedAlarmAction',
        rawInput: <String, Object?>{'reason': reason},
        idempotencyKey: const Uuid().v4(),
        userId: cache.userId,
      ),
    );
  }

  Future<void> _provisionUser(BuildContext context) async {
    final input = await showDialog<_ProvisionInput>(
      context: context,
      builder: (ctx) => const _ProvisionUserDialog(),
    );
    if (input == null) return;
    await _send(
      DispatchRequest(
        actionName: 'ProvisionUserAction',
        rawInput: <String, Object?>{
          'userId': input.userId,
          'role': input.role,
          'activeSite': input.activeSite,
        },
        idempotencyKey: const Uuid().v4(),
        userId: cache.userId,
      ),
    );
  }

  Future<void> _send(DispatchRequest req) async {
    try {
      final resp = await http.dispatch(req);
      onDispatched(
        DispatchHistoryEntry(request: req, response: resp, at: DateTime.now()),
      );
    } on Object catch (e) {
      // Server unreachable from the demo — synthesize a denied response
      // so the history records the failure visibly.
      onDispatched(
        DispatchHistoryEntry(
          request: req,
          response: DispatchResponseDenied(
            denialKind: 'transport_error',
            actionInvocationId: '',
            errorClass: e.runtimeType.toString(),
            errorMessageSanitized: 'transport: $e',
          ),
          at: DateTime.now(),
        ),
      );
    }
  }

  Future<String?> _prompt(BuildContext context, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _ProvisionInput {
  const _ProvisionInput({
    required this.userId,
    required this.role,
    required this.activeSite,
  });
  final String userId;
  final String role;
  final String? activeSite;
}

class _ProvisionUserDialog extends StatefulWidget {
  const _ProvisionUserDialog();

  @override
  State<_ProvisionUserDialog> createState() => _ProvisionUserDialogState();
}

class _ProvisionUserDialogState extends State<_ProvisionUserDialog> {
  final TextEditingController _userIdCtl = TextEditingController();
  final TextEditingController _siteCtl = TextEditingController();
  String _role = 'GreenTeam';

  @override
  void dispose() {
    _userIdCtl.dispose();
    _siteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Provision user'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _userIdCtl,
              decoration: const InputDecoration(labelText: 'userId'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'role'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                DropdownMenuItem(value: 'GreenTeam', child: Text('GreenTeam')),
                DropdownMenuItem(value: 'BlueTeam', child: Text('BlueTeam')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'GreenTeam'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _siteCtl,
              decoration: const InputDecoration(
                labelText: 'activeSite (blank = none)',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop<void>(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final site = _siteCtl.text.trim();
            Navigator.pop<_ProvisionInput>(
              context,
              _ProvisionInput(
                userId: _userIdCtl.text.trim(),
                role: _role,
                activeSite: site.isEmpty ? null : site,
              ),
            );
          },
          child: const Text('Provision'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

/// The two seeded identities. The value IS the dev credential
/// ("userId:activeRole") the DevCredentialAuthValidator parses.
const Map<String, String> _identities = <String, String>{
  'admin-1 (Administrator)': 'admin-1:Administrator',
  'sc-1 (StudyCoordinator)': 'sc-1:StudyCoordinator',
};

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({this.message, super.key});
  final String? message;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  String _credential = _identities.values.first;

  void _connect() =>
      ReActionScope.of(context).authSession.setCredential(_credential);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (widget.message != null) ...<Widget>[
                  Text(widget.message!),
                  const SizedBox(height: 12),
                ],
                const Text('Connect as'),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _credential,
                  isExpanded: true,
                  items: <DropdownMenuItem<String>>[
                    for (final e in _identities.entries)
                      DropdownMenuItem<String>(
                        value: e.value,
                        child: Text(e.key),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => _credential = v ?? _credential),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _connect,
                  icon: const Icon(Icons.login),
                  label: const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

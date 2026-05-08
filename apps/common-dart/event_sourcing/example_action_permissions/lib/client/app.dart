// lib/client/app.dart
import 'package:action_permissions_demo/client/client_pane.dart';
import 'package:action_permissions_demo/client/server_inspector_pane.dart';
import 'package:flutter/material.dart';

class DualPaneApp extends StatelessWidget {
  const DualPaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'action_permissions_demo',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('action_permissions_demo')),
        body: const Row(
          children: <Widget>[
            Expanded(child: ClientPane()),
            VerticalDivider(width: 1),
            Expanded(child: ServerInspectorPane()),
          ],
        ),
      ),
    );
  }
}

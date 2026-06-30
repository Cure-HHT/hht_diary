import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/participant_actions_dialog.dart';

/// pumpReactionWidget wraps a bare MaterialApp; the kit components null-assert
/// the theme extensions, so wrap children in the kit theme.
Widget _kitThemed(Widget child) => Theme(
  data: buildAppTheme(font: AppFontFamily.inter),
  child: child,
);

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required List<ParticipantActionItem> actions,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _kitThemed(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ParticipantActionsDialog.show(
                    context: context,
                    participantId: '001-1023456',
                    actions: actions,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders header, participant id and every action label', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      actions: const [
        ParticipantActionItem(
          label: 'Show Linking Code',
          iconAsset: 'assets/icons/participant/eye.svg',
          onSelected: _noop,
        ),
        ParticipantActionItem(
          label: 'Disconnect Participant',
          iconAsset: 'assets/icons/participant/disconnect.svg',
          destructive: true,
          onSelected: _noop,
        ),
      ],
    );

    expect(find.text('Participant Actions'), findsOneWidget);
    expect(find.textContaining('001-1023456'), findsOneWidget);
    expect(find.text('Show Linking Code'), findsOneWidget);
    expect(find.text('Disconnect Participant'), findsOneWidget);
  });

  testWidgets('a destructive action renders its label in the Critical color', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      actions: const [
        ParticipantActionItem(
          label: 'Mark as Not Participating',
          iconAsset: 'assets/icons/participant/user_x.svg',
          destructive: true,
          onSelected: _noop,
        ),
      ],
    );

    final label = tester.widget<Text>(find.text('Mark as Not Participating'));
    expect(label.style?.color, const Color(0xFFCB333B));
  });

  testWidgets(
    'tapping an action dismisses the sheet then invokes its handler',
    (tester) async {
      var tapped = 0;
      await pumpDialog(
        tester,
        actions: [
          ParticipantActionItem(
            label: 'Show Linking Code',
            iconAsset: 'assets/icons/participant/eye.svg',
            onSelected: () => tapped++,
          ),
        ],
      );

      await tester.tap(find.text('Show Linking Code'));
      await tester.pumpAndSettle();

      expect(tapped, 1);
      // Sheet dismissed before the handler ran.
      expect(find.text('Participant Actions'), findsNothing);
    },
  );

  testWidgets('the close button dismisses the sheet', (tester) async {
    await pumpDialog(
      tester,
      actions: const [
        ParticipantActionItem(
          label: 'Show Linking Code',
          iconAsset: 'assets/icons/participant/eye.svg',
          onSelected: _noop,
        ),
      ],
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Participant Actions'), findsNothing);
  });
}

void _noop() {}

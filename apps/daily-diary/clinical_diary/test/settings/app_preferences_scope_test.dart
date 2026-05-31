// Verifies: DIARY-DEV-reactive-read-path/C — screens read the current
//   preferences reactively from context, fed by the app-level settings view.
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('of() exposes the provided preferences', (tester) async {
    late UserPreferences seen;
    await tester.pumpWidget(
      AppPreferencesScope(
        preferences: const UserPreferences(
          largerTextAndControls: true,
          languageCode: 'es',
        ),
        child: Builder(
          builder: (context) {
            seen = AppPreferencesScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(seen.largerTextAndControls, isTrue);
    expect(seen.languageCode, 'es');
  });

  testWidgets('of() returns defaults when no scope is present', (tester) async {
    late UserPreferences seen;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen = AppPreferencesScope.of(context);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(seen, const UserPreferences());
  });

  testWidgets('rebuilds dependents only when preferences change', (
    tester,
  ) async {
    var buildCount = 0;
    var prefs = const UserPreferences();

    // Cache the dependent so it is the SAME widget instance across rebuilds;
    // only the InheritedWidget dependency can then trigger its rebuild.
    final dependent = Builder(
      builder: (context) {
        buildCount++;
        AppPreferencesScope.of(context);
        return const SizedBox.shrink();
      },
    );

    late StateSetter setOuter;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return AppPreferencesScope(preferences: prefs, child: dependent);
        },
      ),
    );
    expect(buildCount, 1);

    // Same value -> no dependent rebuild.
    setOuter(() => prefs = const UserPreferences());
    await tester.pump();
    expect(buildCount, 1);

    // Changed value -> dependent rebuilds.
    setOuter(() => prefs = const UserPreferences(isDarkMode: true));
    await tester.pump();
    expect(buildCount, 2);
  });
}

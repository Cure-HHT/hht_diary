// Verifies: DIARY-DEV-deployment-config-defaults/A
import 'package:clinical_diary/scope/sponsor_ui_config_scope.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes config to descendants', (tester) async {
    late SponsorUiConfig seen;
    await tester.pumpWidget(
      SponsorUiConfigScope(
        config: const SponsorUiConfig(availableLanguages: ['en']),
        child: Builder(
          builder: (context) {
            seen = SponsorUiConfigScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.availableLanguages, ['en']);
  });

  testWidgets('returns code default when no scope present', (tester) async {
    late SponsorUiConfig seen;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen = SponsorUiConfigScope.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(seen, SponsorUiConfig.codeDefault);
  });
}

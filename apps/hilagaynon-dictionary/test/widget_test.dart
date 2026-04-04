import 'package:flutter_test/flutter_test.dart';

import 'package:hilagaynon_dictionary/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HilagaynonDictionaryApp());
    expect(find.text('Hilagaynon Dictionary'), findsOneWidget);
  });
}
